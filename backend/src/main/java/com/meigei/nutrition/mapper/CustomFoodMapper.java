package com.meigei.nutrition.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.meigei.nutrition.entity.CustomFood;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface CustomFoodMapper extends BaseMapper<CustomFood> {

    // 同步用：绕过 @TableLogic，下发含软删墓碑的变更
    @Select("""
            SELECT * FROM custom_food
            WHERE user_id = #{userId}
              AND (CAST(#{since} AS timestamptz) IS NULL OR updated_at > CAST(#{since} AS timestamptz))
            ORDER BY updated_at
            """)
    List<CustomFood> findChangesSince(@Param("userId") UUID userId,
                                      @Param("since") OffsetDateTime since);

    @Select("SELECT * FROM custom_food WHERE id = #{id}")
    CustomFood findByIdIncludingDeleted(@Param("id") UUID id);

    // 写入墓碑：updateById 不会动 @TableLogic 字段，故显式 SQL
    @Update("""
            UPDATE custom_food
            SET deleted_at = #{deletedAt}, updated_at = #{updatedAt}, version = #{version}
            WHERE id = #{id}
            """)
    int softDelete(@Param("id") UUID id, @Param("deletedAt") OffsetDateTime deletedAt,
                   @Param("updatedAt") OffsetDateTime updatedAt, @Param("version") int version);
}
