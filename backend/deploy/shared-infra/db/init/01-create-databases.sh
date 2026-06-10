#!/bin/bash
# 共享 PG 首次初始化时，为各业务创建独立 database + 角色（逻辑隔离）。
# 注意：仅在数据卷 pgdata 为空的首次启动执行；之后新增服务的建库见 README「手动加库」。
set -e

# ── DontLift ──
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	CREATE ROLE dontlift WITH LOGIN PASSWORD '${DONTLIFT_DB_PASSWORD}';
	CREATE DATABASE dontlift OWNER dontlift;
EOSQL
echo "已创建 database=dontlift / role=dontlift"

# ── 新增服务样例（首次初始化前加在这里；已初始化过的实例改用 README 的手动命令）──
# psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
# 	CREATE ROLE otherapp WITH LOGIN PASSWORD '${OTHERAPP_DB_PASSWORD}';
# 	CREATE DATABASE otherapp OWNER otherapp;
# EOSQL
