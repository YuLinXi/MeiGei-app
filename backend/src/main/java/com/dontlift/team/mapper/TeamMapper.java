package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.Team;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;
import java.util.UUID;

public interface TeamMapper extends BaseMapper<Team> {

    @Select("SELECT * FROM team WHERE invite_code = #{code} AND deleted_at IS NULL")
    Team findByInviteCode(@Param("code") String code);

    // 账号删除：物理硬删该 user 作为 owner 的全部团队（含已软删的，彻底清残留）
    @Delete("DELETE FROM team WHERE owner_user_id = #{userId}")
    int deleteOwnedTeams(@Param("userId") UUID userId);

    /** 账号删除：物理硬删已确认无其他成员的空 Team。 */
    @Delete("DELETE FROM team WHERE id = #{teamId}")
    int hardDeleteById(@Param("teamId") UUID teamId);

    @Update("""
            UPDATE team
            SET owner_user_id = #{newOwnerId},
                owner_transferred_at = now(),
                owner_transferred_from_user_id = #{oldOwnerId},
                updated_at = now(),
                version = version + 1
            WHERE id = #{teamId}
            """)
    int transferOwner(@Param("teamId") UUID teamId,
                      @Param("oldOwnerId") UUID oldOwnerId,
                      @Param("newOwnerId") UUID newOwnerId);

    @Select("SELECT * FROM team WHERE owner_user_id = #{userId} AND deleted_at IS NULL ORDER BY created_at")
    List<Team> findActiveOwnedTeams(@Param("userId") UUID userId);

    // 删号影响面：作为 owner 且未解散的团队数
    @Select("SELECT count(*) FROM team WHERE owner_user_id = #{userId} AND deleted_at IS NULL")
    int countOwnedActiveTeams(@Param("userId") UUID userId);

    @Select("""
            SELECT count(*) FROM team t
            WHERE t.owner_user_id = #{userId}
              AND t.deleted_at IS NULL
              AND EXISTS (
                  SELECT 1 FROM team_member m
                  WHERE m.team_id = t.id AND m.user_id <> #{userId})
            """)
    int countOwnedTeamsToTransfer(@Param("userId") UUID userId);

    @Select("""
            SELECT count(*) FROM team t
            WHERE t.owner_user_id = #{userId}
              AND t.deleted_at IS NULL
              AND NOT EXISTS (
                  SELECT 1 FROM team_member m
                  WHERE m.team_id = t.id AND m.user_id <> #{userId})
            """)
    int countEmptyOwnedTeamsToDelete(@Param("userId") UUID userId);

    // 删号影响面：这些团队中除本人外的去重成员数
    @Select("""
            SELECT count(DISTINCT m.user_id) FROM team_member m
            WHERE m.team_id IN (SELECT id FROM team WHERE owner_user_id = #{userId} AND deleted_at IS NULL)
              AND m.user_id <> #{userId}
            """)
    int countAffectedMembers(@Param("userId") UUID userId);

    // 我加入的所有未解散 Team
    @Select("""
            SELECT t.* FROM team t
            JOIN team_member m ON m.team_id = t.id
            WHERE m.user_id = #{userId} AND t.deleted_at IS NULL
            ORDER BY t.created_at
            """)
    List<Team> findByMember(@Param("userId") UUID userId);
}
