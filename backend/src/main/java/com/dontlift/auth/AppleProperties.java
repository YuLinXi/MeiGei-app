package com.dontlift.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "app.apple")
public record AppleProperties(
        List<String> audiences,
        String issuer,
        String jwksUri,
        /** client_secret 的 sub：Sign in with Apple 的 client_id（原生 App 即 bundle id / Service ID）。 */
        String clientId,
        /** client_secret 的 iss：Apple Developer Team ID。 */
        String teamId,
        /** 签发 client_secret 用的 .p8 私钥 Key ID。 */
        String keyId,
        /** .p8 私钥文件路径。缺失则 token 换取 / revoke 整体降级跳过。 */
        String keyPath
) {

    /** 是否具备签发 client_secret（换 refresh_token / revoke）的完整凭据。 */
    public boolean clientSecretConfigured() {
        return notBlank(clientId) && notBlank(teamId) && notBlank(keyId) && notBlank(keyPath);
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }
}
