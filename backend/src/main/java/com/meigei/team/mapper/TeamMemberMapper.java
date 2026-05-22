package com.meigei.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.meigei.team.entity.TeamMember;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

public interface TeamMemberMapper extends BaseMapper<TeamMember> {

    @Select("SELECT count(*) FROM team_member WHERE team_id = #{teamId}")
    int countByTeam(@Param("teamId") UUID teamId);

    // 用户当前所在的未解散 Team 数（用于 ≤3 上限校验）
    @Select("""
            SELECT count(*) FROM team_member m
            JOIN team t ON t.id = m.team_id
            WHERE m.user_id = #{userId} AND t.deleted_at IS NULL
            """)
    int countActiveByUser(@Param("userId") UUID userId);

    @Select("SELECT * FROM team_member WHERE team_id = #{teamId} AND user_id = #{userId}")
    TeamMember findByTeamAndUser(@Param("teamId") UUID teamId, @Param("userId") UUID userId);

    @Select("SELECT * FROM team_member WHERE team_id = #{teamId} ORDER BY joined_at")
    List<TeamMember> findByTeam(@Param("teamId") UUID teamId);

    @Delete("DELETE FROM team_member WHERE team_id = #{teamId} AND user_id = #{userId}")
    int deleteByTeamAndUser(@Param("teamId") UUID teamId, @Param("userId") UUID userId);

    @Delete("DELETE FROM team_member WHERE team_id = #{teamId}")
    int deleteByTeam(@Param("teamId") UUID teamId);
}
