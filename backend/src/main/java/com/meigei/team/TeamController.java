package com.meigei.team;

import com.meigei.security.SecurityUtils;
import com.meigei.team.dto.TeamMemberView;
import com.meigei.team.dto.TeamRequests.CreateTeam;
import com.meigei.team.dto.TeamRequests.JoinTeam;
import com.meigei.team.entity.Team;
import com.meigei.workout.entity.WorkoutPlan;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
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

    @GetMapping("/{teamId}/members")
    public List<TeamMemberView> members(@PathVariable UUID teamId) {
        return teamService.getMembers(teamId, SecurityUtils.currentUserId());
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

    @PostMapping("/{teamId}/plans/{planId}")
    public WorkoutPlan publish(@PathVariable UUID teamId, @PathVariable UUID planId) {
        return teamPlanService.publishToTeam(SecurityUtils.currentUserId(), planId, teamId);
    }

    @PostMapping("/plans/{planId}/fork")
    public WorkoutPlan fork(@PathVariable UUID planId) {
        return teamPlanService.fork(SecurityUtils.currentUserId(), planId);
    }
}
