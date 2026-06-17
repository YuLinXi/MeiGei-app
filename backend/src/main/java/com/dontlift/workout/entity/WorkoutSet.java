package com.dontlift.workout.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.util.UUID;

/** 某动作的某一组（孙）。PR/曲线由这些原始组重算，不存冗余统计。 */
@Data
@TableName("workout_set")
public class WorkoutSet {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID workoutExerciseId;

    private Integer setIndex;

    private BigDecimal weightKg;

    private Integer reps;

    private Boolean completed;

    private String note;

    /** 组类型（"working"/"warmup"）。WorkoutTree 内嵌实体，随 Jackson 自动序列化；DB 列默认 'working'。 */
    private String setType;
}
