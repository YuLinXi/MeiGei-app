package com.meigei.auth;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.jwk.source.JWKSourceBuilder;
import com.nimbusds.jose.proc.JWSKeySelector;
import com.nimbusds.jose.proc.JWSVerificationKeySelector;
import com.nimbusds.jose.proc.SecurityContext;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.proc.ConfigurableJWTProcessor;
import com.nimbusds.jwt.proc.DefaultJWTProcessor;
import org.springframework.stereotype.Component;

import java.net.URL;
import java.util.Date;

/**
 * 校验 Apple 下发的 identityToken（RS256，由 Apple 私钥签名）。
 * 公钥取自 Apple JWKS，nimbus 自带缓存与轮换。校验签名 + iss + aud + 过期。
 */
@Component
public class AppleTokenVerifier {

    private final AppleProperties props;
    private final ConfigurableJWTProcessor<SecurityContext> processor;

    public AppleTokenVerifier(AppleProperties props) throws Exception {
        this.props = props;
        JWKSource<SecurityContext> keySource =
                JWKSourceBuilder.create(new URL(props.jwksUri())).build();
        DefaultJWTProcessor<SecurityContext> p = new DefaultJWTProcessor<>();
        JWSKeySelector<SecurityContext> keySelector =
                new JWSVerificationKeySelector<>(JWSAlgorithm.RS256, keySource);
        p.setJWSKeySelector(keySelector);
        this.processor = p;
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
            throw new AppleTokenException("identityToken 校验失败: " + e.getMessage());
        }
    }

    public static class AppleTokenException extends RuntimeException {
        public AppleTokenException(String message) {
            super(message);
        }
    }
}
