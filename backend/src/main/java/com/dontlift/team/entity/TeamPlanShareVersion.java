package com.dontlift.team.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Team 分享计划的不可变版本快照。items 为无重量 jsonb 字符串。 */
@Data
@TableName("team_plan_share_version")
public class TeamPlanShareVersion {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID shareId;

    private Integer versionNumber;

    private String planNameSnapshot;

    private String mode;

    private String items;

    private OffsetDateTime createdAt;
}
