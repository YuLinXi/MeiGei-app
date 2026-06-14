-- 首登资料补全：用户画像落后端（服务端权威域，非 LWW 同步）。
-- 称呼复用既有 display_name；本迁移新增性别一列。
-- sex 可空（不设默认）：null = 从未设置，区别于「用户显式选了男」。客户端回灌时 null 保留本地值，
--   避免服务端默认值覆盖存量用户本地已选的性别；展示层缺省按男渲染。
--   「是否已补全」由 display_name（称呼）是否为空判定，与 sex 无关。
ALTER TABLE app_user ADD COLUMN sex text CHECK (sex IN ('male', 'female'));
