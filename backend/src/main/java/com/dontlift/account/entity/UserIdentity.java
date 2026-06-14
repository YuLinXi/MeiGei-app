package com.dontlift.account.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 登录身份。一个 AppUser 可挂多种 provider；唯一约束在 (provider, provider_user_id)。
 * 不带软删/乐观锁，故不继承 BaseEntity。
 */
@Data
@TableName("user_identity")
public class UserIdentity {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID userId;

    /** apple（预留 phone/wechat）。 */
    private String provider;

    /** Apple sub。 */
    private String providerUserId;

    private String email;

    /** Apple refresh_token（由登录 authorizationCode 换取），仅用于删号时主动撤销授权；不入日志。可空。 */
    private String appleRefreshToken;

    @TableField(fill = FieldFill.INSERT)
    private OffsetDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private OffsetDateTime updatedAt;
}
