package com.dontlift.sync.dto;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** 批量上传结果：applied = 已落库 id；conflicts = 服务端较新而被拒的项。 */
public record SyncPushResult<T>(
        List<UUID> applied,
        List<SyncConflict<T>> conflicts,
        OffsetDateTime serverTime,
        List<SyncTimestampAdjustment> timestampAdjustments
) {
    public SyncPushResult(List<UUID> applied, List<SyncConflict<T>> conflicts, OffsetDateTime serverTime) {
        this(applied, conflicts, serverTime, List.of());
    }
}
