package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.dto.TeamPlanShareCard;
import com.dontlift.team.entity.TeamPlanShare;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface TeamPlanShareMapper extends BaseMapper<TeamPlanShare> {

    @Select("""
            SELECT * FROM team_plan_share
            WHERE team_id = #{teamId}
              AND owner_user_id = #{ownerUserId}
              AND source_plan_id = #{sourcePlanId}
              AND deleted_at IS NULL
            LIMIT 1
            """)
    TeamPlanShare findByTeamOwnerSource(@Param("teamId") UUID teamId,
                                        @Param("ownerUserId") UUID ownerUserId,
                                        @Param("sourcePlanId") UUID sourcePlanId);

    @Select("""
            SELECT * FROM team_plan_share
            WHERE team_id = #{teamId}
              AND owner_user_id = #{ownerUserId}
              AND source_plan_id = #{sourcePlanId}
              AND deleted_at IS NULL
            LIMIT 1
            FOR UPDATE
            """)
    TeamPlanShare findByTeamOwnerSourceForUpdate(@Param("teamId") UUID teamId,
                                                 @Param("ownerUserId") UUID ownerUserId,
                                                 @Param("sourcePlanId") UUID sourcePlanId);

    @Select("""
            SELECT
                s.id AS share_id,
                v.id AS version_id,
                s.team_id,
                s.owner_user_id,
                u.display_name AS owner_name,
                s.source_plan_id,
                s.title,
                v.version_number,
                v.plan_name_snapshot,
                v.mode,
                v.items::text AS items,
                v.created_at,
                COALESCE(f.copy_count, 0) AS copy_count,
                COALESCE(f.copy_count, 0) AS adoption_count,
                COALESCE(c.completion_count, 0) AS completion_count,
                COALESCE(c.completion_count, 0) AS weekly_completion_count
            FROM team_plan_share s
            JOIN team_plan_share_version v ON v.id = s.latest_version_id
            JOIN app_user u ON u.id = s.owner_user_id
            LEFT JOIN (
                SELECT share_id, count(DISTINCT user_id)::int AS copy_count
                FROM team_plan_share_event
                WHERE event_type = 'fork'
                GROUP BY share_id
            ) f ON f.share_id = s.id
            LEFT JOIN (
                SELECT share_id, count(*)::int AS completion_count
                FROM team_plan_share_event
                WHERE event_type = 'complete'
                GROUP BY share_id
            ) c ON c.share_id = s.id
            WHERE s.team_id = #{teamId}
              AND s.deleted_at IS NULL
            ORDER BY s.updated_at DESC, v.created_at DESC
            """)
    List<TeamPlanShareCard> findCardsByTeam(@Param("teamId") UUID teamId);

    @Update("""
            UPDATE team_plan_share
            SET title = #{title},
                latest_version_id = #{versionId},
                updated_at = #{updatedAt},
                version = COALESCE(version, 0) + 1
            WHERE id = #{shareId}
              AND deleted_at IS NULL
            """)
    int updateLatestVersion(@Param("shareId") UUID shareId,
                            @Param("title") String title,
                            @Param("versionId") UUID versionId,
                            @Param("updatedAt") OffsetDateTime updatedAt);

    @Update("""
            UPDATE team_plan_share
            SET deleted_at = #{deletedAt},
                updated_at = #{deletedAt},
                version = COALESCE(version, 0) + 1
            WHERE id = #{shareId}
              AND owner_user_id = #{ownerUserId}
              AND deleted_at IS NULL
            """)
    int softDelete(@Param("shareId") UUID shareId,
                   @Param("ownerUserId") UUID ownerUserId,
                   @Param("deletedAt") OffsetDateTime deletedAt);

    @Delete("DELETE FROM team_plan_share WHERE owner_user_id = #{userId}")
    int deleteByUser(@Param("userId") UUID userId);

    @Delete("DELETE FROM team_plan_share WHERE team_id = #{teamId}")
    int deleteByTeam(@Param("teamId") UUID teamId);
}
