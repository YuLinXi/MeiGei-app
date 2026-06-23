package com.dontlift.workout.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.workout.entity.WorkoutExercise;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

public interface WorkoutExerciseMapper extends BaseMapper<WorkoutExercise> {

    @Select("SELECT * FROM workout_exercise WHERE workout_id = #{workoutId} ORDER BY order_index")
    List<WorkoutExercise> findByWorkout(@Param("workoutId") UUID workoutId);

    @Select("""
            <script>
            SELECT * FROM workout_exercise
            WHERE workout_id IN
            <foreach collection="workoutIds" item="id" open="(" separator="," close=")">
                #{id}
            </foreach>
            ORDER BY workout_id, order_index
            </script>
            """)
    List<WorkoutExercise> findByWorkouts(@Param("workoutIds") List<UUID> workoutIds);

    // 整树替换：删动作即级联删其下各组（ON DELETE CASCADE）
    @Delete("DELETE FROM workout_exercise WHERE workout_id = #{workoutId}")
    int deleteByWorkout(@Param("workoutId") UUID workoutId);
}
