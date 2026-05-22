package com.meigei.sync.dto;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 增量下拉结果：自客户端上次 since 起本人的全部变更（含软删墓碑，让其他设备删除本地）。
 * serverTime 作为客户端下次 since 的水位。
 */
public record SyncPullResult<T>(
        List<T> changes,
        OffsetDateTime serverTime
) {
}
