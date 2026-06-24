package com.dontlift.sync;

import com.dontlift.sync.dto.SyncTimestampAdjustment;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.UUID;

/** 同步写入时间防护：避免明显偏移的设备时钟污染 LWW 基准。 */
public final class SyncTimestampGuard {

    private static final Duration FUTURE_TOLERANCE = Duration.ofMinutes(5);
    private static final Duration PAST_TOLERANCE = Duration.ofHours(24);

    private SyncTimestampGuard() {
    }

    public static Decision normalize(UUID id, String domain, OffsetDateTime clientUpdatedAt, OffsetDateTime serverNow) {
        if (clientUpdatedAt == null) {
            return adjusted(id, domain, null, serverNow, serverNow, "missing_updated_at");
        }

        if (clientUpdatedAt.isAfter(serverNow.plus(FUTURE_TOLERANCE))) {
            return adjusted(id, domain, clientUpdatedAt, serverNow, serverNow, "client_clock_ahead");
        }

        if (clientUpdatedAt.isBefore(serverNow.minus(PAST_TOLERANCE))) {
            return adjusted(id, domain, clientUpdatedAt, serverNow, clientUpdatedAt, "client_clock_behind");
        }

        return new Decision(clientUpdatedAt, clientUpdatedAt, null);
    }

    public static OffsetDateTime normalizeDeletedAt(OffsetDateTime deletedAt, OffsetDateTime effectiveUpdatedAt) {
        if (deletedAt != null && deletedAt.isAfter(effectiveUpdatedAt)) {
            return effectiveUpdatedAt;
        }
        return deletedAt;
    }

    private static Decision adjusted(UUID id,
                                     String domain,
                                     OffsetDateTime originalUpdatedAt,
                                     OffsetDateTime effectiveUpdatedAt,
                                     OffsetDateTime lwwUpdatedAt,
                                     String reason) {
        return new Decision(
                effectiveUpdatedAt,
                lwwUpdatedAt,
                new SyncTimestampAdjustment(id, domain, originalUpdatedAt, effectiveUpdatedAt, reason)
        );
    }

    public record Decision(
            OffsetDateTime effectiveUpdatedAt,
            OffsetDateTime lwwUpdatedAt,
            SyncTimestampAdjustment adjustment
    ) {
        public boolean adjusted() {
            return adjustment != null;
        }
    }
}
