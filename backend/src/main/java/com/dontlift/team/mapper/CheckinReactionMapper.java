package com.dontlift.team.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.team.entity.CheckinReaction;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.UUID;

public interface CheckinReactionMapper extends BaseMapper<CheckinReaction> {

    @Select("SELECT * FROM checkin_reaction WHERE checkin_id = #{checkinId} AND user_id = #{userId}")
    CheckinReaction findByCheckinAndUser(@Param("checkinId") UUID checkinId, @Param("userId") UUID userId);

    @Select("SELECT * FROM checkin_reaction WHERE checkin_id = #{checkinId} ORDER BY created_at")
    List<CheckinReaction> findByCheckin(@Param("checkinId") UUID checkinId);
}
