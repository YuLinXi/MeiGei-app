package com.dontlift.team.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Team 分享计划的最小化反馈事件，不包含训练详情。 */
@Data
@TableName("team_plan_share_event")
public class TeamPlanShareEvent {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID teamId;

    private UUID shareId;

    private UUID versionId;

    private UUID userId;

    private String eventType;

    /** 软指针，仅用于客户端去重与排障，不对 Team 展示训练内容。 */
    private UUID workoutId;

    private LocalDate eventDate;

    private OffsetDateTime createdAt;
}
