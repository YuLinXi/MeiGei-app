package com.dontlift.auth;

import com.dontlift.auth.dto.AppleLoginRequest;
import com.dontlift.auth.dto.AuthResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth/apple")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /** 客户端 Apple 登录。 */
    @PostMapping
    public AuthResponse login(@Valid @RequestBody AppleLoginRequest request) {
        return authService.loginWithApple(request.identityToken());
    }

    /** Apple 服务端到服务端撤销通知回调（无需自有 JWT，靠 Apple 签名校验）。 */
    @PostMapping("/revoke")
    public ResponseEntity<Void> revoke(@RequestParam("payload") String payload) {
        authService.handleRevokeNotification(payload);
        return ResponseEntity.ok().build();
    }
}
