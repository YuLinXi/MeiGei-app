package com.meigei.push;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.meigei.common.id.Uuid7;
import com.meigei.push.dto.RegisterTokenRequest;
import com.meigei.push.entity.DeviceToken;
import com.meigei.push.mapper.DeviceTokenMapper;
import com.meigei.security.SecurityUtils;
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

    /** 注册/更新本设备的 APNs token（token 唯一，重复注册则改归属与环境）。 */
    @PostMapping("/token")
    public ResponseEntity<Void> register(@Valid @RequestBody RegisterTokenRequest req) {
        UUID userId = SecurityUtils.currentUserId();
        DeviceToken existing = mapper.selectOne(new LambdaQueryWrapper<DeviceToken>()
                .eq(DeviceToken::getApnsToken, req.apnsToken()));
        if (existing == null) {
            DeviceToken dt = new DeviceToken();
            dt.setId(Uuid7.generate());
            dt.setUserId(userId);
            dt.setApnsToken(req.apnsToken());
            dt.setEnvironment(req.environment());
            mapper.insert(dt);
        } else {
            existing.setUserId(userId);
            existing.setEnvironment(req.environment());
            mapper.updateById(existing);
        }
        return ResponseEntity.ok().build();
    }
}
