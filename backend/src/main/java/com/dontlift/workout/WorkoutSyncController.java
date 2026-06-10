package com.dontlift.workout;

import com.dontlift.security.SecurityUtils;
import com.dontlift.sync.dto.SyncPullResult;
import com.dontlift.sync.dto.SyncPushRequest;
import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.workout.dto.WorkoutTree;
import com.dontlift.workout.entity.CustomExercise;
import com.dontlift.workout.entity.WorkoutPlan;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 训练域同步接口（custom_exercise / workout_plan）。
 * pull?since=ISO8601 增量下拉；push 批量上传 + LWW。
 * 写接口配合 Idempotency-Key 头实现幂等（D4）。
 */
@RestController
@RequestMapping("/sync")
@RequiredArgsConstructor
public class WorkoutSyncController {

    private final CustomExerciseSyncService customExerciseSync;
    private final WorkoutPlanSyncService workoutPlanSync;
    private final WorkoutSyncService workoutSync;

    @GetMapping("/custom-exercises/pull")
    public SyncPullResult<CustomExercise> pullCustomExercises(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime since) {
        UUID userId = SecurityUtils.currentUserId();
        return customExerciseSync.pull(userId, since);
    }

    @PostMapping("/custom-exercises/push")
    public SyncPushResult<CustomExercise> pushCustomExercises(
            @RequestBody SyncPushRequest<CustomExercise> req) {
        UUID userId = SecurityUtils.currentUserId();
        return customExerciseSync.push(userId, req.items());
    }

    @GetMapping("/workout-plans/pull")
    public SyncPullResult<WorkoutPlan> pullWorkoutPlans(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime since) {
        UUID userId = SecurityUtils.currentUserId();
        return workoutPlanSync.pull(userId, since);
    }

    @PostMapping("/workout-plans/push")
    public SyncPushResult<WorkoutPlan> pushWorkoutPlans(
            @RequestBody SyncPushRequest<WorkoutPlan> req) {
        UUID userId = SecurityUtils.currentUserId();
        return workoutPlanSync.push(userId, req.items());
    }

    @GetMapping("/workouts/pull")
    public SyncPullResult<WorkoutTree> pullWorkouts(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime since) {
        UUID userId = SecurityUtils.currentUserId();
        return workoutSync.pull(userId, since);
    }

    @PostMapping("/workouts/push")
    public SyncPushResult<WorkoutTree> pushWorkouts(
            @RequestBody SyncPushRequest<WorkoutTree> req) {
        UUID userId = SecurityUtils.currentUserId();
        return workoutSync.push(userId, req.items());
    }
}
