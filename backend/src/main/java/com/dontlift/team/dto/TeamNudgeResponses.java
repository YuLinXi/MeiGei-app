package com.dontlift.team.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Team 拍一拍的最小响应集合，仅暴露可展示接收者，不返回他人的具体偏好或接收配额。 */
public final class TeamNudgeResponses {

    private TeamNudgeResponses() {
    }

    public record TodayState(
            LocalDate date,
            List<UUID> nudgedRecipientUserIds,
            List<UUID> receivableRecipientUserIds,
            boolean receiveTeamNotifications
    ) {
        /** 兼容尚未升级的客户端；不是独立偏好。 */
        @JsonProperty("receiveWorkoutNudges")
        public boolean legacyReceiveWorkoutNudges() {
            return receiveTeamNotifications;
        }
    }

    public record SendResult(
            UUID recipientUserId,
            LocalDate date,
            OffsetDateTime createdAt
    ) {
    }
}
