package com.dontlift.auth;

import com.dontlift.auth.dto.AuthResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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

    @PostMapping("/token")
    public AuthResponse devToken() {
        DevDataSeeder.SeedResult seed = devDataSeeder.seed();
        return new AuthResponse(jwtService.issue(seed.userId()), seed.userId(), seed.created());
    }
}
