package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.TeamPlanShareVersion;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.UUID;

public interface TeamPlanShareVersionMapper extends BaseMapper<TeamPlanShareVersion> {

    @Select("""
            SELECT COALESCE(MAX(version_number), 0) + 1
            FROM team_plan_share_version
            WHERE share_id = #{shareId}
            """)
    int nextVersionNumber(@Param("shareId") UUID shareId);

    @Select("""
            SELECT * FROM team_plan_share_version
            WHERE share_id = #{shareId}
            ORDER BY version_number DESC
            LIMIT 1
            """)
    TeamPlanShareVersion findLatestByShare(@Param("shareId") UUID shareId);
}
