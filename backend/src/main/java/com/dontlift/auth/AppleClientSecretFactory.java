package com.dontlift.auth;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.interfaces.ECPrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.Date;
import java.util.List;

/**
 * 签发 Apple client_secret（ES256 JWT，aud=appleid.apple.com），供调用
 * Apple {@code /auth/token}（换 refresh_token）与 {@code /auth/revoke}（撤销授权）使用。
 * 复用 nimbus-jose-jwt。.p8 私钥缺失或解析失败时 {@link #available()} 返回 false，调用方降级跳过。
 */
@Slf4j
@Component
public class AppleClientSecretFactory {

    private static final String APPLE_AUD = "https://appleid.apple.com";

    private final AppleProperties props;

    public AppleClientSecretFactory(AppleProperties props) {
        this.props = props;
    }

    /** 凭据是否齐备（client_id / team_id / key_id / .p8 路径均配置）。 */
    public boolean available() {
        return props.clientSecretConfigured();
    }

    /** client_secret 的 sub（= client_id），调用 token/revoke 时一并提交。 */
    public String clientId() {
        return props.clientId();
    }

    /**
     * 签发一枚短时效（5 分钟）client_secret。
     * @throws IllegalStateException 凭据缺失或私钥不可用
     */
    public String create() {
        if (!available()) {
            throw new IllegalStateException("Apple client_secret 凭据缺失");
        }
        try {
            ECPrivateKey privateKey = loadPrivateKey(props.keyPath());
            Instant now = Instant.now();
            JWTClaimsSet claims = new JWTClaimsSet.Builder()
                    .issuer(props.teamId())
                    .issueTime(Date.from(now))
                    .expirationTime(Date.from(now.plus(5, ChronoUnit.MINUTES)))
                    .audience(List.of(APPLE_AUD))
                    .subject(props.clientId())
                    .build();
            SignedJWT jwt = new SignedJWT(
                    new JWSHeader.Builder(JWSAlgorithm.ES256).keyID(props.keyId()).build(),
                    claims);
            jwt.sign(new ECDSASigner(privateKey));
            return jwt.serialize();
        } catch (Exception e) {
            throw new IllegalStateException("签发 Apple client_secret 失败", e);
        }
    }

    private ECPrivateKey loadPrivateKey(String path) throws Exception {
        String pem = Files.readString(Path.of(path));
        String base64 = pem
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
        byte[] der = Base64.getDecoder().decode(base64);
        KeyFactory kf = KeyFactory.getInstance("EC");
        return (ECPrivateKey) kf.generatePrivate(new PKCS8EncodedKeySpec(der));
    }
}
