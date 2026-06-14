package com.dontlift.auth;

import com.dontlift.account.entity.UserIdentity;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.account.mapper.UserIdentityMapper;
import com.dontlift.auth.dto.AuthResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nimbusds.jwt.JWTClaimsSet;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 3.4：登录回传 authorizationCode 时持久化 refresh_token；无 code 时跳过且不阻断登录。 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AuthServiceRefreshTokenTest {

    @Mock AppleTokenVerifier appleTokenVerifier;
    @Mock JwtService jwtService;
    @Mock AppUserMapper appUserMapper;
    @Mock UserIdentityMapper userIdentityMapper;
    @Mock ObjectMapper objectMapper;
    @Mock AppleClientSecretFactory appleClientSecretFactory;
    @Mock AppleTokenClient appleTokenClient;

    @InjectMocks AuthService authService;

    private final UUID identityId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    private void existingAppleUser() {
        when(appleTokenVerifier.verify(any()))
                .thenReturn(new JWTClaimsSet.Builder().subject("apple-sub").build());
        UserIdentity identity = new UserIdentity();
        identity.setId(identityId);
        identity.setUserId(userId);
        when(userIdentityMapper.selectOne(any())).thenReturn(identity);
        when(jwtService.issue(userId)).thenReturn("jwt-token");
    }

    @Test
    void login_persistsRefreshTokenWhenCodeAndCredentialsPresent() {
        existingAppleUser();
        when(appleClientSecretFactory.available()).thenReturn(true);
        when(appleClientSecretFactory.clientId()).thenReturn("com.example.app");
        when(appleClientSecretFactory.create()).thenReturn("signed-secret");
        when(appleTokenClient.exchangeRefreshToken("com.example.app", "signed-secret", "auth-code"))
                .thenReturn("rt-xyz");

        AuthResponse resp = authService.loginWithApple("id-token", "auth-code");

        assertThat(resp.token()).isEqualTo("jwt-token");
        verify(userIdentityMapper).updateRefreshToken(identityId, "rt-xyz");
    }

    @Test
    void login_skipsRefreshTokenWhenNoCode() {
        existingAppleUser();

        AuthResponse resp = authService.loginWithApple("id-token", null);

        assertThat(resp.token()).isEqualTo("jwt-token");
        verify(userIdentityMapper, never()).updateRefreshToken(any(), any());
        verify(appleTokenClient, never()).exchangeRefreshToken(any(), any(), any());
    }
}
