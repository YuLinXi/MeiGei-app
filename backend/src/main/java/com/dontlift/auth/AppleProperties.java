package com.dontlift.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "app.apple")
public record AppleProperties(
        List<String> audiences,
        String issuer,
        String jwksUri
) {
}
