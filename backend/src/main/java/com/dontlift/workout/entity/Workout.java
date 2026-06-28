package com.dontlift.workout.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.dontlift.common.entity.BaseEntity;
import com.dontlift.sync.UserOwned;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 一次训练（聚合根）。其子树 workout_exercise/workout_set 随聚合整体上传，
 * 服务端按 workoutId 全量替换（ON DELETE CASCADE）。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("workout")
public class Workout extends BaseEntity implements UserOwned {

    private UUID userId;

    /** 来源模板，软指针无 FK。 */
    private UUID planId;

    private UUID sourceShareId;

    private UUID sourceShareVersionId;

    private String sourcePlanNameSnapshot;

    private String title;

    private OffsetDateTime startedAt;

    private OffsetDateTime endedAt;

    private String note;
}
