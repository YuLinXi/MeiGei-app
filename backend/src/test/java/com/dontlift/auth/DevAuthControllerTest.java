package com.dontlift.auth;

import com.dontlift.account.entity.AppUser;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.common.web.AppException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DevAuthControllerTest {

    @Mock DevDataSeeder devDataSeeder;
    @Mock JwtService jwtService;
    @Mock AppUserMapper appUserMapper;
    @InjectMocks DevAuthController controller;

    @Test
    void defaultLoginStillSeedsExampleData() {
        UUID userId = UUID.randomUUID();
        when(devDataSeeder.seed()).thenReturn(new DevDataSeeder.SeedResult(userId, true));
        when(jwtService.issue(userId)).thenReturn("dev-token");

        var response = controller.devToken();

        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.newUser()).isTrue();
        verifyNoInteractions(appUserMapper);
    }

    @Test
    void configuredLoginUsesImportedAccountWithoutSeeding() {
        UUID userId = UUID.randomUUID();
        ReflectionTestUtils.setField(controller, "userId", userId.toString());
        when(appUserMapper.selectById(userId)).thenReturn(new AppUser());
        when(jwtService.issue(userId)).thenReturn("local-token");

        var response = controller.devToken();

        assertThat(response.userId()).isEqualTo(userId);
        assertThat(response.token()).isEqualTo("local-token");
        assertThat(response.newUser()).isFalse();
        verifyNoInteractions(devDataSeeder);
    }

    @Test
    void missingOrDeletedAccountDoesNotIssueTokenOrSeedData() {
        ReflectionTestUtils.setField(controller, "userId", UUID.randomUUID().toString());

        assertThatThrownBy(controller::devToken)
                .isInstanceOfSatisfying(AppException.class,
                        error -> assertThat(error.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
        verifyNoInteractions(jwtService, devDataSeeder);
    }
}
