package com.meigei.team.dto;

import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 成员视图：在 {@code team_member} 基础上 join {@code app_user.display_name}，
 * 供 Team 详情页渲染 monogram 首字、动态卡昵称、退出/解散 sheet 上下文。
 * display_name 可能为 null（用户未设名），由客户端兜底。
 */
@Data
public class TeamMemberView {
    private UUID id;
    private UUID teamId;
    private UUID userId;
    private String role;
    private OffsetDateTime joinedAt;
    private String displayName;
}
