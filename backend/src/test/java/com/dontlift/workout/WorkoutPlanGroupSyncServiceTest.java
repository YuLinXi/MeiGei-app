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
        WorkoutPlanGroup incoming = group("腿", 1, OffsetDateTime.now().minusMinutes(10));
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(null);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(result.timestampAdjustments()).isEmpty();
        assertThat(incoming.getUserId()).isEqualTo(userId);
        verify(mapper).insert(incoming);
    }

    @Test
    void push_updatesExistingGroupWhenIncomingWins() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime updatedAt = OffsetDateTime.now().minusMinutes(10);
        WorkoutPlanGroup server = group("旧名称", 0, updatedAt.minusMinutes(5));
        server.setVersion(3);
        WorkoutPlanGroup incoming = group("新名称", 2, updatedAt);
        incoming.setId(server.getId());
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(server);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(result.timestampAdjustments()).isEmpty();
        assertThat(incoming.getUserId()).isEqualTo(userId);
        assertThat(incoming.getVersion()).isEqualTo(3);
        verify(mapper).updateById(incoming);
    }

    @Test
    void push_clampsFutureUpdatedAtAndReturnsAdjustmentNotice() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime future = OffsetDateTime.now().plusDays(2);
        WorkoutPlanGroup incoming = group("未来设备", 0, future);
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(null);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(result.timestampAdjustments()).hasSize(1);
        assertThat(result.timestampAdjustments().getFirst().id()).isEqualTo(incoming.getId());
        assertThat(result.timestampAdjustments().getFirst().domain()).isEqualTo("workout-plan-groups");
        assertThat(result.timestampAdjustments().getFirst().originalUpdatedAt()).isEqualTo(future);
        assertThat(result.timestampAdjustments().getFirst().adjustedAt()).isEqualTo(result.serverTime());
        assertThat(result.timestampAdjustments().getFirst().reason()).isEqualTo("client_clock_ahead");
        assertThat(incoming.getUpdatedAt()).isEqualTo(result.serverTime());
        verify(mapper).insert(incoming);
    }

    @Test
    void push_slowClockDoesNotOverwriteNewerServerValue() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime serverUpdatedAt = OffsetDateTime.now().minusHours(1);
        WorkoutPlanGroup server = group("服务端较新", 0, serverUpdatedAt);
        server.setVersion(4);
        WorkoutPlanGroup incoming = group("慢时钟", 0, serverUpdatedAt.minusDays(2));
        incoming.setId(server.getId());
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(server);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).isEmpty();
        assertThat(result.conflicts()).hasSize(1);
        assertThat(result.conflicts().getFirst().id()).isEqualTo(server.getId());
        assertThat(result.timestampAdjustments()).hasSize(1);
        assertThat(result.timestampAdjustments().getFirst().reason()).isEqualTo("client_clock_behind");
        verify(mapper, never()).updateById(any(WorkoutPlanGroup.class));
    }

    @Test
    void push_softDeletesWithExplicitTombstoneUpdate() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime updatedAt = OffsetDateTime.now().minusMinutes(10);
        OffsetDateTime deletedAt = updatedAt.plusMinutes(5);
        WorkoutPlanGroup server = group("胸背", 0, updatedAt.minusHours(1));
        server.setVersion(7);
        WorkoutPlanGroup incoming = group("胸背", 0, updatedAt);
        incoming.setId(server.getId());
        incoming.setDeletedAt(deletedAt);
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(server);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(result.timestampAdjustments()).isEmpty();
        verify(mapper).softDelete(incoming.getId(), deletedAt, updatedAt, 8);
        verify(mapper, never()).updateById(any(WorkoutPlanGroup.class));
    }

    @Test
    void push_clampsFutureTombstoneWithoutDroppingSoftDelete() {
        WorkoutPlanGroupSyncService service = new WorkoutPlanGroupSyncService(mapper);
        UUID userId = UUID.randomUUID();
        OffsetDateTime now = OffsetDateTime.now();
        OffsetDateTime future = now.plusDays(1);
        WorkoutPlanGroup server = group("胸背", 0, now.minusHours(1));
        server.setVersion(7);
        WorkoutPlanGroup incoming = group("胸背", 0, future);
        incoming.setId(server.getId());
        incoming.setDeletedAt(future.plusMinutes(5));
        when(mapper.findByIdIncludingDeleted(incoming.getId())).thenReturn(server);

        SyncPushResult<WorkoutPlanGroup> result = service.push(userId, List.of(incoming));

        assertThat(result.applied()).containsExactly(incoming.getId());
        assertThat(result.conflicts()).isEmpty();
        assertThat(result.timestampAdjustments()).hasSize(1);
        assertThat(incoming.getUpdatedAt()).isEqualTo(result.serverTime());
        assertThat(incoming.getDeletedAt()).isEqualTo(result.serverTime());
        verify(mapper).softDelete(incoming.getId(), incoming.getDeletedAt(), incoming.getUpdatedAt(), 8);
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
