# 服务器级共享基础设施

这一层与 DontLift 业务**解耦**，是「一台服务器跑多套后端服务」的公共底座：

- `edge/` —— 共享反向代理（Caddy），全机唯一占用 80/443，按域名把流量分发到各业务容器，自动管 HTTPS 证书。
- `db/` —— 共享 PostgreSQL 16 实例，多套服务各用独立 database + 角色（逻辑隔离）。

> 这些文件恰好放在 DontLift 仓库里方便维护，但它们不属于 DontLift 业务。部署时拷到服务器的 `/opt/stacks/` 独立目录，由所有服务共用。

## 拓扑

```
                         ┌─────────────── edge-caddy (80/443) ──────────────┐
   iOS App ─HTTPS─▶ 域名 ─┤  api.dontlift.com → dontlift-app:8080                 │
   其它客户端       ─────┤  other.com      → other-app:9000   ...           │
                         └──────────────────────┬───────────────────────────┘
                                    network: web │ (反代 ↔ 各 app)
                         ┌──────────────────────┴───────────────────────────┐
                         │  dontlift-app   other-app   ...   各业务栈(独立部署) │
                         └──────────────────────┬───────────────────────────┘
                                  network: dbnet │ (app ↔ 数据库)
                                       shared-postgres (dontlift 库 / other 库 / ...)
```

## 首次搭建（按顺序，仅一次）

```bash
# 0) 两个共享网络（各业务栈以 external 接入）
docker network create web
docker network create dbnet

# 1) 共享数据库
sudo mkdir -p /opt/stacks && cd /opt/stacks
cp -r <仓库>/backend/deploy/shared-infra/db ./db && cd db
cp .env.example .env       # 填 POSTGRES_SUPERPASS 和 DONTLIFT_DB_PASSWORD
docker compose up -d
# 首次启动会自动建 dontlift 库 + 角色（init/01-create-databases.sh）

# 2) 共享反代
cd /opt/stacks
cp -r <仓库>/backend/deploy/shared-infra/edge ./edge && cd edge
cat Caddyfile              # 已预填 dontlift.peipadada.com，确认无误即可
docker compose up -d
```

之后各业务栈（如 DontLift，见 `backend/DEPLOY.md`）只要接入 `web` + `dbnet` 即可上线。

## 单域名多服务：用子域名路由（推荐）

只有一个备案主域名 `example.com`、却要服务多个应用时，按**子域名**分，而不是按路径分：

```
api.example.com    → dontlift-app:8080
admin.example.com  → admin-app:8090
blog.example.com   → blog-app:3000
```

- **备案**：子域名继承主域名备案，无需单独备案（同主体、同服务器即可）。
- **证书**：Caddy 为每个子域名各自自动签 Let's Encrypt，零配置。
- **后端零改动**：每个服务都在自己域名的根路径 `/`，不用配 context-path。

要做的只有两步：
1. **DNS**：加一条泛解析 `*.example.com → 服务器IP`（一劳永逸），或每个子域名各加一条 A 记录。
2. **Caddyfile**：加一个域名块（见下节），热重载生效。

> 不要走「`example.com/api`、`example.com/admin`」的路径前缀方案：后端的绝对链接 / 重定向 / Swagger 路径 / Cookie path 常和前缀错位，排查痛苦。原生 App + REST 场景用子域名最干净。

## 新增一套服务（Java / Go / Node 都一样）

1. **建库**（共享 PG 已初始化过，用手动命令）：
   ```bash
   docker exec -it shared-postgres psql -U postgres -c \
     "CREATE ROLE otherapp LOGIN PASSWORD '强密码'; CREATE DATABASE otherapp OWNER otherapp;"
   ```
2. **写该服务的 compose**：app 接入 `web` 和 `dbnet`（external），不要自带反代/PG，连接串指向 `shared-postgres:5432/otherapp`。
3. **加路由**：在 `edge/Caddyfile` 加一个域名块 → 该服务容器名:端口，然后热重载：
   ```bash
   docker compose -f /opt/stacks/edge/docker-compose.yml exec caddy \
     caddy reload --config /etc/caddy/Caddyfile
   ```

## 备份（共享实例上的所有库）

`backend/scripts/db-backup.sh` 备份的是 dontlift 库。要整实例备份所有库：
```bash
docker exec -t shared-postgres pg_dumpall -U postgres | gzip > all_$(date +%F).sql.gz
```
