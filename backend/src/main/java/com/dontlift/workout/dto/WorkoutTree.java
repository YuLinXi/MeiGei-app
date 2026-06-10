package com.dontlift.workout.dto;

import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.entity.WorkoutExercise;
import com.dontlift.workout.entity.WorkoutSet;

import java.util.List;

/**
 * 训练记录聚合：聚合根 workout + 其动作/组子树，作为同步的整体单元。
 * 上传时服务端按 workoutId 全量替换子树；下拉时墓碑项 exercises 为空。
 */
public record WorkoutTree(
        Workout workout,
        List<ExerciseNode> exercises
) {
    public record ExerciseNode(
            WorkoutExercise exercise,
            List<WorkoutSet> sets
    ) {
    }
}
