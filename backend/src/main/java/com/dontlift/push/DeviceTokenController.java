package com.dontlift.push;

import com.dontlift.common.id.Uuid7;
import com.dontlift.push.dto.RegisterTokenRequest;
import com.dontlift.push.entity.DeviceToken;
import com.dontlift.push.mapper.DeviceTokenMapper;
import com.dontlift.security.SecurityUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/devices")
@RequiredArgsConstructor
public class DeviceTokenController {

    private final DeviceTokenMapper mapper;

    /**
     * 注册/更新本设备的 APNs token。token 唯一，重复注册则改归属与环境。
     * 用原子 upsert（ON CONFLICT），避免登录与 didRegister 回调近乎同时注册同一 token 时
     * 「先查后插」竞态撞 uq_apns_token。
     */
    @PostMapping("/token")
    public ResponseEntity<Void> register(@Valid @RequestBody RegisterTokenRequest req) {
        UUID userId = SecurityUtils.currentUserId();
        DeviceToken dt = new DeviceToken();
        dt.setId(Uuid7.generate());
        dt.setUserId(userId);
        dt.setApnsToken(req.apnsToken());
        dt.setEnvironment(req.environment());
        mapper.upsertByApnsToken(dt);
        return ResponseEntity.ok().build();
    }
}
