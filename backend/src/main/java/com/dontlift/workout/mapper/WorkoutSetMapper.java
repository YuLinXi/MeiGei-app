package com.dontlift.workout.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.workout.entity.WorkoutSet;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

public interface WorkoutSetMapper extends BaseMapper<WorkoutSet> {

    @Select("SELECT * FROM workout_set WHERE workout_exercise_id = #{exerciseId} ORDER BY set_index")
    List<WorkoutSet> findByExercise(@Param("exerciseId") UUID exerciseId);

    @Delete("DELETE FROM workout_set WHERE workout_exercise_id = #{exerciseId}")
    int deleteByExercise(@Param("exerciseId") UUID exerciseId);
}
