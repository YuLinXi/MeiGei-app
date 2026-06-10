package com.dontlift.push;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.apns")
public record ApnsProperties(
        String keyPath,
        String keyId,
        String teamId,
        String topic,
        boolean production
) {
    public boolean configured() {
        return keyPath != null && !keyPath.isBlank()
                && keyId != null && !keyId.isBlank()
                && teamId != null && !teamId.isBlank();
    }
}
