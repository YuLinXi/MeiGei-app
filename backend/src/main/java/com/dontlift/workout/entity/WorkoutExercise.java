package com.dontlift.workout.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.util.UUID;

/**
 * 训练中的某个动作（子）。快照动作名/肌群，便于队友端与服务端展示而不依赖内置目录。
 * builtin_exercise_code 与 custom_exercise_id 二选一（DB CHECK 约束）。
 * 随聚合根整体上传，故不带同步信封。
 */
@Data
@TableName("workout_exercise")
public class WorkoutExercise {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID workoutId;

    private UUID userId;

    private String builtinExerciseCode;

    private UUID customExerciseId;

    private String exerciseName;

    private String primaryMuscle;

    private Integer orderIndex;

    private String note;
}
