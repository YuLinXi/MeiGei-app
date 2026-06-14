package com.dontlift.auth;

import com.dontlift.account.entity.AppUser;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.auth.dto.AuthResponse;
import com.dontlift.common.id.Uuid7;
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

    private final AppUserMapper appUserMapper;
    private final JwtService jwtService;

    @PostMapping("/token")
    public AuthResponse devToken() {
        AppUser user = new AppUser();
        user.setId(Uuid7.generate());
        // 不预设称呼：与真实 Apple 首登一致，留空 displayName，
        // 令客户端走首登资料补全（昵称/性别）门控，便于联调验证该流程。
        appUserMapper.insert(user);
        return new AuthResponse(jwtService.issue(user.getId()), user.getId(), true);
    }
}
