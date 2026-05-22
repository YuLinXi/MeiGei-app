package com.meigei.nutrition;

import com.meigei.nutrition.entity.CustomFood;
import com.meigei.nutrition.mapper.CustomFoodMapper;
import com.meigei.sync.AbstractSyncService;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class CustomFoodSyncService extends AbstractSyncService<CustomFood> {

    private final CustomFoodMapper foodMapper;

    public CustomFoodSyncService(CustomFoodMapper mapper) {
        super(mapper);
        this.foodMapper = mapper;
    }

    @Override
    protected List<CustomFood> findChangesSince(UUID userId, OffsetDateTime since) {
        return foodMapper.findChangesSince(userId, since);
    }

    @Override
    protected CustomFood findByIdIncludingDeleted(UUID id) {
        return foodMapper.findByIdIncludingDeleted(id);
    }

    @Override
    protected void softDelete(CustomFood item, int serverVersion) {
        foodMapper.softDelete(item.getId(), item.getDeletedAt(), item.getUpdatedAt(), serverVersion + 1);
    }
}
