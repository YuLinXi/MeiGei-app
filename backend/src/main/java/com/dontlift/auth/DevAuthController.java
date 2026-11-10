package com.dontlift.auth;

import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.auth.dto.AuthResponse;
import com.dontlift.common.web.AppException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * 本地联调专用：免 Apple 直接造用户 + 签 JWT。
 * 仅当 app.dev.token-enabled=true 时注册（默认 false，生产环境安全关闭）。
 */
@RestController
@RequestMapping("/auth/dev")
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "app.dev", name = "token-enabled", havingValue = "true")
public class DevAuthController {

    private final DevDataSeeder devDataSeeder;
    private final JwtService jwtService;
    private final AppUserMapper appUserMapper;

    @Value("${app.dev.user-id:}")
    private String userId = "";

    @PostMapping("/token")
    public AuthResponse devToken() {
        // 导入真实数据时直接登录指定的本地账号，避免混入或重置示例数据。
        if (!userId.isBlank()) {
            UUID localUserId = UUID.fromString(userId);
            if (appUserMapper.selectById(localUserId) == null) {
                throw AppException.notFound("指定的本地开发账号不存在或已删除");
            }
            return new AuthResponse(jwtService.issue(localUserId), localUserId, false);
        }
        DevDataSeeder.SeedResult seed = devDataSeeder.seed();
        return new AuthResponse(jwtService.issue(seed.userId()), seed.userId(), seed.created());
    }
}
