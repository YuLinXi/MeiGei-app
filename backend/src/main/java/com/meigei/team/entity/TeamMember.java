package com.meigei.team.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

/** 成员关系。role: owner|member。无同步信封，归属 Team 服务端管理。 */
@Data
@TableName("team_member")
public class TeamMember {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID teamId;

    private UUID userId;

    private String role;

    private OffsetDateTime joinedAt;
}
