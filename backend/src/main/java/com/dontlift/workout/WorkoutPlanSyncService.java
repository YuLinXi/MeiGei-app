package com.dontlift.workout;

import com.dontlift.sync.AbstractSyncService;
import com.dontlift.workout.entity.WorkoutPlan;
import com.dontlift.workout.mapper.WorkoutPlanMapper;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class WorkoutPlanSyncService extends AbstractSyncService<WorkoutPlan> {

    private final WorkoutPlanMapper planMapper;

    public WorkoutPlanSyncService(WorkoutPlanMapper mapper) {
        super(mapper, "workout-plans");
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
