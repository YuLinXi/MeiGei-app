package com.dontlift.push.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.push.entity.DeviceToken;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Param;

import java.util.UUID;

public interface DeviceTokenMapper extends BaseMapper<DeviceToken> {

    /**
     * 原子注册/更新设备 token：token 已存在则改归属与环境（避免「先查后插」并发竞态撞 uq_apns_token）。
     */
    @Insert("""
            INSERT INTO device_token (id, user_id, apns_token, environment, created_at, updated_at)
            VALUES (#{id}, #{userId}, #{apnsToken}, #{environment}, now(), now())
            ON CONFLICT (apns_token) DO UPDATE
               SET user_id = excluded.user_id,
                   environment = excluded.environment,
                   updated_at = now()
            """)
    int upsertByApnsToken(DeviceToken dt);

    // 账号删除：清该 user 的所有设备 token
    @Delete("DELETE FROM device_token WHERE user_id = #{userId}")
    int deleteAllByUser(@Param("userId") UUID userId);
}
