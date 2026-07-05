package com.dontlift.workout;

import com.dontlift.sync.dto.SyncConflict;
import com.dontlift.sync.dto.SyncPullResult;
import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.sync.SyncTimestampGuard;
import com.dontlift.sync.dto.SyncTimestampAdjustment;
import com.dontlift.team.CheckinService;
import com.dontlift.workout.dto.WorkoutTree;
import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.entity.WorkoutExercise;
import com.dontlift.workout.entity.WorkoutSet;
import com.dontlift.workout.mapper.WorkoutExerciseMapper;
import com.dontlift.workout.mapper.WorkoutMapper;
import com.dontlift.workout.mapper.WorkoutSetMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 训练记录聚合根同步：LWW 作用于聚合根 workout 的 updatedAt；
 * 子树（动作/组）无独立信封，随聚合整体上传，服务端按 workoutId 全量替换。
 * 不复用 AbstractSyncService，因同步单元是嵌套树而非单实体。
 */
@Service
public class WorkoutSyncService {

    private final WorkoutMapper workoutMapper;
    private final WorkoutExerciseMapper exerciseMapper;
    private final WorkoutSetMapper setMapper;
    private final CheckinService checkinService;

    public WorkoutSyncService(WorkoutMapper workoutMapper,
                              WorkoutExerciseMapper exerciseMapper,
                              WorkoutSetMapper setMapper,
                              CheckinService checkinService) {
        this.workoutMapper = workoutMapper;
        this.exerciseMapper = exerciseMapper;
        this.setMapper = setMapper;
        this.checkinService = checkinService;
    }

    /** 增量下拉：含软删墓碑（墓碑项 exercises 为空，让其他设备删除本地）。 */
    public SyncPullResult<WorkoutTree> pull(UUID userId, OffsetDateTime since) {
        List<Workout> changes = workoutMapper.findChangesSince(userId, since);
        Map<UUID, WorkoutTree> loaded = loadTrees(changes.stream()
                .filter(w -> w.getDeletedAt() == null)
                .toList());
        List<WorkoutTree> trees = new ArrayList<>(changes.size());
        for (Workout w : changes) {
            trees.add(w.getDeletedAt() != null
                    ? new WorkoutTree(w, List.of())
                    : loaded.getOrDefault(w.getId(), new WorkoutTree(w, List.of())));
        }
        return new SyncPullResult<>(trees, OffsetDateTime.now());
    }

    /** 批量上传 + LWW + 子树全量替换。 */
    @Transactional
    public SyncPushResult<WorkoutTree> push(UUID userId, List<WorkoutTree> incoming) {
        OffsetDateTime serverTime = OffsetDateTime.now();
        List<UUID> applied = new ArrayList<>();
        List<SyncConflict<WorkoutTree>> conflicts = new ArrayList<>();
        List<SyncTimestampAdjustment> timestampAdjustments = new ArrayList<>();

        for (WorkoutTree item : incoming) {
            Workout workout = item.workout();
            workout.setUserId(userId); // 强制归属，忽略客户端伪造
            SyncTimestampGuard.Decision timestamp = SyncTimestampGuard.normalize(
                    workout.getId(), "workouts", workout.getUpdatedAt(), serverTime);
            if (timestamp.adjusted()) {
                workout.setUpdatedAt(timestamp.effectiveUpdatedAt());
                workout.setDeletedAt(SyncTimestampGuard.normalizeDeletedAt(workout.getDeletedAt(), timestamp.effectiveUpdatedAt()));
                timestampAdjustments.add(timestamp.adjustment());
            }
            Workout server = workoutMapper.findByIdIncludingDeleted(workout.getId());

            if (server == null) {
                workoutMapper.insert(workout);
                replaceChildren(userId, workout.getId(), item.exercises());
                applied.add(workout.getId());
                continue;
            }

            boolean incomingWins = !server.getUpdatedAt().isAfter(timestamp.lwwUpdatedAt());
            if (!incomingWins) {
                conflicts.add(new SyncConflict<>(workout.getId(), loadTree(server)));
                continue;
            }

            if (workout.getDeletedAt() != null) {
                // 墓碑：写软删字段（updateById 写不动 @TableLogic）并清掉子树
                workoutMapper.softDelete(workout.getId(), workout.getDeletedAt(),
                        workout.getUpdatedAt(), server.getVersion() + 1);
                exerciseMapper.deleteByWorkout(workout.getId());
                // 连带移除该训练在所有 Team 的打卡（保持「删除后不再计入」与 Team 视图一致）
                checkinService.removeForWorkout(userId, workout.getId());
            } else {
                workout.setVersion(server.getVersion()); // 通过乐观锁校验
                workoutMapper.updateById(workout);
                replaceChildren(userId, workout.getId(), item.exercises());
            }
            applied.add(workout.getId());
        }

        return new SyncPushResult<>(applied, conflicts, serverTime, timestampAdjustments);
    }

