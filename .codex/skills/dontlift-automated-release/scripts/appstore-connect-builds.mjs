#!/usr/bin/env node
// 查询 App Store Connect build，避免复用 build，并验证 TestFlight processing 状态。
import { createSign } from "node:crypto";
import { appendFileSync, readFileSync } from "node:fs";

const command = process.argv[2];
const issuerId = process.env.APPSTORE_ISSUER_ID;
const keyId = process.env.APPSTORE_API_KEY_ID;
const keyPath = process.env.APPSTORE_API_PRIVATE_KEY_PATH;
const bundleId = process.env.IOS_BUNDLE_ID ?? "com.yulinxi.app.DontLift";
const version = process.env.RELEASE_VERSION;
const requestedBuild = Number(process.env.RELEASE_BUILD);

function required(value, name) {
  if (!value) throw new Error(`缺少环境变量 ${name}`);
  return value;
}

required(command, "command");
required(issuerId, "APPSTORE_ISSUER_ID");
required(keyId, "APPSTORE_API_KEY_ID");
required(keyPath, "APPSTORE_API_PRIVATE_KEY_PATH");
const privateKey = readFileSync(keyPath, "utf8");

function base64url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer.toString("base64url");
}

function token() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
  const payload = base64url(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 10 * 60,
    aud: "appstoreconnect-v1",
  }));
  const unsigned = `${header}.${payload}`;
  const signer = createSign("SHA256");
  signer.update(unsigned);
  signer.end();
  const signature = signer.sign({ key: privateKey, dsaEncoding: "ieee-p1363" });
  return `${unsigned}.${base64url(signature)}`;
}

async function get(url) {
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token()}` },
  });
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`App Store Connect ${response.status}: ${body.slice(0, 1000)}`);
  }
  return JSON.parse(body);
}

async function allPages(url) {
  const data = [];
  let next = url;
  for (let page = 0; next && page < 20; page += 1) {
    const body = await get(next);
    data.push(...(body.data ?? []));
    next = body.links?.next ?? null;
  }
  if (next) throw new Error("App Store Connect 分页超过安全上限 20 页");
  return data;
}

async function appId() {
  const url = new URL("https://api.appstoreconnect.apple.com/v1/apps");
  url.searchParams.set("filter[bundleId]", bundleId);
  url.searchParams.set("limit", "2");
  const body = await get(url);
  if (body.data?.length !== 1) {
    throw new Error(`bundleId=${bundleId} 应唯一匹配 App，实际 ${body.data?.length ?? 0}`);
  }
  return body.data[0].id;
}

async function allBuilds(id) {
  const url = new URL("https://api.appstoreconnect.apple.com/v1/builds");
  url.searchParams.set("filter[app]", id);
  url.searchParams.set("fields[builds]", "version,processingState,uploadedDate");
  url.searchParams.set("limit", "200");
  return allPages(url);
}

async function targetBuild(id, marketingVersion, buildNumber) {
  const url = new URL("https://api.appstoreconnect.apple.com/v1/builds");
  url.searchParams.set("filter[app]", id);
  url.searchParams.set("filter[version]", String(buildNumber));
  url.searchParams.set("filter[preReleaseVersion.version]", marketingVersion);
  url.searchParams.set("fields[builds]", "version,processingState,uploadedDate");
  url.searchParams.set("limit", "2");
  const body = await get(url);
  if ((body.data?.length ?? 0) > 1) {
    throw new Error(`TestFlight ${marketingVersion} (${buildNumber}) 匹配到多个 build`);
  }
  return body.data?.[0] ?? null;
}

function writeOutput(values) {
  const output = Object.entries(values).map(([key, value]) => `${key}=${value}`).join("\n");
  process.stdout.write(`${JSON.stringify(values)}\n`);
  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(process.env.GITHUB_OUTPUT, `${output}\n`);
  }
}

async function main() {
  const id = await appId();
  if (command === "latest" || command === "assert-available") {
    const builds = await allBuilds(id);
    const latestBuild = builds.reduce((max, item) => {
      const value = Number(item.attributes?.version);
      return Number.isFinite(value) ? Math.max(max, value) : max;
    }, 0);
    if (command === "assert-available") {
      required(version, "RELEASE_VERSION");
      if (!Number.isInteger(requestedBuild) || requestedBuild <= latestBuild) {
        throw new Error(`build=${process.env.RELEASE_BUILD} 不可用；App Store Connect 最高 build=${latestBuild}`);
      }
    }
    writeOutput({ latest_build: latestBuild, requested_build: requestedBuild || "" });
    return;
  }

  if (command === "target-status" || command === "verify-valid") {
    required(version, "RELEASE_VERSION");
    if (!Number.isInteger(requestedBuild)) throw new Error("RELEASE_BUILD 必须为整数");
    const target = await targetBuild(id, version, requestedBuild);
    if (!target && command === "target-status") {
      writeOutput({ exists: false, processing_state: "NOT_FOUND", build_id: "" });
      return;
    }
    if (!target) throw new Error(`未找到 TestFlight ${version} (${requestedBuild})`);
    const state = target.attributes?.processingState;
    if (command === "target-status") {
      writeOutput({ exists: true, processing_state: state, build_id: target.id });
      return;
    }
    if (state !== "VALID") throw new Error(`TestFlight processingState=${state}，期望 VALID`);
    writeOutput({
      build_id: target.id,
      processing_state: state,
      version,
      build: requestedBuild,
    });
    return;
  }

  throw new Error(`未知命令 ${command}；可用 latest | assert-available | target-status | verify-valid`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack ?? error.message}\n`);
  process.exit(1);
});
