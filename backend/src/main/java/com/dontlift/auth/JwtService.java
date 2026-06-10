package com.dontlift.auth;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.JWSSigner;
import com.nimbusds.jose.JWSVerifier;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jose.crypto.MACVerifier;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.UUID;

/** 签发/校验本服务自有 JWT（HS256），sub = userId。 */
@Service
public class JwtService {

    private final byte[] secret;
    private final long ttlDays;

    public JwtService(JwtProperties props) {
        this.secret = props.secret().getBytes(StandardCharsets.UTF_8);
        this.ttlDays = props.ttlDays();
    }

    public String issue(UUID userId) {
        try {
            Instant now = Instant.now();
            JWTClaimsSet claims = new JWTClaimsSet.Builder()
                    .subject(userId.toString())
                    .issueTime(Date.from(now))
                    .expirationTime(Date.from(now.plus(ttlDays, ChronoUnit.DAYS)))
                    .build();
            SignedJWT jwt = new SignedJWT(new JWSHeader(JWSAlgorithm.HS256), claims);
            JWSSigner signer = new MACSigner(secret);
            jwt.sign(signer);
            return jwt.serialize();
        } catch (Exception e) {
            throw new IllegalStateException("签发 JWT 失败", e);
        }
    }

    /** 校验通过返回 userId；否则返回 null。 */
    public UUID parse(String token) {
        try {
            SignedJWT jwt = SignedJWT.parse(token);
            JWSVerifier verifier = new MACVerifier(secret);
            if (!jwt.verify(verifier)) {
                return null;
            }
            JWTClaimsSet claims = jwt.getJWTClaimsSet();
            Date exp = claims.getExpirationTime();
            if (exp == null || exp.before(new Date())) {
                return null;
            }
            return UUID.fromString(claims.getSubject());
        } catch (Exception e) {
            return null;
        }
    }
}