    private WorkoutTree loadTree(Workout w) {
        List<WorkoutExercise> exercises = exerciseMapper.findByWorkout(w.getId());
        List<WorkoutTree.ExerciseNode> nodes = new ArrayList<>(exercises.size());
        for (WorkoutExercise e : exercises) {
            nodes.add(new WorkoutTree.ExerciseNode(e, setMapper.findByExercise(e.getId())));
        }
        return new WorkoutTree(w, nodes);
    }

    private Map<UUID, WorkoutTree> loadTrees(List<Workout> workouts) {
        if (workouts.isEmpty()) {
            return Map.of();
        }
        List<UUID> workoutIds = workouts.stream().map(Workout::getId).toList();
        List<WorkoutExercise> exercises = exerciseMapper.findByWorkouts(workoutIds);
        Map<UUID, List<WorkoutExercise>> exercisesByWorkout = exercises.stream()
                .collect(Collectors.groupingBy(WorkoutExercise::getWorkoutId));
        List<UUID> exerciseIds = exercises.stream().map(WorkoutExercise::getId).toList();
        Map<UUID, List<WorkoutSet>> setsByExercise = exerciseIds.isEmpty()
                ? Map.of()
                : setMapper.findByExercises(exerciseIds).stream()
                .collect(Collectors.groupingBy(WorkoutSet::getWorkoutExerciseId));
        return workouts.stream().collect(Collectors.toMap(
                Workout::getId,
                workout -> {
                    List<WorkoutExercise> workoutExercises = exercisesByWorkout.getOrDefault(workout.getId(), List.of());
                    List<WorkoutTree.ExerciseNode> nodes = new ArrayList<>(workoutExercises.size());
                    for (WorkoutExercise exercise : workoutExercises) {
                        nodes.add(new WorkoutTree.ExerciseNode(
                                exercise,
                                setsByExercise.getOrDefault(exercise.getId(), List.of())));
                    }
                    return new WorkoutTree(workout, nodes);
                }));
    }

    /** 删旧子树（动作删除级联删组）后按上传内容重建。 */
    private void replaceChildren(UUID userId, UUID workoutId, List<WorkoutTree.ExerciseNode> nodes) {
        exerciseMapper.deleteByWorkout(workoutId);
        if (nodes == null) {
            return;
        }
        for (WorkoutTree.ExerciseNode node : nodes) {
            WorkoutExercise e = node.exercise();
            e.setWorkoutId(workoutId);
            e.setUserId(userId);
            exerciseMapper.insert(e);
            if (node.sets() == null) {
                continue;
            }
            for (WorkoutSet s : node.sets()) {
                s.setWorkoutExerciseId(e.getId());
                normalizeSetTypeAndWarmup(s);
                s.setSegments(normalizedSegments(s.getSegments()));
                setMapper.insert(s);
            }
        }
    }

    private void normalizeSetTypeAndWarmup(WorkoutSet set) {
        if ("warmup".equals(set.getSetType())) {
            set.setIsWarmup(true);
            set.setSetType("working");
        }
        if (set.getSetType() == null || set.getSetType().isBlank()) {
            set.setSetType("working");
        }
        if (set.getIsWarmup() == null) {
            set.setIsWarmup(false);
        }
    }

    private String normalizedSegments(String segments) {
        return segments == null || segments.isBlank() ? "[]" : segments;
    }
}
