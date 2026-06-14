package com.dontlift.account.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.account.entity.AppUser;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;

import java.util.UUID;

public interface AppUserMapper extends BaseMapper<AppUser> {

    // 账号删除：物理硬删（BaseMapper.deleteById 因 @TableLogic 仅写墓碑，故显式 SQL）
    @Delete("DELETE FROM app_user WHERE id = #{userId}")
    int hardDeleteById(@Param("userId") UUID userId);
}
