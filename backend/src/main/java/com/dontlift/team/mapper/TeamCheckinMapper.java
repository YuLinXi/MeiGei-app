package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.TeamCheckin;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface TeamCheckinMapper extends BaseMapper<TeamCheckin> {

    @Select("SELECT * FROM team_checkin WHERE team_id = #{teamId} AND user_id = #{userId} AND workout_id = #{workoutId}")
    TeamCheckin findByTeamUserWorkout(@Param("teamId") UUID teamId,
                                      @Param("userId") UUID userId,
                                      @Param("workoutId") UUID workoutId);

    /** 训练被删除时连带清打卡（reactions 由 checkin_reaction 的 ON DELETE CASCADE 自动清理）。 */
    @Delete("DELETE FROM team_checkin WHERE user_id = #{userId} AND workout_id = #{workoutId}")
    int deleteByUserWorkout(@Param("userId") UUID userId, @Param("workoutId") UUID workoutId);

    @Select("SELECT * FROM team_checkin WHERE team_id = #{teamId} AND checkin_date = #{date} ORDER BY created_at DESC")
    List<TeamCheckin> findByTeamAndDate(@Param("teamId") UUID teamId, @Param("date") LocalDate date);

    // 账号删除：本人打卡 + 本人作为 owner 的团队的全部打卡（其 reactions 由 ON DELETE CASCADE 连带清理）
    @Delete("""
            DELETE FROM team_checkin
            WHERE user_id = #{userId}
               OR team_id IN (SELECT id FROM team WHERE owner_user_id = #{userId})
            """)
    int deleteByUserOrOwnedTeams(@Param("userId") UUID userId);
}
