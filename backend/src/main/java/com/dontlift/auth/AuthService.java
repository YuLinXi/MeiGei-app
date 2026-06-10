package com.dontlift.auth;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.dontlift.account.entity.AppUser;
import com.dontlift.account.entity.UserIdentity;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.account.mapper.UserIdentityMapper;
import com.dontlift.auth.dto.AuthResponse;
import com.dontlift.common.id.Uuid7;
import com.nimbusds.jwt.JWTClaimsSet;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private static final String PROVIDER_APPLE = "apple";

    private final AppleTokenVerifier appleTokenVerifier;
    private final JwtService jwtService;
    private final AppUserMapper appUserMapper;
    private final UserIdentityMapper userIdentityMapper;
    private final ObjectMapper objectMapper;

    /** Apple 登录：校验 identityToken，首登建账户、老用户复用，签发自有 JWT。 */
    @Transactional
    public AuthResponse loginWithApple(String identityToken) {
        JWTClaimsSet claims = appleTokenVerifier.verify(identityToken);
        String sub = claims.getSubject();
        String email = safeClaim(claims, "email");

        UserIdentity identity = userIdentityMapper.selectOne(new LambdaQueryWrapper<UserIdentity>()
                .eq(UserIdentity::getProvider, PROVIDER_APPLE)
                .eq(UserIdentity::getProviderUserId, sub));

        boolean newUser = false;
        UUID userId;
        if (identity != null) {
            userId = identity.getUserId();
        } else {
            AppUser user = new AppUser();
            user.setId(Uuid7.generate());
            user.setFirstLoginEmail(email);
            appUserMapper.insert(user);

            identity = new UserIdentity();
            identity.setId(Uuid7.generate());
            identity.setUserId(user.getId());
            identity.setProvider(PROVIDER_APPLE);
            identity.setProviderUserId(sub);
            identity.setEmail(email);
            userIdentityMapper.insert(identity);

            userId = user.getId();
            newUser = true;
        }

        return new AuthResponse(jwtService.issue(userId), userId, newUser);
    }

    /**
     * 处理 Apple 服务端到服务端撤销通知（form 字段 payload = 签名 JWT）。
     * consent-revoked / account-delete 时注销该用户。
     */
    @Transactional
    public void handleRevokeNotification(String payload) {
        JWTClaimsSet claims = appleTokenVerifier.verify(payload);
        String eventsRaw = safeClaim(claims, "events");
        if (eventsRaw == null) {
            log.warn("撤销通知缺少 events");
            return;
        }
        try {
            JsonNode event = objectMapper.readTree(eventsRaw);
            String type = event.path("type").asText();
            String sub = event.path("sub").asText();
            if ("consent-revoked".equals(type) || "account-delete".equals(type)) {
                revokeBySub(sub);
            } else {
                log.info("忽略 Apple 事件类型: {}", type);
            }
        } catch (Exception e) {
            log.error("解析 Apple events 失败", e);
        }
    }

    private void revokeBySub(String sub) {
        UserIdentity identity = userIdentityMapper.selectOne(new LambdaQueryWrapper<UserIdentity>()
                .eq(UserIdentity::getProvider, PROVIDER_APPLE)
                .eq(UserIdentity::getProviderUserId, sub));
        if (identity == null) {
            return;
        }
        // 匿名化 PII + 软删用户与身份
        UUID userId = identity.getUserId();
        AppUser user = appUserMapper.selectById(userId);
        if (user != null) {
            user.setDisplayName(null);
            user.setFirstLoginEmail(null);
            appUserMapper.updateById(user);
            appUserMapper.deleteById(userId); // @TableLogic → 写 deleted_at
        }
        userIdentityMapper.deleteById(identity.getId());
        log.info("已注销用户 {} (apple sub 撤销)", userId);
    }

    private String safeClaim(JWTClaimsSet claims, String name) {
        try {
            return claims.getStringClaim(name);
        } catch (Exception e) {
            return null;
        }
    }
}
