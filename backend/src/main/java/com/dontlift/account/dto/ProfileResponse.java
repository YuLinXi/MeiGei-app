package com.dontlift.account.dto;

import java.util.UUID;

/**
 * 用户画像（服务端权威域，非 LWW 同步）。
 * displayName 为空表示称呼未补全 —— 客户端据此决定是否拦首登补全页。
 */
public record ProfileResponse(
        UUID userId,
        String displayName,
        String sex,
        String email
) {
}
