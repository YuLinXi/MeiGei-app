package com.dontlift.workout;

import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.team.CheckinService;
import com.dontlift.workout.dto.WorkoutTree;
import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.mapper.WorkoutExerciseMapper;
import com.dontlift.workout.mapper.WorkoutMapper;
import com.dontlift.workout.mapper.WorkoutSetMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

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
