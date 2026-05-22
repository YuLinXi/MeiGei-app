package com.meigei.workout;

import com.meigei.sync.AbstractSyncService;
import com.meigei.workout.entity.WorkoutPlan;
import com.meigei.workout.mapper.WorkoutPlanMapper;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class WorkoutPlanSyncService extends AbstractSyncService<WorkoutPlan> {

    private final WorkoutPlanMapper planMapper;

    public WorkoutPlanSyncService(WorkoutPlanMapper mapper) {
        super(mapper);
        this.planMapper = mapper;
    }

    @Override
    protected List<WorkoutPlan> findChangesSince(UUID userId, OffsetDateTime since) {
        return planMapper.findChangesSince(userId, since);
    }

    @Override
    protected WorkoutPlan findByIdIncludingDeleted(UUID id) {
        return planMapper.findByIdIncludingDeleted(id);
    }

    @Override
    protected void softDelete(WorkoutPlan item, int serverVersion) {
        planMapper.softDelete(item.getId(), item.getDeletedAt(), item.getUpdatedAt(), serverVersion + 1);
    }
}
