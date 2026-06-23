package com.dontlift.workout;

import com.dontlift.sync.dto.SyncPullResult;
import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.workout.entity.WorkoutPlanGroup;
import com.dontlift.workout.mapper.WorkoutPlanGroupMapper;
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
class WorkoutPlanGroupSyncServiceTest {

    @Mock WorkoutPlanGroupMapper mapper;

    @Test
    void pull_returnsChangesFromMapper() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime since = OffsetDateTime.parse("2026-06-01T10:00:00Z");
        WorkoutPlanGroup group = group("胸背", 0, since.plusHours(1));
        when(mapper.findChangesSince(userId, since)).thenReturn(List.of(group));

        SyncPullResult<WorkoutPlanGroup> result = service.pull(userId, since);

        assertThat(result.changes()).containsExactly(group);
        assertThat(result.serverTime()).isNotNull();
        verify(mapper).findChangesSince(userId, since);
    }

    @Test
    void push_insertsNewGroupAndForcesOwner() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        WorkoutPlanGroup incoming = group("腿", 1, OffsetDateTime.parse("2026-06-02T10:00:00Z"));
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(null);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(incoming.getUserId()).isEqualTo(userId);
        verify(mapper).insert(incoming);
    }

    @Test
    void push_updatesExistingGroupWhenIncomingWins() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        WorkoutPlanGroup server = group("旧名称", 0, OffsetDateTime.parse("2026-06-02T09:00:00Z"));
        server.setVersion(3);
        WorkoutPlanGroup incoming = group("新名称", 2, OffsetDateTime.parse("2026-06-02T10:00:00Z"));
        incoming.setId(server.getId());
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(server);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(incoming.getUserId()).isEqualTo(userId);
        assertThat(incoming.getVersion()).isEqualTo(3);
        verify(mapper).updateById(incoming);
    }

    @Test
    void push_softDeletesWithExplicitTombstoneUpdate() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime updatedAt = OffsetDateTime.parse("2026-06-03T10:00:00Z");
        OffsetDateTime deletedAt = OffsetDateTime.parse("2026-06-03T10:05:00Z");
        WorkoutPlanGroup server = group("胸背", 0, updatedAt.minusHours(1));
        server.setVersion(7);
        WorkoutPlanGroup incoming = group("胸背", 0, updatedAt);
        incoming.setId(server.getId());
        incoming.setDeletedAt(deletedAt);
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(server);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        verify(mapper).softDelete(incoming.getId(), deletedAt, updatedAt, 8);
        verify(mapper, never()).updateById(any(WorkoutPlanGroup.class));
    }

    private WorkoutPlanGroup group(String name, int sortOrder, OffsetDateTime updatedAt) {
        WorkoutPlanGroup group = new WorkoutPlanGroup();
        group.setId(UUID.randomUUID());
        group.setName(name);
        group.setSortOrder(sortOrder);
        group.setCreatedAt(updatedAt.minusDays(1));
        group.setUpdatedAt(updatedAt);
        group.setVersion(0);
        return group;
    }
}
