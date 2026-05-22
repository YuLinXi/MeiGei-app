package com.meigei.nutrition;

import com.meigei.nutrition.entity.CustomFood;
import com.meigei.security.SecurityUtils;
import com.meigei.sync.dto.SyncPullResult;
import com.meigei.sync.dto.SyncPushRequest;
import com.meigei.sync.dto.SyncPushResult;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 饮食域同步接口（custom_food）。pull?since=ISO8601 增量下拉；push 批量上传 + LWW。
 * 写接口配合 Idempotency-Key 头实现幂等（D4）。
 */
@RestController
@RequestMapping("/sync")
@RequiredArgsConstructor
public class NutritionSyncController {

    private final CustomFoodSyncService customFoodSync;

    @GetMapping("/custom-foods/pull")
    public SyncPullResult<CustomFood> pullCustomFoods(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime since) {
        UUID userId = SecurityUtils.currentUserId();
        return customFoodSync.pull(userId, since);
    }

    @PostMapping("/custom-foods/push")
    public SyncPushResult<CustomFood> pushCustomFoods(
            @RequestBody SyncPushRequest<CustomFood> req) {
        UUID userId = SecurityUtils.currentUserId();
        return customFoodSync.push(userId, req.items());
    }
}
