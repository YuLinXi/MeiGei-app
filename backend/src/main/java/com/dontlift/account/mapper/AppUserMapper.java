package com.dontlift.account.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.account.entity.AppUser;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.UUID;

public interface AppUserMapper extends BaseMapper<AppUser> {

    @Select("SELECT * FROM app_user WHERE id = #{userId}")
    AppUser findByIdIncludingDeleted(@Param("userId") UUID userId);

    @Update("""
            UPDATE app_user
            SET display_name = CASE
                    WHEN display_name IS NULL OR btrim(display_name) = '' THEN #{displayName}
                    ELSE display_name
                END,
                first_login_email = COALESCE(first_login_email, #{email}),
                sex = COALESCE(sex, #{sex}),
                deleted_at = NULL,
                updated_at = now(),
                version = version + 1
            WHERE id = #{userId}
            """)
    int restoreDevProfile(@Param("userId") UUID userId,
                          @Param("displayName") String displayName,
                          @Param("email") String email,
                          @Param("sex") String sex);

    // 账号删除：物理硬删（BaseMapper.deleteById 因 @TableLogic 仅写墓碑，故显式 SQL）
    @Delete("DELETE FROM app_user WHERE id = #{userId}")
    int hardDeleteById(@Param("userId") UUID userId);
}
