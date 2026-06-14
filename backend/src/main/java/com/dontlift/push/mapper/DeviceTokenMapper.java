package com.dontlift.push.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.push.entity.DeviceToken;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;

import java.util.UUID;

public interface DeviceTokenMapper extends BaseMapper<DeviceToken> {

    // 账号删除：清该 user 的所有设备 token
    @Delete("DELETE FROM device_token WHERE user_id = #{userId}")
    int deleteAllByUser(@Param("userId") UUID userId);
}
