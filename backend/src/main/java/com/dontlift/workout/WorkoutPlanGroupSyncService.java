package com.dontlift.workout;

import com.dontlift.sync.AbstractSyncService;
import com.dontlift.workout.entity.WorkoutPlanGroup;
import com.dontlift.workout.mapper.WorkoutPlanGroupMapper;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class WorkoutPlanGroupSyncService extends AbstractSyncService<WorkoutPlanGroup> {

    private final WorkoutPlanGroupMapper groupMapper;

    public WorkoutPlanGroupSyncService(WorkoutPlanGroupMapper mapper) {
        super(mapper, "workout-plan-groups");
        this.groupMapper = mapper;
    }

    @Override
    protected List<WorkoutPlanGroup> findChangesSince(UUID userId, OffsetDateTime since) {
        return groupMapper.findChangesSince(userId, since);
    }

    @Override
    protected WorkoutPlanGroup findByIdIncludingDeleted(UUID id) {
        return groupMapper.findByIdIncludingDeleted(id);
    }

    @Override
    protected void softDelete(WorkoutPlanGroup item, int serverVersion) {
        groupMapper.softDelete(item.getId(), item.getDeletedAt(), item.getUpdatedAt(), serverVersion + 1);
    }
}
