package com.dontlift.auth;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.RemoteKeySourceException;
import com.nimbusds.jose.jwk.JWKMatcher;
import com.nimbusds.jose.jwk.JWKSelector;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.jwk.source.JWKSourceBuilder;
import com.nimbusds.jose.proc.JWSKeySelector;
import com.nimbusds.jose.proc.JWSVerificationKeySelector;
import com.nimbusds.jose.proc.SecurityContext;
import com.nimbusds.jose.util.DefaultResourceRetriever;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.proc.ConfigurableJWTProcessor;
import com.nimbusds.jwt.proc.DefaultJWTProcessor;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.URL;
import java.util.Date;

/**
 * 校验 Apple 下发的 identityToken（RS256，由 Apple 私钥签名）。
 * 公钥取自 Apple JWKS，nimbus 自带缓存与轮换。校验签名 + iss + aud + 过期。
 */
@Slf4j
@Component
public class AppleTokenVerifier {

    private static final int JWKS_CONNECT_TIMEOUT_MS = 5_000;
    private static final int JWKS_READ_TIMEOUT_MS = 5_000;
    private static final int JWKS_SIZE_LIMIT_BYTES = 64 * 1024;
    private static final long JWKS_CACHE_TTL_MS = 24 * 60 * 60 * 1000L;
    private static final long JWKS_CACHE_REFRESH_TIMEOUT_MS = 15_000L;
    private static final long JWKS_OUTAGE_TOLERANCE_MS = 24 * 60 * 60 * 1000L;

    private final AppleProperties props;
    private final JWKSource<SecurityContext> keySource;
    private final ConfigurableJWTProcessor<SecurityContext> processor;

    public AppleTokenVerifier(AppleProperties props) throws Exception {
        this.props = props;
        URL jwksUrl = URI.create(props.jwksUri()).toURL();
        DefaultResourceRetriever retriever = new DefaultResourceRetriever(
                JWKS_CONNECT_TIMEOUT_MS, JWKS_READ_TIMEOUT_MS, JWKS_SIZE_LIMIT_BYTES);
        this.keySource = JWKSourceBuilder.<SecurityContext>create(jwksUrl, retriever)
                .cache(JWKS_CACHE_TTL_MS, JWKS_CACHE_REFRESH_TIMEOUT_MS)
                .retrying(true)
                .outageTolerant(JWKS_OUTAGE_TOLERANCE_MS)
                .build();
        DefaultJWTProcessor<SecurityContext> p = new DefaultJWTProcessor<>();
        JWSKeySelector<SecurityContext> keySelector =
                new JWSVerificationKeySelector<>(JWSAlgorithm.RS256, this.keySource);
        p.setJWSKeySelector(keySelector);
        this.processor = p;
    }

    @PostConstruct
    void warmUpJwks() {
        try {
            var keys = keySource.get(new JWKSelector(new JWKMatcher.Builder().build()), null);
            log.info("Apple JWKS 预热成功 keys={}", keys.size());
        } catch (Exception e) {
            log.warn("Apple JWKS 预热失败，将在首次 Apple 登录时重试: {}", e.getMessage());
        }
    }

    /** 校验通过返回 claims（含 sub、email）；否则抛 {@link AppleTokenException}。 */
    public JWTClaimsSet verify(String identityToken) {
        try {
            JWTClaimsSet claims = processor.process(identityToken, null);
            if (!props.issuer().equals(claims.getIssuer())) {
                throw new AppleTokenException("issuer 不匹配");
            }
            boolean audOk = claims.getAudience().stream().anyMatch(props.audiences()::contains);
            if (!audOk) {
                throw new AppleTokenException("audience 不匹配");
            }
            Date exp = claims.getExpirationTime();
            if (exp == null || exp.before(new Date())) {
                throw new AppleTokenException("token 已过期");
            }
            return claims;
        } catch (AppleTokenException e) {
            throw e;
        } catch (Exception e) {
            if (isRemoteKeyFailure(e)) {
                throw new AppleJwksUnavailableException("Apple 登录校验服务暂不可用，请稍后重试");
            }
            throw new AppleTokenException("identityToken 校验失败: " + e.getMessage());
        }
    }

    private boolean isRemoteKeyFailure(Throwable e) {
        Throwable current = e;
        while (current != null) {
            if (current instanceof RemoteKeySourceException) {
                return true;
            }
            String message = current.getMessage();
            if (message != null && message.contains("Couldn't retrieve JWK set")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    public static class AppleTokenException extends RuntimeException {
        public AppleTokenException(String message) {
            super(message);
        }
    }

    public static class AppleJwksUnavailableException extends RuntimeException {
        public AppleJwksUnavailableException(String message) {
            super(message);
        }
    }
}
