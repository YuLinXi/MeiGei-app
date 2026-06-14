# 后端生产部署（自托管 Ubuntu + 共享基础设施 + Docker Compose）

面向「一台服务器跑多套后端服务」的部署。分两层：

- **共享基础设施**（服务器级，所有服务共用一次搭好）：见 `deploy/shared-infra/`
  - 共享反向代理 Caddy：唯一占 80/443，按域名分发，自动 HTTPS。
  - 共享 PostgreSQL 16：多服务各用独立 database + 角色。
- **DontLift 业务栈**（本目录 `docker-compose.prod.yml`）：只含 app，接入共享网络。

```
iOS App ─HTTPS(443)─▶ edge-caddy ─(web 网络)─▶ dontlift-app:8080 ─(dbnet 网络)─▶ shared-postgres/dontlift
                          └─▶ 其它服务…(同一反代、同一 PG 实例不同库)
```

Flyway 在 app 启动时自动对 `dontlift` 库建表/迁移。

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
cp -r /path/to/DontLift-app/backend/deploy/shared-infra/db ./db && cd db
cp .env.example .env      # 填 POSTGRES_SUPERPASS、DONTLIFT_DB_PASSWORD（openssl rand -base64 24）
docker compose up -d      # 首次自动建 dontlift 库 + 角色

# 共享反代
cd /opt/stacks
cp -r /path/to/DontLift-app/backend/deploy/shared-infra/edge ./edge && cd edge
cat Caddyfile             # 已预填 dontlift.peipadada.com，确认无误即可
docker compose up -d
```

> DNS：把 `api.你的域名.com` 的 A 记录指向服务器公网 IP；安全组放行 **80、443**，确认 5432 未对公网开放。备案域名需已备案完成。

## 三、部署 DontLift 业务栈

> 注：本项目**实际首次部署用的是 `backend/deploy/local-deploy.sh`**（rsync 同步，非 git clone），因此服务器 `/opt/DontLift-app` **不是 git 仓库**，后续更新见第五节、**不能 `git pull`**。下面的手动 clone 仅作全新服务器的通用参考。

```bash
sudo mkdir -p /opt && cd /opt
git clone <你的仓库地址> DontLift-app
cd DontLift-app/backend

cp .env.prod.example .env.prod
openssl rand -base64 48   # → JWT_SECRET
nano .env.prod            # 填 JWT_SECRET / APPLE_AUDIENCES(真实 Bundle ID) /
                          #    DB_PASSWORD（=共享 PG 的 DONTLIFT_DB_PASSWORD，两边必须一致）

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

**备份**（dontlift 库，建议 cron）：
```bash
crontab -e
30 3 * * * cd /opt/DontLift-app/backend && ./scripts/db-backup.sh >> /var/log/dontlift-backup.log 2>&1
```
恢复：`gunzip -c backups/dontlift_xxx.sql.gz | docker exec -i shared-postgres psql -U dontlift -d dontlift`

**更新 DontLift**（Flyway 自动跑新增 `V2__*.sql` 等迁移）：

> ⚠️ **服务器代码不是 git 仓库**（首次由本机同步上来，`/opt/DontLift-app` 下只有 `backend/`，无 `.git`）。**不要用 `git pull`**——用本机一键脚本，从本机仓库根目录执行：

```bash
./backend/deploy/local-deploy.sh root@124.222.79.121
# 内部：rsync 同步源码（排除 .env.prod/secrets）→ 远程 server-bootstrap.sh → docker compose up -d --build → health 自检
```

> ⚠️ **已知隐患**：`local-deploy.sh` 的 `rsync --delete` **未排除 `backups/`**，会误删服务器上的数据库备份。修脚本前，建议改用下面这套**不带 `--delete`、显式排除备份**的手动同步（2026-06-14 第二次发版实测可用）：

```bash
# 1) 本机仓库根目录：同步源码（保护密钥与备份，build/产物不传）
rsync -rlptz --exclude='.env.prod' --exclude='secrets/' --exclude='backups/' \
  --exclude='build/' --exclude='.gradle/' --exclude='.git/' --exclude='.idea/' \
  backend/ root@124.222.79.121:/opt/DontLift-app/backend/
# 2) 远程重建并启动（Flyway 启动时自动迁移）
ssh root@124.222.79.121 'cd /opt/DontLift-app/backend && \
  docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build'
# 3) 验证：日志 Flyway 迁移 + Started、health UP、flyway_schema_history 到最新版本
```

