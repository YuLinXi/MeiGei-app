package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.TeamNudge;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface TeamNudgeMapper extends BaseMapper<TeamNudge> {

    @Select("""
            SELECT * FROM team_nudge
            WHERE team_id = #{teamId}
              AND sender_user_id = #{senderUserId}
              AND recipient_user_id = #{recipientUserId}
              AND nudge_date = #{date}
            """)
    TeamNudge findDaily(@Param("teamId") UUID teamId,
                        @Param("senderUserId") UUID senderUserId,
                        @Param("recipientUserId") UUID recipientUserId,
                        @Param("date") LocalDate date);

    @Select("""
            SELECT recipient_user_id FROM team_nudge
            WHERE team_id = #{teamId}
              AND sender_user_id = #{senderUserId}
              AND nudge_date = #{date}
            ORDER BY created_at
            """)
    List<UUID> findRecipientIds(@Param("teamId") UUID teamId,
                                @Param("senderUserId") UUID senderUserId,
                                @Param("date") LocalDate date);

    @Select("""
            SELECT count(DISTINCT recipient_user_id) FROM team_nudge
            WHERE sender_user_id = #{senderUserId} AND nudge_date = #{date}
            """)
    int countDistinctRecipients(@Param("senderUserId") UUID senderUserId,
                                @Param("date") LocalDate date);

    @Select("""
            SELECT EXISTS (
                SELECT 1 FROM team_nudge
                WHERE sender_user_id = #{senderUserId}
                  AND recipient_user_id = #{recipientUserId}
                  AND nudge_date = #{date}
            )
            """)
    boolean hasRecipient(@Param("senderUserId") UUID senderUserId,
                         @Param("recipientUserId") UUID recipientUserId,
                         @Param("date") LocalDate date);

    @Select("""
            SELECT count(*) FROM team_nudge
            WHERE recipient_user_id = #{recipientUserId} AND nudge_date = #{date}
            """)
    int countForRecipient(@Param("recipientUserId") UUID recipientUserId,
                          @Param("date") LocalDate date);

    /** 在同一事务内串行化用户跨 Team 的发送/接收日配额检查。 */
    @Select("SELECT id FROM app_user WHERE id = #{userId} FOR UPDATE")
    UUID lockUser(@Param("userId") UUID userId);
}
