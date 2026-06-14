package com.dontlift.workout.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.workout.entity.WorkoutPlan;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface WorkoutPlanMapper extends BaseMapper<WorkoutPlan> {

    // 账号删除：物理硬删该 user 全部训练计划（绕过 @TableLogic 墓碑）
    @Delete("DELETE FROM workout_plan WHERE user_id = #{userId}")
    int deleteAllByUser(@Param("userId") UUID userId);

    // 写入墓碑：updateById 不会动 @TableLogic 字段，故显式 SQL
    @Update("""
            UPDATE workout_plan
            SET deleted_at = #{deletedAt}, updated_at = #{updatedAt}, version = #{version}
            WHERE id = #{id}
            """)
    int softDelete(@Param("id") UUID id, @Param("deletedAt") OffsetDateTime deletedAt,
                   @Param("updatedAt") OffsetDateTime updatedAt, @Param("version") int version);

    @Select("""
            SELECT * FROM workout_plan
            WHERE user_id = #{userId}
              AND (CAST(#{since} AS timestamptz) IS NULL OR updated_at > CAST(#{since} AS timestamptz))
            ORDER BY updated_at
            """)
    List<WorkoutPlan> findChangesSince(@Param("userId") UUID userId,
                                       @Param("since") OffsetDateTime since);

    @Select("SELECT * FROM workout_plan WHERE id = #{id}")
    WorkoutPlan findByIdIncludingDeleted(@Param("id") UUID id);

    // Team 内浏览：某 Team 已发布且未删除的模板
    @Select("""
            SELECT * FROM workout_plan
            WHERE shared_to_team_id = #{teamId} AND deleted_at IS NULL
            ORDER BY updated_at DESC
            """)
    List<WorkoutPlan> findSharedToTeam(@Param("teamId") UUID teamId);
}
