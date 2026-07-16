package com.dontlift.team;

import com.dontlift.common.web.AppException;
import com.dontlift.security.SecurityUtils;
import com.dontlift.team.dto.TeamMemberView;
import com.dontlift.team.dto.TeamPlanShareCard;
import com.dontlift.team.dto.TeamNudgeResponses.SendResult;
import com.dontlift.team.dto.TeamNudgeResponses.TodayState;
import com.dontlift.team.dto.TeamRequests.CreateTeam;
import com.dontlift.team.dto.TeamRequests.JoinTeam;
import com.dontlift.team.dto.TeamRequests.SharePlan;
import com.dontlift.team.dto.TeamRequests.SharePlanEvent;
import com.dontlift.team.dto.TeamRequests.UpdateSharePreference;
import com.dontlift.team.dto.TeamRequests.UpdateNudgePreference;
import com.dontlift.team.entity.Team;
import com.dontlift.team.entity.TeamPlanShareEvent;
import com.dontlift.team.entity.TeamPlanShareVersion;
import com.dontlift.workout.entity.WorkoutPlan;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/** Team 生命周期、成员管理与计划发布/Fork（5.2 / 5.3）。 */
@RestController
@RequestMapping("/teams")
@RequiredArgsConstructor
public class TeamController {

    private final TeamService teamService;
    private final TeamPlanService teamPlanService;
    private final TeamNudgeService teamNudgeService;

    @PostMapping
    public Team create(@Valid @RequestBody CreateTeam req) {
        return teamService.createTeam(SecurityUtils.currentUserId(), req.name());
    }

    @PostMapping("/join")
    public Team join(@Valid @RequestBody JoinTeam req) {
        return teamService.joinByInviteCode(SecurityUtils.currentUserId(), req.inviteCode());
    }

    @GetMapping
    public List<Team> myTeams() {
        return teamService.listMyTeams(SecurityUtils.currentUserId());
    }

    @GetMapping("/members/me/share-preferences")
    public List<TeamMemberView> mySharePreferences() {
        return teamService.listMySharePreferences(SecurityUtils.currentUserId());
    }

    @GetMapping("/{teamId}/members")
    public List<TeamMemberView> members(@PathVariable UUID teamId) {
        return teamService.getMembers(teamId, SecurityUtils.currentUserId());
    }

    @PatchMapping("/{teamId}/members/me/share-preferences")
    public TeamMemberView updateSharePreference(@PathVariable UUID teamId,
                                                @Valid @RequestBody UpdateSharePreference req) {
        return teamService.updateSharePreference(SecurityUtils.currentUserId(), teamId, req.autoShareWorkouts());
    }

    @GetMapping("/{teamId}/nudges/today")
    public TodayState todayNudgeState(@PathVariable UUID teamId) {
        return teamNudgeService.todayState(SecurityUtils.currentUserId(), teamId);
    }

    @PostMapping("/{teamId}/members/{recipientUserId}/nudges")
    public SendResult nudge(@PathVariable UUID teamId,
                            @PathVariable UUID recipientUserId,
                            @RequestHeader("Idempotency-Key") String idempotencyKey) {
        requireIdempotencyKey(idempotencyKey);
        return teamNudgeService.send(SecurityUtils.currentUserId(), teamId, recipientUserId);
    }

    @PatchMapping("/{teamId}/members/me/nudge-preferences")
    public TodayState updateNudgePreference(@PathVariable UUID teamId,
                                            @RequestHeader("Idempotency-Key") String idempotencyKey,
                                            @Valid @RequestBody UpdateNudgePreference req) {
        requireIdempotencyKey(idempotencyKey);
        return teamNudgeService.updatePreference(
                SecurityUtils.currentUserId(), teamId, req.receiveWorkoutNudges());
    }

    @DeleteMapping("/{teamId}/members/me")
    public void leave(@PathVariable UUID teamId) {
        teamService.leaveTeam(SecurityUtils.currentUserId(), teamId);
    }

    @DeleteMapping("/{teamId}")
    public void dissolve(@PathVariable UUID teamId) {
        teamService.dissolveTeam(SecurityUtils.currentUserId(), teamId);
    }

    @GetMapping("/{teamId}/plans")
    public List<WorkoutPlan> teamPlans(@PathVariable UUID teamId) {
        return teamPlanService.listTeamPlans(SecurityUtils.currentUserId(), teamId);
    }

    @GetMapping("/{teamId}/plan-shares")
    public List<TeamPlanShareCard> planShares(@PathVariable UUID teamId,
                                              @RequestParam(required = false) String weekStart) {
        return teamPlanService.listShareCards(SecurityUtils.currentUserId(), teamId);
    }

    @PostMapping("/{teamId}/plan-shares")
    public TeamPlanShareVersion sharePlan(@PathVariable UUID teamId,
                                          @RequestHeader("Idempotency-Key") String idempotencyKey,
                                          @Valid @RequestBody SharePlan req) {
        requireIdempotencyKey(idempotencyKey);
        return teamPlanService.shareToTeam(SecurityUtils.currentUserId(), teamId, req);
    }

    @DeleteMapping("/{teamId}/plan-shares/{shareId}")
    public void deletePlanShare(@PathVariable UUID teamId,
                                @PathVariable UUID shareId,
                                @RequestHeader("Idempotency-Key") String idempotencyKey) {
        requireIdempotencyKey(idempotencyKey);
        teamPlanService.deleteShare(SecurityUtils.currentUserId(), teamId, shareId);
    }

    @PostMapping("/{teamId}/plans/{planId}")
    public WorkoutPlan publish(@PathVariable UUID teamId,
                               @PathVariable UUID planId,
                               @RequestHeader("Idempotency-Key") String idempotencyKey) {
        requireIdempotencyKey(idempotencyKey);
        return teamPlanService.publishToTeam(SecurityUtils.currentUserId(), planId, teamId);
    }

    @PostMapping("/plans/{planId}/fork")
    public WorkoutPlan fork(@PathVariable UUID planId,
                            @RequestHeader("Idempotency-Key") String idempotencyKey) {
        requireIdempotencyKey(idempotencyKey);
        return teamPlanService.fork(SecurityUtils.currentUserId(), planId);
    }

    @PostMapping("/plan-share-versions/{versionId}/fork")
    public WorkoutPlan forkShareVersion(@PathVariable UUID versionId,
                                        @RequestHeader("Idempotency-Key") String idempotencyKey) {
        requireIdempotencyKey(idempotencyKey);
        return teamPlanService.forkVersion(SecurityUtils.currentUserId(), versionId);
    }

    @PostMapping("/plan-share-versions/{versionId}/events")
    public TeamPlanShareEvent recordShareEvent(@PathVariable UUID versionId,
                                               @RequestHeader("Idempotency-Key") String idempotencyKey,
                                               @Valid @RequestBody SharePlanEvent req) {
        requireIdempotencyKey(idempotencyKey);
        return teamPlanService.recordEvent(SecurityUtils.currentUserId(), versionId,
                req.eventType(), req.workoutId(), req.eventDate());
    }

    private void requireIdempotencyKey(String idempotencyKey) {
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            throw AppException.badRequest("缺少 Idempotency-Key");
        }
    }
}
