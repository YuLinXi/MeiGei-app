package com.dontlift.account;

import com.dontlift.account.dto.ProfileResponse;
import com.dontlift.security.SecurityUtils;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * 用户画像 REST（服务端权威域）。JWT 即身份，仅作用于当前登录用户。
 * GET /me 只读回灌；PATCH /account/profile 部分更新，幂等由 IdempotencyFilter 统一保障。
 */
@RestController
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    /** 当前用户完整画像；displayName 为空表示称呼未补全（客户端据此拦首登补全页）。 */
    @GetMapping("/me")
    public ProfileResponse me() {
        return profileService.me(SecurityUtils.currentUserId());
    }

    /** 部分更新画像（带 Idempotency-Key）。请求体含 displayName/sex 任意子集。 */
    @PatchMapping("/account/profile")
    public ProfileResponse updateProfile(@RequestBody JsonNode body) {
        return profileService.update(SecurityUtils.currentUserId(), body);
    }
}
