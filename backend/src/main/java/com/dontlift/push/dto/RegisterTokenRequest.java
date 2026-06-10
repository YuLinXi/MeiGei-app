package com.dontlift.push.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record RegisterTokenRequest(
        @NotBlank String apnsToken,
        @Pattern(regexp = "sandbox|production") String environment
) {
}
