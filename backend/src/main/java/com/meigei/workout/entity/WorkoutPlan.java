package com.meigei.workout.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.meigei.common.entity.BaseEntity;
import com.meigei.sync.UserOwned;
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

    private UUID forkedFrom;

    private UUID sharedToTeamId;
}
