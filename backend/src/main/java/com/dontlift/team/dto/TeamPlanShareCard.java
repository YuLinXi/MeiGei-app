package com.dontlift.team.dto;

import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Team 计划页卡片视图：最新分享版本 + 聚合反馈统计。 */
@Data
public class TeamPlanShareCard {
    private UUID shareId;
    private UUID versionId;
    private UUID teamId;
    private UUID ownerUserId;
    private String ownerName;
    private UUID sourcePlanId;
    private String title;
    private Integer versionNumber;
    private String planNameSnapshot;
    private String mode;
    private String items;
    private OffsetDateTime createdAt;
    private Integer copyCount;
    private Integer completionCount;
    /** 兼容旧客户端字段；语义等同 copyCount。 */
    private Integer adoptionCount;
    /** 兼容旧客户端字段；语义等同 completionCount。 */
    private Integer weeklyCompletionCount;
}
