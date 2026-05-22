package com.meigei.workout.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.meigei.common.entity.BaseEntity;
import com.meigei.sync.UserOwned;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.UUID;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("custom_exercise")
public class CustomExercise extends BaseEntity implements UserOwned {

    private UUID userId;

    private String name;

    private String primaryMuscle;

    private String equipmentType;
}
