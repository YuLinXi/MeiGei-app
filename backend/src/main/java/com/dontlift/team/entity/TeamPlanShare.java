package com.dontlift.team.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.dontlift.common.entity.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.UUID;

/** Team 计划分享线索。最新版本用于列表展示，版本本身不可变。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("team_plan_share")
public class TeamPlanShare extends BaseEntity {

    private UUID teamId;

    private UUID ownerUserId;

    /** 原个人计划软指针；原计划删除不影响已分享版本。 */
    private UUID sourcePlanId;

    private String title;

    private UUID latestVersionId;
}
