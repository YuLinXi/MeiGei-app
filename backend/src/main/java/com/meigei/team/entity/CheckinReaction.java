package com.meigei.team.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

/** 打卡的表情回应。emoji: muscle|fire|clap|heart。uq(checkin_id,user_id) 一人一表情(可改)。 */
@Data
@TableName("checkin_reaction")
public class CheckinReaction {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID checkinId;

    private UUID userId;

    private String emoji;

    private OffsetDateTime createdAt;

    private OffsetDateTime updatedAt;
}
