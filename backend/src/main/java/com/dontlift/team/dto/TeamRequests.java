package com.dontlift.team.dto;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Team 域请求体集合。 */
public final class TeamRequests {

    private TeamRequests() {
    }

    public record CreateTeam(@NotBlank String name) {
    }

    public record JoinTeam(@NotBlank String inviteCode) {
    }

    public record UpdateSharePreference(@NotNull Boolean autoShareWorkouts) {
    }

    public record CheckIn(
            @NotNull UUID workoutId,
            @NotNull LocalDate checkinDate,
            @NotNull JsonNode summary,
            @NotEmpty List<UUID> teamIds
    ) {
    }

    public record React(@NotBlank String emoji) {
    }

    public record SharePlan(
            @NotNull UUID sourcePlanId,
            String planNameSnapshot,
            String items
    ) {
    }

    public record SharePlanEvent(
            @NotBlank String eventType,
            UUID workoutId,
            LocalDate eventDate
    ) {
    }
}
