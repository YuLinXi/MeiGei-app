package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.Team;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

public interface TeamMapper extends BaseMapper<Team> {

    @Select("SELECT * FROM team WHERE invite_code = #{code} AND deleted_at IS NULL")
    Team findByInviteCode(@Param("code") String code);

    // 我加入的所有未解散 Team
    @Select("""
            SELECT t.* FROM team t
            JOIN team_member m ON m.team_id = t.id
            WHERE m.user_id = #{userId} AND t.deleted_at IS NULL
            ORDER BY t.created_at
            """)
    List<Team> findByMember(@Param("userId") UUID userId);
}
