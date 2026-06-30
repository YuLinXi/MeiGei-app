package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.CheckinReaction;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface CheckinReactionMapper extends BaseMapper<CheckinReaction> {

    @Select("SELECT * FROM checkin_reaction WHERE checkin_id = #{checkinId} AND user_id = #{userId}")
    CheckinReaction findByCheckinAndUser(@Param("checkinId") UUID checkinId, @Param("userId") UUID userId);

    @Insert("""
            INSERT INTO checkin_reaction (id, checkin_id, user_id, emoji, created_at, updated_at)
            VALUES (#{reaction.id}, #{reaction.checkinId}, #{reaction.userId}, #{reaction.emoji},
                    #{reaction.createdAt}, #{reaction.updatedAt})
            ON CONFLICT (checkin_id, user_id) DO NOTHING
            """)
    int insertReactionIfAbsent(@Param("reaction") CheckinReaction reaction);

    @Insert("""
            INSERT INTO checkin_reaction_push_receipt (id, checkin_id, user_id, created_at)
            VALUES (#{id}, #{checkinId}, #{userId}, #{createdAt})
            ON CONFLICT (checkin_id, user_id) DO NOTHING
            """)
    int insertPushReceiptIfAbsent(@Param("id") UUID id,
                                  @Param("checkinId") UUID checkinId,
                                  @Param("userId") UUID userId,
                                  @Param("createdAt") OffsetDateTime createdAt);

    @Select("SELECT * FROM checkin_reaction WHERE checkin_id = #{checkinId} ORDER BY created_at")
    List<CheckinReaction> findByCheckin(@Param("checkinId") UUID checkinId);

    @Select("""
            <script>
            SELECT * FROM checkin_reaction
            WHERE checkin_id IN
            <foreach collection="checkinIds" item="id" open="(" separator="," close=")">
                #{id}
            </foreach>
            ORDER BY created_at
            </script>
            """)
    List<CheckinReaction> findByCheckins(@Param("checkinIds") List<UUID> checkinIds);

    @Delete("DELETE FROM checkin_reaction WHERE user_id = #{userId}")
    int deleteByUser(@Param("userId") UUID userId);

    // 账号删除：本人产生的所有表情 + 本人作为 owner 的团队下打卡收到的全部表情
    @Delete("""
            DELETE FROM checkin_reaction
            WHERE user_id = #{userId}
               OR checkin_id IN (
                   SELECT id FROM team_checkin
                   WHERE team_id IN (SELECT id FROM team WHERE owner_user_id = #{userId}))
            """)
    int deleteByUserOrOwnedTeams(@Param("userId") UUID userId);
}
