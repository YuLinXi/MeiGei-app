package com.dontlift.account;

import com.dontlift.account.dto.ProfileResponse;
import com.dontlift.account.entity.AppUser;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.common.web.AppException;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;
import java.util.UUID;

/**
 * 用户画像读写（服务端权威域，非 LWW 同步）。称呼 / 性别挂在业务主体 app_user。
 * PATCH 走真正的部分更新：以请求体「字段是否出现」决定是否改动。
 */
@Service
@RequiredArgsConstructor
public class ProfileService {

    private static final Set<String> SEXES = Set.of("male", "female");
    private static final int MAX_NAME_LEN = 20;

    private final AppUserMapper appUserMapper;

    /** 读当前用户完整画像。 */
    public ProfileResponse me(UUID userId) {
        return toResponse(requireUser(userId));
    }

    /**
     * 部分更新画像。请求体可含 displayName / sex 任意子集；缺省字段不改动。
     * 称呼去空白 1–20；性别枚举 male/female。
     */
    @Transactional
    public ProfileResponse update(UUID userId, JsonNode body) {
        AppUser user = requireUser(userId);

        if (body.has("displayName")) {
            JsonNode n = body.get("displayName");
            // 称呼不支持清空（必填）：显式 null 视为不改动，仅在有值时校验并写入。
            if (!n.isNull()) {
                String name = n.asText().trim();
                if (name.isEmpty() || name.length() > MAX_NAME_LEN) {
                    throw AppException.badRequest("称呼需为 1–" + MAX_NAME_LEN + " 字符");
                }
                user.setDisplayName(name);
            }
        }

        if (body.has("sex")) {
            JsonNode n = body.get("sex");
            if (!n.isNull()) {
                String sex = n.asText();
                if (!SEXES.contains(sex)) {
                    throw AppException.badRequest("性别取值非法（仅 male/female）");
                }
                user.setSex(sex);
            }
        }

        appUserMapper.updateById(user);
        return toResponse(user);
    }

    private AppUser requireUser(UUID userId) {
        AppUser user = appUserMapper.selectById(userId);
        if (user == null) {
            throw AppException.notFound("用户不存在");
        }
        return user;
    }

    private ProfileResponse toResponse(AppUser u) {
        // sex 原样回传（可空）：null 表示从未设置，客户端据此保留本地、展示层缺省按男。
        return new ProfileResponse(u.getId(), u.getDisplayName(), u.getSex(), u.getFirstLoginEmail());
    }
}
