package com.dontlift.workout.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.util.UUID;

/** 某动作的某一组（孙）。PR/曲线由这些原始组重算，不存冗余统计。 */
@Data
@TableName("workout_set")
public class WorkoutSet {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID workoutExerciseId;

    private Integer setIndex;

    private BigDecimal weightKg;

    private Integer reps;

    private Boolean completed;

    private String note;

    /** 完成该组后启动休息时采用的预计秒数；旧数据可为空。 */
    private Integer plannedRestSeconds;

    /** 该组休息完成后的真实秒数；旧数据可为空。 */
    private Integer actualRestSeconds;

    /** 组结构类型（"working"/"drop"）。旧 "warmup" 上传会在同步服务里兼容转为 isWarmup。 */
    private String setType;

    /** 热身标记，独立于结构类型。 */
    private Boolean isWarmup;

    /**
     * 递减组分段 jsonb 字符串。普通组/热身组为空数组。
     * 结构示例：[{segmentId, segmentIndex, weightKg, reps}]。
     */
    private String segments = "[]";
}
