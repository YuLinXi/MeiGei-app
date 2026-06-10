package com.dontlift.push;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.eatthepath.pushy.apns.ApnsClient;
import com.eatthepath.pushy.apns.ApnsClientBuilder;
import com.eatthepath.pushy.apns.auth.ApnsSigningKey;
import com.eatthepath.pushy.apns.util.SimpleApnsPayloadBuilder;
import com.eatthepath.pushy.apns.util.SimpleApnsPushNotification;
import com.eatthepath.pushy.apns.util.TokenUtil;
import com.dontlift.push.entity.DeviceToken;
import com.dontlift.push.mapper.DeviceTokenMapper;
import jakarta.annotation.PreDestroy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.File;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * APNs 推送（Pushy + .p8 token 认证）。未配置凭据时整体降级为 no-op，
 * 使本地/测试环境无需 Apple 私钥即可运行。
 */
@Slf4j
@Service
public class PushService {

    private final ApnsProperties props;
    private final DeviceTokenMapper deviceTokenMapper;
    private final ApnsClient client; // 可空：未配置时为 null

    public PushService(ApnsProperties props, DeviceTokenMapper deviceTokenMapper) {
        this.props = props;
        this.deviceTokenMapper = deviceTokenMapper;
        this.client = buildClientOrNull(props);
        if (client == null) {
            log.warn("APNs 未配置（缺 .p8/keyId/teamId），推送降级为 no-op");
        }
    }

    private ApnsClient buildClientOrNull(ApnsProperties props) {
        if (!props.configured()) {
            return null;
        }
        try {
            String host = props.production()
                    ? ApnsClientBuilder.PRODUCTION_APNS_HOST
                    : ApnsClientBuilder.DEVELOPMENT_APNS_HOST;
            return new ApnsClientBuilder()
                    .setApnsServer(host)
                    .setSigningKey(ApnsSigningKey.loadFromPkcs8File(
                            new File(props.keyPath()), props.teamId(), props.keyId()))
                    .build();
        } catch (Exception e) {
            log.error("初始化 APNs 客户端失败，推送降级为 no-op", e);
            return null;
        }
    }

    /** 向某用户的所有设备发推送（打卡/表情回应等事件）。 */
    public void sendToUser(UUID userId, String title, String body, Map<String, String> data) {
        if (client == null) {
            return;
        }
        List<DeviceToken> tokens = deviceTokenMapper.selectList(
                new LambdaQueryWrapper<DeviceToken>().eq(DeviceToken::getUserId, userId));
        for (DeviceToken dt : tokens) {
            send(dt.getApnsToken(), title, body, data);
        }
    }

    private void send(String deviceToken, String title, String body, Map<String, String> data) {
        try {
            SimpleApnsPayloadBuilder payload = new SimpleApnsPayloadBuilder();
            payload.setAlertTitle(title);
            payload.setAlertBody(body);
            payload.setSound("default");
            if (data != null) {
                data.forEach(payload::addCustomProperty);
            }
            SimpleApnsPushNotification notification = new SimpleApnsPushNotification(
                    TokenUtil.sanitizeTokenString(deviceToken), props.topic(), payload.build());
            client.sendNotification(notification);
        } catch (Exception e) {
            log.warn("发送 APNs 失败 token={}", deviceToken, e);
        }
    }

    @PreDestroy
    public void close() {
        if (client != null) {
            client.close();
        }
    }
}