**加一套新服务**：见 `deploy/shared-infra/README.md` 的「新增一套服务」（建库 → 写 compose 接 web+dbnet → Caddyfile 加域名块热重载）。

## 六、上线检查清单

- [ ] `docker network create web && dbnet` 已建；共享 PG、edge 反代已起
- [ ] `.env.prod` 的 `DB_PASSWORD` == 共享 PG 的 `DONTLIFT_DB_PASSWORD`
- [ ] `JWT_SECRET` 强随机、`APP_DEV_TOKEN=false`、`APPLE_AUDIENCES`=真实 Bundle ID
- [ ] `edge/Caddyfile` 域名已改、DNS 生效、80/443 放行
- [ ] `/actuator/health` 返回 UP、HTTPS 证书正常
- [ ] 备份 cron 配好并跑通一次

---

## 七、从 meigei 迁移到 dontlift（产品改名，一次性剧本）

产品于 2026-06 由「MeiGei」改名「别练了（Don't Lift）」。已部署的腾讯云服务器上旧栈仍叫 `meigei-*`，按以下顺序切换（产品未上线，**不保留旧数据**，全新建库最省事）：

```bash
# 0) DNS：在域名服务商给 peipadada.com 加 A 记录 dontlift → 服务器公网 IP
#    （peipadada.com 主域已备案，子域一般无需单独备案，留意服务商要求）

# 1) 共享 PG 里新建库/角色（init 脚本只在 PG 首次初始化时跑，存量实例须手工建）
docker exec -it shared-postgres psql -U postgres \
  -c "CREATE ROLE dontlift WITH LOGIN PASSWORD '<openssl rand -base64 24 生成>';" \
  -c "CREATE DATABASE dontlift OWNER dontlift;"
#    同步把 /opt/stacks/db/.env 里的 MEIGEI_DB_PASSWORD 行改成 DONTLIFT_DB_PASSWORD=<同上>（作记录用）

# 2) 拉新代码（目录可顺手 mv 成 /opt/DontLift-app；mv 后记得改 crontab 里备份任务的 cd 路径）
cd /opt/MeiGei-app && git pull
cd backend && nano .env.prod
#    改三处：DB_PASSWORD=<新密码>、APNS_TOPIC=com.yulinxi.app.DontLift、APPLE_AUDIENCES=com.yulinxi.app.DontLift

# 3)（可选）保留旧测试数据：
#    docker exec shared-postgres pg_dump -U meigei meigei | docker exec -i shared-postgres psql -U dontlift dontlift
#    未上线建议跳过，让 Flyway 在新库全新建表（V1 注释已变，旧库 checksum 对不上，新库无此问题）

# 4) 起新栈（container_name 已是 dontlift-app）
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
docker compose -f docker-compose.prod.yml logs -f app   # 看 Flyway 建表 + Spring UP

# 5) 更新边缘反代：用仓库新版 Caddyfile 覆盖 /opt/stacks/edge/Caddyfile
#    （dontlift.peipadada.com → dontlift-app:8080；过渡期可新旧两个域名块并存）
cd /opt/stacks/edge && docker compose restart
curl -s https://dontlift.peipadada.com/actuator/health   # 期望 {"status":"UP"}

# 6) 验证通过后下线旧栈（顺序：旧容器 → Caddy 旧域名块 → 旧库/角色 → 旧 DNS 记录）
docker rm -f meigei-app
# Caddyfile 删 meigei.peipadada.com 块后 docker compose restart
docker exec -it shared-postgres psql -U postgres -c "DROP DATABASE meigei;" -c "DROP ROLE meigei;"
```

**Apple Developer 侧（bundle ID 变更 = 全新 App）：**

- developer.apple.com → Identifiers 新建 App ID `com.yulinxi.app.DontLift`，勾 Sign in with Apple、HealthKit、Push Notifications；另建 widget ID `com.yulinxi.app.DontLift.DontLiftWidgets`。
- APNs 的 `.p8` 密钥是 Team 级的，**可复用**，只需 `.env.prod` 的 `APNS_TOPIC` 改成新 bundle ID。
- Xcode automatic signing 会对新 bundle ID 自动生成 provisioning profile。
- App Store Connect 后续以新 bundle ID 新建 App「别练了」；旧 MeiGei App 记录（若建过）废弃。
- 旧装机的 Keychain/UserDefaults/SwiftData 数据不随新 App 迁移（沙盒不同），测试设备直接删旧 App。
