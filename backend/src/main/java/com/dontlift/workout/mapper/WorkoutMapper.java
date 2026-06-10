package com.dontlift.workout.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.workout.entity.Workout;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface WorkoutMapper extends BaseMapper<Workout> {

    // 写入墓碑：updateById 不会动 @TableLogic 字段，故显式 SQL
    @Update("""
            UPDATE workout
            SET deleted_at = #{deletedAt}, updated_at = #{updatedAt}, version = #{version}
            WHERE id = #{id}
            """)
    int softDelete(@Param("id") UUID id, @Param("deletedAt") OffsetDateTime deletedAt,
                   @Param("updatedAt") OffsetDateTime updatedAt, @Param("version") int version);

    @Select("""
            SELECT * FROM workout
            WHERE user_id = #{userId}
              AND (CAST(#{since} AS timestamptz) IS NULL OR updated_at > CAST(#{since} AS timestamptz))
            ORDER BY updated_at
            """)
    List<Workout> findChangesSince(@Param("userId") UUID userId,
                                   @Param("since") OffsetDateTime since);

    @Select("SELECT * FROM workout WHERE id = #{id}")
    Workout findByIdIncludingDeleted(@Param("id") UUID id);
}
