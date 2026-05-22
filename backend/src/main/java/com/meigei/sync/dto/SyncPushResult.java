package com.meigei.sync.dto;

import java.time.OffsetDateTime;
import java.util.List;

/** 批量上传结果：applied = 已落库 id；conflicts = 服务端较新而被拒的项。 */
public record SyncPushResult<T>(
        List<java.util.UUID> applied,
        List<SyncConflict<T>> conflicts,
        OffsetDateTime serverTime
) {
}
