package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.TeamPlanShareEvent;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Param;

import java.util.UUID;

public interface TeamPlanShareEventMapper extends BaseMapper<TeamPlanShareEvent> {

    @Insert("""
            INSERT INTO team_plan_share_event (
                id, team_id, share_id, version_id, user_id, event_type, workout_id, event_date, created_at
            ) VALUES (
                #{event.id}, #{event.teamId}, #{event.shareId}, #{event.versionId},
                #{event.userId}, #{event.eventType}, #{event.workoutId}, #{event.eventDate}, #{event.createdAt}
            )
            ON CONFLICT (version_id, event_type, user_id, workout_id)
                WHERE workout_id IS NOT NULL
            DO NOTHING
            """)
    int insertIgnoreDuplicate(@Param("event") TeamPlanShareEvent event);

    @Delete("DELETE FROM team_plan_share_event WHERE user_id = #{userId}")
    int deleteByUser(@Param("userId") UUID userId);

    @Delete("DELETE FROM team_plan_share_event WHERE team_id = #{teamId}")
    int deleteByTeam(@Param("teamId") UUID teamId);
}
