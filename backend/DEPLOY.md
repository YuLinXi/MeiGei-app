# 后端生产部署（自托管 Ubuntu + 共享基础设施 + Docker Compose）

面向「一台服务器跑多套后端服务」的部署。分两层：

- **共享基础设施**（服务器级，所有服务共用一次搭好）：见 `deploy/shared-infra/`
  - 共享反向代理 Caddy：唯一占 80/443，按域名分发，自动 HTTPS。
  - 共享 PostgreSQL 16：多服务各用独立 database + 角色。
- **MeiGei 业务栈**（本目录 `docker-compose.prod.yml`）：只含 app，接入共享网络。

```
iOS App ─HTTPS(443)─▶ edge-caddy ─(web 网络)─▶ meigei-app:8080 ─(dbnet 网络)─▶ shared-postgres/meigei
                          └─▶ 其它服务…(同一反代、同一 PG 实例不同库)
```

Flyway 在 app 启动时自动对 `meigei` 库建表/迁移。

---

## 一、装 Docker（Ubuntu，仅一次）

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # 重新登录后免 sudo
docker --version && docker compose version
```

## 二、搭共享基础设施（仅一次，详见 deploy/shared-infra/README.md）

```bash
docker network create web && docker network create dbnet

# 共享 PG
sudo mkdir -p /opt/stacks && cd /opt/stacks
cp -r /path/to/MeiGei-app/backend/deploy/shared-infra/db ./db && cd db
cp .env.example .env      # 填 POSTGRES_SUPERPASS、MEIGEI_DB_PASSWORD（openssl rand -base64 24）
docker compose up -d      # 首次自动建 meigei 库 + 角色

# 共享反代
cd /opt/stacks
cp -r /path/to/MeiGei-app/backend/deploy/shared-infra/edge ./edge && cd edge
nano Caddyfile            # api.meigei-example.com → 改成你的真实域名
docker compose up -d
```

> DNS：把 `api.你的域名.com` 的 A 记录指向服务器公网 IP；安全组放行 **80、443**，确认 5432 未对公网开放。备案域名需已备案完成。

## 三、部署 MeiGei 业务栈

```bash
sudo mkdir -p /opt && cd /opt
git clone <你的仓库地址> MeiGei-app
cd MeiGei-app/backend

cp .env.prod.example .env.prod
openssl rand -base64 48   # → JWT_SECRET
nano .env.prod            # 填 JWT_SECRET / APPLE_AUDIENCES(真实 Bundle ID) /
                          #    DB_PASSWORD（=共享 PG 的 MEIGEI_DB_PASSWORD，两边必须一致）

docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
docker compose -f docker-compose.prod.yml logs -f app   # 看 Flyway 建表 + Spring 起来
```

> APNs 可后补：`.p8` 放 `backend/secrets/apns.p8`，取消 compose 里 app 的 volumes 注释，`.env.prod` 填 `APNS_KEY_ID`/`APNS_TEAM_ID`。未配置时推送静默跳过。

## 四、验证

```bash
curl https://api.你的域名.com/actuator/health     # 期望 {"status":"UP"}
```

iOS 端把 `APIClient` 的 baseURL 改为 `https://api.你的域名.com`（生产 HTTPS 无需 ATS `NSAllowsLocalNetworking`）。

## 五、运维

**备份**（meigei 库，建议 cron）：
```bash
crontab -e
30 3 * * * cd /opt/MeiGei-app/backend && ./scripts/db-backup.sh >> /var/log/meigei-backup.log 2>&1
```
恢复：`gunzip -c backups/meigei_xxx.sql.gz | docker exec -i shared-postgres psql -U meigei -d meigei`

**更新 MeiGei**（Flyway 自动跑新增 `V2__*.sql`）：
```bash
cd /opt/MeiGei-app/backend && git pull
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

**加一套新服务**：见 `deploy/shared-infra/README.md` 的「新增一套服务」（建库 → 写 compose 接 web+dbnet → Caddyfile 加域名块热重载）。

## 六、上线检查清单

- [ ] `docker network create web && dbnet` 已建；共享 PG、edge 反代已起
- [ ] `.env.prod` 的 `DB_PASSWORD` == 共享 PG 的 `MEIGEI_DB_PASSWORD`
- [ ] `JWT_SECRET` 强随机、`APP_DEV_TOKEN=false`、`APPLE_AUDIENCES`=真实 Bundle ID
- [ ] `edge/Caddyfile` 域名已改、DNS 生效、80/443 放行
- [ ] `/actuator/health` 返回 UP、HTTPS 证书正常
- [ ] 备份 cron 配好并跑通一次
