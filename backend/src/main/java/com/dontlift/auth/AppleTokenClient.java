package com.dontlift.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

/**
 * 调用 Apple 身份服务的 token / revoke endpoint。
 * 网络/凭据问题以返回值或 null 表达，由调用方降级处理（不抛断流程）。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AppleTokenClient {

    private static final String TOKEN_URL = "https://appleid.apple.com/auth/token";
    private static final String REVOKE_URL = "https://appleid.apple.com/auth/revoke";

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();
    private final ObjectMapper objectMapper;

    /**
     * 用 authorizationCode 换 refresh_token。
     * @return refresh_token；失败返回 null（不抛异常）。
     */
    public String exchangeRefreshToken(String clientId, String clientSecret, String authorizationCode) {
        String form = "grant_type=authorization_code"
                + "&code=" + enc(authorizationCode)
                + "&client_id=" + enc(clientId)
                + "&client_secret=" + enc(clientSecret);
        try {
            HttpResponse<String> resp = post(TOKEN_URL, form);
            if (resp.statusCode() / 100 != 2) {
                log.warn("Apple /auth/token 非 2xx: status={}", resp.statusCode());
                return null;
            }
            JsonNode body = objectMapper.readTree(resp.body());
            JsonNode rt = body.get("refresh_token");
            return rt != null && !rt.isNull() ? rt.asText() : null;
        } catch (Exception e) {
            log.warn("Apple /auth/token 调用异常", e);
            return null;
        }
    }

    /**
     * 撤销 refresh_token（连带撤销该用户对本 App 的授权）。
     * @return 是否 2xx 成功。
     */
    public boolean revokeToken(String clientId, String clientSecret, String refreshToken) {
        String form = "token=" + enc(refreshToken)
                + "&token_type_hint=refresh_token"
                + "&client_id=" + enc(clientId)
                + "&client_secret=" + enc(clientSecret);
        try {
            HttpResponse<String> resp = post(REVOKE_URL, form);
            boolean ok = resp.statusCode() / 100 == 2;
            if (!ok) {
                log.warn("Apple /auth/revoke 非 2xx: status={}", resp.statusCode());
            }
            return ok;
        } catch (Exception e) {
            log.warn("Apple /auth/revoke 调用异常", e);
            return false;
        }
    }

    private HttpResponse<String> post(String url, String form) throws Exception {
        HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(10))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(form, StandardCharsets.UTF_8))
                .build();
        return httpClient.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
    }

    private static String enc(String v) {
        return URLEncoder.encode(v, StandardCharsets.UTF_8);
    }
}
