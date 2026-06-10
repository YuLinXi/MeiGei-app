package com.dontlift.team.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 训练即打卡：一次训练在所属 Team 内的可见记录。
 * summary 为成交时刻的快照 jsonb（不依赖原始 workout 后续增删）。
 * workoutId 为软指针无 FK。uq(team_id,user_id,workout_id) 保证幂等。
 */
@Data
@TableName("team_checkin")
public class TeamCheckin {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID teamId;

    private UUID userId;

    private UUID workoutId;

    private LocalDate checkinDate;

    /** jsonb 快照：动作数/总组数/总容量等展示用结构化数据。 */
    private String summary;

    private OffsetDateTime createdAt;
}
