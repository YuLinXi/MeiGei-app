package com.dontlift.team.dto;

import com.dontlift.team.entity.CheckinReaction;
import com.dontlift.team.entity.TeamCheckin;

import java.util.List;

public record TeamCheckinFeed(
        List<TeamCheckin> checkins,
        List<CheckinReaction> reactions
) {
}
