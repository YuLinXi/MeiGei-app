-- 账号删除时主动撤销 Apple 授权需要 refresh_token：登录回传 authorization_code 换取后持久化于此。
-- 可空：老客户端/静默登录无 code、或服务端无 .p8 凭据时该列保持 NULL，删号走降级（仅本地删除）。
ALTER TABLE user_identity ADD COLUMN apple_refresh_token text;
