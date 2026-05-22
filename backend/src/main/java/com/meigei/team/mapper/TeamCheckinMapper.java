package com.meigei.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.meigei.team.entity.TeamCheckin;
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

    @Select("SELECT * FROM team_checkin WHERE team_id = #{teamId} AND checkin_date = #{date} ORDER BY created_at DESC")
    List<TeamCheckin> findByTeamAndDate(@Param("teamId") UUID teamId, @Param("date") LocalDate date);
}
