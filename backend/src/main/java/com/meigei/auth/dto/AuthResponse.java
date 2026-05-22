package com.meigei.auth.dto;

import java.util.UUID;

public record AuthResponse(
        String token,
        UUID userId,
        boolean newUser
) {
}
