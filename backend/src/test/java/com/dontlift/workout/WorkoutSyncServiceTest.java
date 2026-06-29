package com.dontlift.workout;

import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.team.CheckinService;
import com.dontlift.workout.dto.WorkoutTree;
import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.entity.WorkoutExercise;
import com.dontlift.workout.entity.WorkoutSet;
import com.dontlift.workout.mapper.WorkoutExerciseMapper;
import com.dontlift.workout.mapper.WorkoutMapper;
import com.dontlift.workout.mapper.WorkoutSetMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkoutSyncServiceTest {

    @Mock WorkoutMapper workoutMapper;
    @Mock WorkoutExerciseMapper exerciseMapper;
    @Mock WorkoutSetMapper setMapper;
    @Mock CheckinService checkinService;

    @Test
    void push_clampsFutureWorkoutUpdatedAtAndReturnsAdjustmentNotice() {
        WorkoutSyncService service = new WorkoutSyncService(workoutMapper, exerciseMapper, setMapper, checkinService);
        UUID userId = UUID.randomUUID();
        OffsetDateTime future = OffsetDateTime.now().plusDays(2);
        Workout workout = workout(future);
        when(workoutMapper.findByIdIncludingDeleted(workout.getId())).thenReturn(null);

        SyncPushResult<WorkoutTree> result = service.push(userId, List.of(new WorkoutTree(workout, List.of())));

        assertThat(result.applied()).containsExactly(workout.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(result.timestampAdjustments()).hasSize(1);
        assertThat(result.timestampAdjustments().getFirst().id()).isEqualTo(workout.getId());
        assertThat(result.timestampAdjustments().getFirst().domain()).isEqualTo("workouts");
        assertThat(result.timestampAdjustments().getFirst().originalUpdatedAt()).isEqualTo(future);
        assertThat(result.timestampAdjustments().getFirst().adjustedAt()).isEqualTo(result.serverTime());
        assertThat(workout.getUpdatedAt()).isEqualTo(result.serverTime());
        assertThat(workout.getUserId()).isEqualTo(userId);
        verify(workoutMapper).insert(workout);
    }

    @Test
    void push_preservesWorkoutSetRestSecondsWhenReplacingChildren() {
        WorkoutSyncService service = new WorkoutSyncService(workoutMapper, exerciseMapper, setMapper, checkinService);
        UUID userId = UUID.randomUUID();
        OffsetDateTime now = OffsetDateTime.now();
        Workout workout = workout(now);
        WorkoutExercise exercise = new WorkoutExercise();
        exercise.setId(UUID.randomUUID());
        exercise.setExerciseName("杠铃卧推");
        exercise.setOrderIndex(0);
        WorkoutSet set = new WorkoutSet();
        set.setId(UUID.randomUUID());
        set.setSetIndex(0);
        set.setWeightKg(BigDecimal.valueOf(80));
        set.setReps(5);
        set.setCompleted(true);
        set.setSetType("working");
        set.setPlannedRestSeconds(120);
        set.setActualRestSeconds(137);
        when(workoutMapper.findByIdIncludingDeleted(workout.getId())).thenReturn(null);

        service.push(userId, List.of(new WorkoutTree(
                workout,
                List.of(new WorkoutTree.ExerciseNode(exercise, List.of(set)))
        )));

        ArgumentCaptor<WorkoutSet> captor = ArgumentCaptor.forClass(WorkoutSet.class);
        verify(setMapper).insert(captor.capture());
        WorkoutSet inserted = captor.getValue();
        assertThat(inserted.getWorkoutExerciseId()).isEqualTo(exercise.getId());
        assertThat(inserted.getPlannedRestSeconds()).isEqualTo(120);
        assertThat(inserted.getActualRestSeconds()).isEqualTo(137);
    }

    private Workout workout(OffsetDateTime updatedAt) {
        Workout workout = new Workout();
        workout.setId(UUID.randomUUID());
        workout.setTitle("胸背");
        workout.setStartedAt(updatedAt.minusHours(1));
        workout.setEndedAt(updatedAt);
        workout.setCreatedAt(updatedAt.minusDays(1));
        workout.setUpdatedAt(updatedAt);
        workout.setVersion(0);
        return workout;
    }
}
