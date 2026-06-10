package com.dontlift.workout;

import com.dontlift.sync.AbstractSyncService;
import com.dontlift.workout.entity.CustomExercise;
import com.dontlift.workout.mapper.CustomExerciseMapper;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class CustomExerciseSyncService extends AbstractSyncService<CustomExercise> {

    private final CustomExerciseMapper customMapper;

    public CustomExerciseSyncService(CustomExerciseMapper mapper) {
        super(mapper);
        this.customMapper = mapper;
    }

    @Override
    protected List<CustomExercise> findChangesSince(UUID userId, OffsetDateTime since) {
        return customMapper.findChangesSince(userId, since);
    }

    @Override
    protected CustomExercise findByIdIncludingDeleted(UUID id) {
        return customMapper.findByIdIncludingDeleted(id);
    }

    @Override
    protected void softDelete(CustomExercise item, int serverVersion) {
        customMapper.softDelete(item.getId(), item.getDeletedAt(), item.getUpdatedAt(), serverVersion + 1);
    }
}
