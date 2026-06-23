package com.dontlift.workout.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.dontlift.common.entity.BaseEntity;
import com.dontlift.sync.UserOwned;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.UUID;

/**
 * 训练计划分组。独立同步实体，允许空分组、分组排序与重命名。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("workout_plan_group")
public class WorkoutPlanGroup extends BaseEntity implements UserOwned {

    private UUID userId;

    private String name;

    private Integer sortOrder;
}
