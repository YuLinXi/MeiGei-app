package com.dontlift.account.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.account.entity.UserIdentity;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

import java.util.UUID;

public interface UserIdentityMapper extends BaseMapper<UserIdentity> {

    // 登录回传 authorizationCode 换得 refresh_token 后持久化（仅更新该列，避免覆盖其它字段）
    @Update("UPDATE user_identity SET apple_refresh_token = #{token}, updated_at = now() WHERE id = #{id}")
    int updateRefreshToken(@Param("id") UUID id, @Param("token") String token);

    // 账号删除：清该 user 的所有登录身份（物理删）
    @Delete("DELETE FROM user_identity WHERE user_id = #{userId}")
    int deleteAllByUser(@Param("userId") UUID userId);
}
