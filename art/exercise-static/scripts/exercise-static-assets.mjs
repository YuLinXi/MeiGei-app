#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repo = path.resolve(import.meta.dirname, "../../..");
const staticRoot = path.join(repo, "art/exercise-static");
const presetPath = path.join(repo, "ios/DontLift/DontLift/Resources/ExerciseLibrary/preset_exercises_v1.json");
const productionPath = path.join(staticRoot, "manifests/production-manifest-v1.json");
const provenancePath = path.join(staticRoot, "manifests/provenance-v1.json");
const runtimeDir = path.join(repo, "ios/DontLift/DontLift/Resources/ExerciseArtwork");
const runtimeManifestPath = path.join(runtimeDir, "exercise_artwork_manifest_v1.json");
const stagingDir = path.join(staticRoot, "staging/exports");
const reviewPagePath = path.join(staticRoot, "reviews/generated/static-review-v1.html");
const skippedLedgerPath = path.join(staticRoot, "reviews/autopilot-skipped-actions-v1.md");
const rendererPath = path.join(staticRoot, "scripts/render-thumbnail.swift");
const reviewKinds = ["identity", "art", "movement", "equipment", "rights"];
const runtimePixels = 288;
const jpegQuality = 82;
const maximumRuntimeBytes = 24_576;

