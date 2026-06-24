package com.dontlift.sync.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

/** 同步 push 中服务端对客户端偏移时间戳做出的校正通知。 */
public record SyncTimestampAdjustment(
        UUID id,
        String domain,
        OffsetDateTime originalUpdatedAt,
        OffsetDateTime adjustedAt,
        String reason
) {
}
