package com.dontlift.workout;

import com.dontlift.sync.dto.SyncPullResult;
import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.workout.entity.WorkoutPlan;
import com.dontlift.workout.mapper.WorkoutPlanMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 计划整体备注 note 字段的同步信封透传（含旧客户端无 note 的兼容）。 */
@ExtendWith(MockitoExtension.class)
class WorkoutPlanSyncServiceTest {

    @Mock WorkoutPlanMapper planMapper;

    @Test
    void push_preservesPlanNoteOnInsert() {
        WorkoutPlanSyncService service = new WorkoutPlanSyncService(planMapper);
        UUID userId = UUID.randomUUID();
        WorkoutPlan plan = plan("本周减载");
        when(planMapper.findByIdIncludingDeleted(plan.getId())).thenReturn(null);

        SyncPushResult<WorkoutPlan> result = service.push(userId, List.of(plan));

        assertThat(result.applied()).containsExactly(plan.getId());
        ArgumentCaptor<WorkoutPlan> captor = ArgumentCaptor.forClass(WorkoutPlan.class);
        verify(planMapper).insert(captor.capture());
        assertThat(captor.getValue().getNote()).isEqualTo("本周减载");
    }

    @Test
    void push_preservesPlanNoteOnUpdate() {
        WorkoutPlanSyncService service = new WorkoutPlanSyncService(planMapper);
        UUID userId = UUID.randomUUID();
        WorkoutPlan plan = plan("本周减载");
        WorkoutPlan server = plan(null);
        server.setUpdatedAt(plan.getUpdatedAt().minusMinutes(1));
        server.setVersion(3);
        when(planMapper.findByIdIncludingDeleted(plan.getId())).thenReturn(server);

        SyncPushResult<WorkoutPlan> result = service.push(userId, List.of(plan));

        assertThat(result.applied()).containsExactly(plan.getId());
        ArgumentCaptor<WorkoutPlan> captor = ArgumentCaptor.forClass(WorkoutPlan.class);
        verify(planMapper).updateById(captor.capture());
        assertThat(captor.getValue().getNote()).isEqualTo("本周减载");
    }

    @Test
    void push_acceptsLegacyPlanWithoutNote() {
        WorkoutPlanSyncService service = new WorkoutPlanSyncService(planMapper);
        UUID userId = UUID.randomUUID();
        WorkoutPlan plan = plan(null);
        when(planMapper.findByIdIncludingDeleted(plan.getId())).thenReturn(null);

        SyncPushResult<WorkoutPlan> result = service.push(userId, List.of(plan));

        assertThat(result.applied()).containsExactly(plan.getId());
        ArgumentCaptor<WorkoutPlan> captor = ArgumentCaptor.forClass(WorkoutPlan.class);
        verify(planMapper).insert(captor.capture());
        assertThat(captor.getValue().getNote()).isNull();
    }

    @Test
    void pull_returnsPlanNote() {
        WorkoutPlanSyncService service = new WorkoutPlanSyncService(planMapper);
        UUID userId = UUID.randomUUID();
        WorkoutPlan plan = plan("本周减载");
        when(planMapper.findChangesSince(userId, null)).thenReturn(List.of(plan));

        SyncPullResult<WorkoutPlan> result = service.pull(userId, null);

        assertThat(result.changes()).hasSize(1);
        assertThat(result.changes().getFirst().getNote()).isEqualTo("本周减载");
    }

    private WorkoutPlan plan(String note) {
        WorkoutPlan plan = new WorkoutPlan();
        plan.setId(UUID.randomUUID());
        plan.setName("胸背");
        plan.setNote(note);
        plan.setItems("[]");
        plan.setMode("adaptive");
        plan.setUpdatedAt(OffsetDateTime.now());
        return plan;
    }
}
