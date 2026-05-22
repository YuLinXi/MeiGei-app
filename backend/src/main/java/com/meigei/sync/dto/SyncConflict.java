package com.meigei.sync.dto;

import java.util.UUID;

/** 服务端胜出的冲突项：回传服务端当前值，供客户端人工提示并覆盖本地（D3）。 */
public record SyncConflict<T>(
        UUID id,
        T serverValue
) {
}
