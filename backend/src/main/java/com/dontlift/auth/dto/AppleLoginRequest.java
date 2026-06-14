package com.dontlift.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record AppleLoginRequest(
        @NotBlank String identityToken,
        /** 可选：仅首次/重新授权时 Apple 才下发。用于后端换取 refresh_token 供删号 revoke。 */
        String authorizationCode
) {
}
