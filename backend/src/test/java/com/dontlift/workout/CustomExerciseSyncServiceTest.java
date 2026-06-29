package com.dontlift.workout;

import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.workout.entity.CustomExercise;
import com.dontlift.workout.mapper.CustomExerciseMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomExerciseSyncServiceTest {

    @Mock CustomExerciseMapper mapper;

    @Test
    void push_softDeletesWithExplicitTombstoneUpdate() {
        CustomExerciseSyncService service = new CustomExerciseSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime updatedAt = OffsetDateTime.now().minusMinutes(10);
        OffsetDateTime deletedAt = updatedAt.plusMinutes(5);
        CustomExercise server = exercise("旧动作", updatedAt.minusHours(1));
        server.setVersion(7);
        CustomExercise incoming = exercise("旧动作", updatedAt);
        incoming.setId(server.getId());
        incoming.setDeletedAt(deletedAt);
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(server);

        SyncPushResult<CustomExercise> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(result.timestampAdjustments()).isEmpty();
        assertThat(incoming.getUserId()).isEqualTo(userId);
        verify(mapper).softDelete(incoming.getId(), deletedAt, updatedAt, 8);
        verify(mapper, never()).updateById(any(CustomExercise.class));
    }

    private CustomExercise exercise(String name, OffsetDateTime updatedAt) {
        CustomExercise exercise = new CustomExercise();
        exercise.setId(UUID.randomUUID());
        exercise.setName(name);
        exercise.setPrimaryMuscle("胸");
        exercise.setEquipmentType("哑铃");
        exercise.setCreatedAt(updatedAt.minusDays(1));
        exercise.setUpdatedAt(updatedAt);
        exercise.setVersion(0);
        return exercise;
    }
}
