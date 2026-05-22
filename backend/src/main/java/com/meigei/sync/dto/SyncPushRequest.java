package com.meigei.sync.dto;

import java.util.List;

/** 批量上传请求体。 */
public record SyncPushRequest<T>(
        List<T> items
) {
}
