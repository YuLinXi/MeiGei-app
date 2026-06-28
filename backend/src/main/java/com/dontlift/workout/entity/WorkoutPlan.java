package com.dontlift.workout.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.dontlift.common.entity.BaseEntity;
import com.dontlift.sync.UserOwned;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.UUID;

/**
 * 单次训练计划模板。items 为有序动作列表 jsonb，每项含稳定 itemId（D5）。
 * Fork = 复制 items + 记 forkedFrom 软指针；发布到 Team 设 sharedToTeamId。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("workout_plan")
public class WorkoutPlan extends BaseEntity implements UserOwned {

    private UUID userId;

    private String name;

    /** jsonb：[{itemId, exerciseRef, order, suggestedSets, suggestedReps, suggestedWeight}]。 */
    private String items;

    /** 计划模式："strict"（照剧本）/"adaptive"（活文档，实绩回写）。默认 adaptive。 */
    private String mode;

    private UUID forkedFrom;

    private UUID forkedFromShareVersionId;

    private UUID sharedToTeamId;

    /** 计划分组；null 表示未分组。为离线同步容错，不在数据库层加外键。 */
    private UUID groupId;

    /** 组内排序值，升序排列；同值时客户端按 updatedAt 兜底。 */
    private Integer sortOrder;
}
