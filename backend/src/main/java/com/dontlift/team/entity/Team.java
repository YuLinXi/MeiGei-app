package com.dontlift.team.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.dontlift.common.entity.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.util.UUID;

/** 私密小空间。服务端权威共享实体（非离线同步域），软删=解散。 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("team")
public class Team extends BaseEntity {

    private String name;

    private UUID ownerUserId;

    private String inviteCode;
}