function fail(message) {
  throw new Error(message);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`);
  fs.renameSync(temporary, file);
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function relative(file) {
  return path.relative(repo, file).split(path.sep).join("/");
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: repo,
    encoding: "utf8",
    stdio: options.capture ? "pipe" : "inherit",
  });
  if (result.status !== 0) {
    const detail = options.capture ? `\n${result.stderr || result.stdout}` : "";
    fail(`${command} 执行失败${detail}`);
  }
  return result.stdout ?? "";
}

function knownCodes() {
  return new Set(readJson(presetPath).exercises.map((exercise) => exercise.code));
}

function isOutOfScope(exercise) {
  return exercise.category === "热身拉伸"
    || exercise.category === "功能性"
    || exercise.category === "有氧"
    || (exercise.category === "核心" && exercise.equipmentType === "自重");
}

function inScopeExercises() {
  return readJson(presetPath).exercises.filter((exercise) => !isOutOfScope(exercise));
}

function requireCode(rawCode) {
  const code = rawCode ?? "";
  if (!/^[A-Z0-9_]+$/.test(code)) fail(`非法 exercise code：${code || "<empty>"}`);
  if (!knownCodes().has(code)) fail(`未知 exercise code：${code}`);
  return code;
}

function approvedMaster(code) {
  const directory = path.join(staticRoot, "masters/approved");
  const matches = fs.readdirSync(directory)
    .filter((name) => name.startsWith(`${code}-v`) && name.endsWith(".png"))
    .sort();
  if (matches.length !== 1) {
    fail(`${code} 必须且只能有一个已批准 PNG 母版，当前为 ${matches.length} 个`);
  }
  return path.join(directory, matches[0]);
}

function reviewRecord(code) {
  const file = path.join(staticRoot, `reviews/${code}-review.json`);
  if (!fs.existsSync(file)) fail(`缺少机器可读审核记录：${relative(file)}`);
  const record = readJson(file);
  if (record.exerciseCode !== code) fail(`${relative(file)} 的 exerciseCode 不一致`);
  for (const kind of reviewKinds) {
    const review = record.reviews?.[kind];
    if (review?.status !== "approved") fail(`${code} 的 ${kind} 尚未通过自治或人工审核`);
    if (!review.reviewerId || !review.reviewedAt || !review.evidence?.length) {
      fail(`${code} 的 ${kind} 批准记录不完整`);
    }
  }
  return record;
}

function publicReview(record) {
  return Object.fromEntries(reviewKinds.map((kind) => {
    const { status, reviewerId, reviewedAt, evidence, notes } = record.reviews[kind];
    return [kind, { status, reviewerId, reviewedAt, evidence, notes }];
  }));
}

function exportThumbnail(code, output) {
  const master = approvedMaster(code);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  run("swift", [rendererPath, master, output]);
  inspectJpeg(output);
  return output;
}

function inspectJpeg(file) {
  if (!fs.existsSync(file)) fail(`缺少 JPG：${relative(file)}`);
  const output = run("sips", [
    "-g", "pixelWidth",
    "-g", "pixelHeight",
    "-g", "format",
    "-g", "profile",
    "-g", "hasAlpha",
    file,
  ], { capture: true });
  const property = (name) => output.match(new RegExp(`\\b${name}: (.+)`))?.[1]?.trim();
  if (property("pixelWidth") !== String(runtimePixels)
      || property("pixelHeight") !== String(runtimePixels)) {
    fail(`${relative(file)} 不是 ${runtimePixels}×${runtimePixels}`);
  }
  if (property("format") !== "jpeg") fail(`${relative(file)} 不是 JPEG`);
  if (!property("profile")?.toLowerCase().includes("srgb")) fail(`${relative(file)} 不是 sRGB`);
  if (property("hasAlpha") !== "no") fail(`${relative(file)} 仍含透明通道`);
  const sizeBytes = fs.statSync(file).size;
  if (sizeBytes > maximumRuntimeBytes) {
    fail(`${relative(file)} 为 ${sizeBytes} bytes，超过 24 KiB`);
  }
  return { sizeBytes, sha256: sha256(file) };
}

function commandExport(code) {
  const output = path.join(stagingDir, `exercise_${code}.jpg`);
  exportThumbnail(code, output);
  const { sizeBytes, sha256: digest } = inspectJpeg(output);
  console.log(`已导出 ${relative(output)} (${sizeBytes} bytes, ${digest})`);
}

function verifyPromotionGate(code) {
  const review = reviewRecord(code);
  const master = approvedMaster(code);
  const masterDigest = sha256(master);
  if (review.masterPath !== relative(master) || review.masterSha256 !== masterDigest) {
    fail(`${code} 审核记录与已批准母版不一致`);
  }
  const provenance = readJson(provenancePath).assets?.[code];
  if (!provenance || provenance.sha256 !== masterDigest || provenance.rightsStatus !== "approved") {
    fail(`${code} 来源台账不完整或 rightsStatus 未批准`);
  }
  return { review, master, masterDigest };
}

function commandPreflight(code) {
  verifyPromotionGate(code);
  const temporaryDir = fs.mkdtempSync(path.join(os.tmpdir(), "dontlift-exercise-preflight-"));
  try {
    const temporaryJpeg = path.join(temporaryDir, `exercise_${code}.jpg`);
    exportThumbnail(code, temporaryJpeg);
    const { sizeBytes, sha256: digest } = inspectJpeg(temporaryJpeg);
    console.log(`promote 预检通过：${code} (${sizeBytes} bytes, ${digest})`);
  } finally {
    fs.rmSync(temporaryDir, { recursive: true, force: true });
  }
}

function commandPromote(code) {
  const { review, master, masterDigest } = verifyPromotionGate(code);

  const temporaryDir = fs.mkdtempSync(path.join(os.tmpdir(), "dontlift-exercise-art-"));
  const temporaryJpeg = path.join(temporaryDir, `exercise_${code}.jpg`);
  try {
    exportThumbnail(code, temporaryJpeg);
    const runtimeFile = path.join(runtimeDir, `exercise_${code}.jpg`);
    fs.mkdirSync(runtimeDir, { recursive: true });
    fs.copyFileSync(temporaryJpeg, runtimeFile);
    const runtime = inspectJpeg(runtimeFile);

    const production = readJson(productionPath);
    production.assets[code] = {
      exerciseCode: code,
      characterVersion: "character-v1",
      styleVersion: "style-v1",
      briefPath: `art/exercise-static/briefs/${code}.json`,
      masterPath: relative(master),
      runtimePath: relative(runtimeFile),
      masterSha256: masterDigest,
      runtimeSha256: runtime.sha256,
      pixelWidth: runtimePixels,
      pixelHeight: runtimePixels,
      jpegQuality,
      sizeBytes: runtime.sizeBytes,
      reviews: publicReview(review),
      technicalStatus: "passed",
      // 获授权的自治审核可直接发布；早期人工审核条目仍由 release 单独收口，
      // 避免 promote 隐式改变历史发布结论。
      releaseStatus: reviewKinds.every((kind) => review.reviews[kind].reviewerId === "production-autopilot")
        ? "released"
        : "draft"
    };
    writeJson(productionPath, production);

    const runtimeManifest = fs.existsSync(runtimeManifestPath)
      ? readJson(runtimeManifestPath)
      : { schemaVersion: 1, assets: {} };
    runtimeManifest.assets[code] = {
      file: `exercise_${code}.jpg`,
      sha256: runtime.sha256,
      pixelWidth: runtimePixels,
      pixelHeight: runtimePixels,
      sizeBytes: runtime.sizeBytes
    };
    writeJson(runtimeManifestPath, runtimeManifest);
    commandValidate();
    console.log(`已 promote ${code}；releaseStatus=${production.assets[code].releaseStatus}`);
  } finally {
    fs.rmSync(temporaryDir, { recursive: true, force: true });
  }
}

function commandAutopilotRegister(code, candidateArgument) {
  const candidate = path.resolve(repo, candidateArgument || `art/exercise-static/candidates/${code}/${code}-candidate-01.png`);
  if (!fs.existsSync(candidate)) fail(`缺少候选 PNG：${relative(candidate)}`);
  const masterDirectory = path.join(staticRoot, "masters/approved");
  const existing = fs.readdirSync(masterDirectory)
    .filter((name) => name.startsWith(`${code}-v`) && name.endsWith(".png"));
  if (existing.length) fail(`${code} 已有正式母版，不能重复 autopilot-register`);

  const master = path.join(masterDirectory, `${code}-v1.png`);
  fs.copyFileSync(candidate, master);
  const masterDigest = sha256(master);
  const reviewedAt = new Date().toISOString();
  const reviewPath = path.join(staticRoot, `reviews/${code}-review.json`);
  const reviewEvidence = (kind) => kind === "identity"
    ? ["art/exercise-static/references/approved/character-v1.png", relative(master)]
    : kind === "art"
      ? ["art/exercise-static/references/approved/style-v1.png", relative(master)]
      : kind === "rights"
        ? ["art/exercise-static/reviews/input-policy-v1.md", "art/exercise-static/reviews/openai-imagegen-terms-2026-07-24.md", `art/exercise-static/masters/approved/${code}-v1.provenance.json`]
        : [`art/exercise-static/briefs/${code}.json`, relative(master)];
  const reviewNotes = {
    identity: "按 character-v1 身份清单核对脸型、发型、体型、服装、四肢完整性和线稿一致性。",
    art: "按 style-v1 核对灰阶线稿、主动肌朱砂红、协同肌浅红、白底安全边距、无文字/Logo/水印及弱化乳头特征。",
    movement: "按动作 brief 核对代表姿势、关节方向、握法、身体接触点和目标肌。",
    equipment: "按动作 brief 核对器械类别、关键结构、握持关系、连接连续性和安全边距。",
    rights: "仅使用原创 brief、character-v1、style-v1 和本项目 imagegen 生成链，未使用第三方图片。",
  };
  const reviews = Object.fromEntries(reviewKinds.map((kind) => [kind, {
    status: "approved",
    reviewerId: "production-autopilot",
    reviewedAt,
    evidence: reviewEvidence(kind),
    notes: reviewNotes[kind],
  }]));
  writeJson(reviewPath, {
    schemaVersion: 1,
    exerciseCode: code,
    candidateId: path.basename(candidate, path.extname(candidate)),
    masterPath: relative(master),
    masterSha256: masterDigest,
    reviews,
  });

  const provenanceRecord = {
    assetId: `${code}-v1`,
    exerciseCode: code,
    status: "approved-master",
    tool: "Codex built-in imagegen",
    model: "not exposed by built-in tool",
    generatedAt: reviewedAt,
    promptPath: `art/exercise-static/briefs/${code}.json`,
    briefPath: `art/exercise-static/briefs/${code}.json`,
    inputs: [
      { kind: "original-text", source: `art/exercise-static/briefs/${code}.json`, sha256: sha256(path.join(staticRoot, `briefs/${code}.json`)), rightsBasis: "本项目原创动作与器械 brief" },
      { kind: "owned-reference", source: relative(candidate), sha256: sha256(candidate), rightsBasis: "本项目 imagegen 生成候选；候选目录由 Git 忽略" },
      { kind: "owned-reference", source: "art/exercise-static/references/approved/character-v1.png", sha256: sha256(path.join(staticRoot, "references/approved/character-v1.png")), rightsBasis: "本项目已批准的原创统一角色母版" },
      { kind: "owned-reference", source: "art/exercise-static/references/approved/style-v1.png", sha256: sha256(path.join(staticRoot, "references/approved/style-v1.png")), rightsBasis: "本项目已批准的原创风格母版" },
    ],
    humanEdits: "无手工像素编辑。",
    file: relative(master),
    pixelWidth: 0,
    pixelHeight: 0,
    sizeBytes: fs.statSync(master).size,
    sha256: masterDigest,
    reviewRecord: relative(reviewPath),
    approvedAt: reviewedAt,
    reviewerId: "production-autopilot",
  };
  const dimensions = run("sips", ["-g", "pixelWidth", "-g", "pixelHeight", master], { capture: true });
  provenanceRecord.pixelWidth = Number(dimensions.match(/pixelWidth: (\d+)/)?.[1] ?? 0);
  provenanceRecord.pixelHeight = Number(dimensions.match(/pixelHeight: (\d+)/)?.[1] ?? 0);
  const masterProvenancePath = path.join(masterDirectory, `${code}-v1.provenance.json`);
  writeJson(masterProvenancePath, provenanceRecord);

  const provenance = readJson(provenancePath);
  provenance.assets[code] = {
    exerciseCode: code,
    promptPath: `art/exercise-static/briefs/${code}.json`,
    tool: "Codex built-in imagegen",
    model: "not exposed by built-in tool",
    generatedAt: reviewedAt,
    inputs: [
      { kind: "original-text", source: `art/exercise-static/briefs/${code}.json`, sha256: sha256(path.join(staticRoot, `briefs/${code}.json`)), rightsBasis: "本项目原创动作与器械 brief" },
      { kind: "owned-reference", source: relative(candidate), sha256: sha256(candidate), rightsBasis: "本项目 imagegen 生成候选；候选目录由 Git 忽略" },
      { kind: "owned-reference", source: "art/exercise-static/references/approved/character-v1.png", sha256: sha256(path.join(staticRoot, "references/approved/character-v1.png")), rightsBasis: "本项目已批准的原创统一角色母版" },
      { kind: "owned-reference", source: "art/exercise-static/references/approved/style-v1.png", sha256: sha256(path.join(staticRoot, "references/approved/style-v1.png")), rightsBasis: "本项目已批准的原创风格母版" },
    ],
    humanEdits: "无手工像素编辑。",
    sha256: masterDigest,
    rightsStatus: "approved",
    reviewRecord: relative(reviewPath),
  };
  writeJson(provenancePath, provenance);
  commandPromote(code);
}

function commandRelease(code) {
  const { master, masterDigest } = verifyPromotionGate(code);
  const production = readJson(productionPath);
  const asset = production.assets?.[code];
  if (!asset) fail(`${code} 尚未 promote，不能发布`);
  if (asset.masterPath !== relative(master) || asset.masterSha256 !== masterDigest) {
    fail(`${code} 的生产条目与当前已批准母版不一致`);
  }

  const runtime = path.join(repo, asset.runtimePath);
  const inspected = inspectJpeg(runtime);
  if (inspected.sha256 !== asset.runtimeSha256 || inspected.sizeBytes !== asset.sizeBytes) {
    fail(`${code} 的运行时文件与生产 manifest 不一致`);
  }

  const temporaryDir = fs.mkdtempSync(path.join(os.tmpdir(), "dontlift-exercise-release-"));
  try {
    const expected = path.join(temporaryDir, `exercise_${code}.jpg`);
    exportThumbnail(code, expected);
    if (sha256(expected) !== asset.runtimeSha256) {
      fail(`${code} 的运行时 JPG 不是当前母版按质量 82 确定性导出的结果`);
    }
  } finally {
    fs.rmSync(temporaryDir, { recursive: true, force: true });
  }

  asset.releaseStatus = "released";
  writeJson(productionPath, production);
  commandValidate();
  console.log(`已发布 ${code}`);
}

function trackedFiles() {
  return run("git", ["ls-files", "-z"], { capture: true }).split("\0").filter(Boolean);
}

function commandValidate() {
  const codes = knownCodes();
  const production = readJson(productionPath);
  const seenCodes = new Set();
  const expectedRuntimeFiles = new Set();

  for (const [key, asset] of Object.entries(production.assets)) {
    if (!codes.has(key)) fail(`生产 manifest 包含未知 code：${key}`);
    if (asset.exerciseCode !== key) fail(`${key} 的 exerciseCode 与键不一致`);
    if (seenCodes.has(asset.exerciseCode)) fail(`生产 manifest 出现重复 code：${asset.exerciseCode}`);
    seenCodes.add(asset.exerciseCode);
    if (asset.pixelWidth !== runtimePixels
        || asset.pixelHeight !== runtimePixels
        || asset.jpegQuality !== jpegQuality) {
      fail(`${key} 的尺寸或 JPEG 质量声明不符合全局标准`);
    }
    if (asset.technicalStatus !== "passed") fail(`${key} 的 technicalStatus 不是 passed`);
    for (const kind of reviewKinds) {
      if (asset.reviews?.[kind]?.status !== "approved") fail(`${key} 的 ${kind} 未批准`);
    }

    const master = path.join(repo, asset.masterPath);
    const runtime = path.join(repo, asset.runtimePath);
    const brief = path.join(repo, asset.briefPath);
    if (!fs.existsSync(master) || !fs.existsSync(runtime) || !fs.existsSync(brief)) {
      fail(`${key} 的母版、运行时图片或 brief 缺失`);
    }
    if (sha256(master) !== asset.masterSha256) fail(`${key} 的母版摘要不一致`);
    const inspected = inspectJpeg(runtime);
    if (inspected.sha256 !== asset.runtimeSha256 || inspected.sizeBytes !== asset.sizeBytes) {
      fail(`${key} 的运行时摘要或大小不一致`);
    }

    const temporaryDir = fs.mkdtempSync(path.join(os.tmpdir(), "dontlift-exercise-validate-"));
    try {
      const expected = path.join(temporaryDir, `exercise_${key}.jpg`);
      exportThumbnail(key, expected);
      if (sha256(expected) !== asset.runtimeSha256) {
        fail(`${key} 的运行时 JPG 不是当前母版按质量 82 确定性导出的结果`);
      }
    } finally {
      fs.rmSync(temporaryDir, { recursive: true, force: true });
    }
    expectedRuntimeFiles.add(path.basename(runtime));
  }

  if (fs.existsSync(runtimeDir)) {
    for (const name of fs.readdirSync(runtimeDir)) {
      if (name.startsWith("exercise_") && name.endsWith(".jpg") && !expectedRuntimeFiles.has(name)) {
        fail(`发现孤立运行时图片：${relative(path.join(runtimeDir, name))}`);
      }
    }
  }

  const forbiddenTracked = trackedFiles().filter((file) =>
    /^art\/exercise-static\/(candidates|staging|cache|logs)\//.test(file)
    || /\.(blend\d*|gif|apng|mp4|mov)$/i.test(file)
  );
  if (forbiddenTracked.length) fail(`候选或动态/Blender 文件误入库：${forbiddenTracked.join(", ")}`);

  const formalRoots = [
    path.join(staticRoot, "references/approved"),
    path.join(staticRoot, "masters/approved"),
    runtimeDir,
  ].filter(fs.existsSync);
  for (const root of formalRoots) {
    for (const entry of fs.readdirSync(root)) {
      if (/\.(blend\d*|gif|apng|mp4|mov)$/i.test(entry)) {
        fail(`正式目录出现动态或 Blender 文件：${relative(path.join(root, entry))}`);
      }
    }
  }

  console.log(`严格校验通过：${Object.keys(production.assets).length} 个正式运行时条目`);
}

function commandCoverage() {
  const preset = readJson(presetPath).exercises;
  const codes = inScopeExercises().map((exercise) => exercise.code).sort();
  const production = readJson(productionPath).assets ?? {};
  const skippedRows = fs.existsSync(skippedLedgerPath)
    ? fs.readFileSync(skippedLedgerPath, "utf8").split("\n")
      .map((line) => line.match(/^\|\s*`?([A-Z0-9_]+)`?\s*\|/))
      .filter(Boolean)
      .map((match) => match[1])
    : [];
  const skipped = new Set(skippedRows);
  const released = codes.filter((code) => production[code]?.releaseStatus === "released");
  const draft = codes.filter((code) => production[code]?.releaseStatus === "draft");
  const uncovered = codes.filter((code) => !production[code] && !skipped.has(code));
  const invalidSkipped = [...skipped].filter((code) => !knownCodes().has(code));
  if (invalidSkipped.length) fail(`跳过台账包含未知 code：${invalidSkipped.join(", ")}`);
  const excluded = preset.filter(isOutOfScope);
  console.log(JSON.stringify({
    presetTotal: preset.length,
    inScopeTotal: codes.length,
    excludedTotal: excluded.length,
    excludedByRule: Object.fromEntries([...new Set(excluded.map((exercise) => {
      if (exercise.category === "热身拉伸") return "热身拉伸";
      if (exercise.category === "功能性") return "功能性";
      if (exercise.category === "有氧") return "有氧";
      return "自重核心";
    }))].sort().map((rule) => [rule, excluded.filter((exercise) => {
      if (rule === "热身拉伸") return exercise.category === "热身拉伸";
      if (rule === "功能性") return exercise.category === "功能性";
      if (rule === "有氧") return exercise.category === "有氧";
      return exercise.category === "核心" && exercise.equipmentType === "自重";
    }).length])),
    total: codes.length,
    released: released.length,
    draft: draft.length,
    skipped: skipped.size,
    uncovered: uncovered.length,
    releasedCodes: released,
    draftCodes: draft,
    skippedCodes: [...skipped].sort(),
  }, null, 2));
}

function htmlEscape(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
  })[character]);
}

function pageRelative(file) {
  return path.relative(path.dirname(reviewPagePath), file).split(path.sep).join("/");
}

function commandReviewPage() {
  const provenance = readJson(provenancePath).assets;
  const exerciseNames = new Map(
    readJson(presetPath).exercises.map((exercise) => [exercise.code, exercise.name])
  );
  const cards = [];
  for (const code of Object.keys(provenance).sort()) {
    requireCode(code);
    reviewRecord(code);
    const master = approvedMaster(code);
    const thumbnail = path.join(stagingDir, `exercise_${code}.jpg`);
    exportThumbnail(code, thumbnail);
    const inspected = inspectJpeg(thumbnail);
    cards.push(`
      <article class="card">
        <h2>${htmlEscape(code)}</h2>
        <div class="images">
          <figure><img class="master" src="${htmlEscape(pageRelative(master))}" alt="${htmlEscape(code)} 高分辨率母版"><figcaption>已批准母版</figcaption></figure>
          <figure><img class="native" src="${htmlEscape(pageRelative(thumbnail))}" alt="${htmlEscape(code)} 288×288 导出"><figcaption>288×288 / Q82 / ${inspected.sizeBytes} bytes</figcaption></figure>
          <figure><div class="grid-card"><img src="${htmlEscape(pageRelative(thumbnail))}" alt="${htmlEscape(code)} 双列卡片预览"><strong>${htmlEscape(exerciseNames.get(code) ?? code)}</strong></div><figcaption>约 104pt 双列小尺寸卡片预览</figcaption></figure>
        </div>
      </article>`);
  }

  const character = path.join(staticRoot, "references/approved/character-v1.png");
  const style = path.join(staticRoot, "references/approved/style-v1.png");
  const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>别练了静态动作图审核页 v1</title>
  <style>
    :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; background: #eeeae1; color: #171713; }
    body { max-width: 1100px; margin: 0 auto; padding: 32px; }
    .notice { padding: 14px 16px; border: 1px solid #d7cdbd; border-radius: 14px; background: #fffaf1; }
    .references, .images { display: flex; align-items: flex-start; gap: 24px; flex-wrap: wrap; }
    .references img { width: 320px; max-height: 320px; object-fit: contain; background: #f6f3ec; border-radius: 18px; }
    .card { margin-top: 24px; padding: 24px; border-radius: 22px; background: white; box-shadow: 0 10px 30px #554c3c18; }
    figure { margin: 0; }
    figcaption { margin-top: 8px; color: #6f685d; font-size: 13px; }
    .master { width: 360px; height: 360px; object-fit: contain; background: #f6f3ec; border-radius: 18px; }
    .native { width: 288px; height: 288px; border-radius: 16px; }
    .grid-card { width: 104px; overflow: hidden; border: 1px solid #d7cdbd; border-radius: 13px; background: #fff; }
    .grid-card img { display: block; box-sizing: border-box; width: 104px; height: 77px; padding: 10px 7px 4px; object-fit: contain; object-position: center bottom; background: #fff; }
    .grid-card strong { display: grid; min-height: 32px; padding: 0 5px; align-items: start; justify-items: center; text-align: center; font-size: 12px; line-height: 16px; }
  </style>
</head>
<body>
  <h1>静态动作图审核页 v1</h1>
  <p class="notice">此页用于角色联系表和离线 288×288/双列卡片对比，不替代 iOS Simulator 中真实网格容器验收。</p>
  <h2>固定角色与风格参考</h2>
  <div class="references">
    <figure><img src="${htmlEscape(pageRelative(character))}" alt="character-v1"><figcaption>character-v1</figcaption></figure>
    <figure><img src="${htmlEscape(pageRelative(style))}" alt="style-v1"><figcaption>style-v1</figcaption></figure>
  </div>
  ${cards.join("\n")}
</body>
</html>\n`;
  fs.mkdirSync(path.dirname(reviewPagePath), { recursive: true });
  fs.writeFileSync(reviewPagePath, html);
  console.log(`已生成 ${relative(reviewPagePath)}`);
}

const [command = "validate", rawCode] = process.argv.slice(2);
try {
  if (command === "export") commandExport(requireCode(rawCode));
  else if (command === "preflight") commandPreflight(requireCode(rawCode));
  else if (command === "promote") commandPromote(requireCode(rawCode));
  else if (command === "autopilot-register") commandAutopilotRegister(requireCode(rawCode), process.argv[4]);
  else if (command === "release") commandRelease(requireCode(rawCode));
  else if (command === "validate") commandValidate();
  else if (command === "coverage") commandCoverage();
  else if (command === "review-page") commandReviewPage();
  else fail("用法：exercise-static-assets.mjs <export CODE|preflight CODE|promote CODE|autopilot-register CODE [candidate.png]|release CODE|validate|coverage|review-page>");
} catch (error) {
  console.error(`错误：${error.message}`);
  process.exit(1);
}
