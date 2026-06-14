package com.dontlift.idempotency.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.idempotency.entity.IdempotencyKey;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;

import java.util.UUID;

public interface IdempotencyKeyMapper extends BaseMapper<IdempotencyKey> {

    // 账号删除：清该 user 的所有幂等键
    @Delete("DELETE FROM idempotency_key WHERE user_id = #{userId}")
    int deleteAllByUser(@Param("userId") UUID userId);
}
