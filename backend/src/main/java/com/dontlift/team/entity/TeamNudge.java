package com.dontlift.team.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Team 成员当日一次性拍一拍事件。服务端权威，不进入离线同步域。 */
@Data
@TableName("team_nudge")
public class TeamNudge {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID teamId;

    private UUID senderUserId;

    private UUID recipientUserId;

    private LocalDate nudgeDate;

    private OffsetDateTime createdAt;
}
