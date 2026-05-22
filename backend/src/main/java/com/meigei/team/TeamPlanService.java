package com.meigei.team;

import com.meigei.common.id.Uuid7;
import com.meigei.common.web.AppException;
import com.meigei.workout.entity.WorkoutPlan;
import com.meigei.workout.mapper.WorkoutPlanMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/** 计划模板发布到 Team 与 Fork（5.3）。 */
@Service
public class TeamPlanService {

    private final WorkoutPlanMapper planMapper;
    private final TeamService teamService;

    public TeamPlanService(WorkoutPlanMapper planMapper, TeamService teamService) {
        this.planMapper = planMapper;
        this.teamService = teamService;
    }

    /** 把自己的模板发布到所在 Team（全员可见）。 */
    @Transactional
    public WorkoutPlan publishToTeam(UUID userId, UUID planId, UUID teamId) {
        WorkoutPlan plan = ownPlanOrThrow(userId, planId);
        teamService.requireMember(teamId, userId);
        plan.setSharedToTeamId(teamId);
        planMapper.updateById(plan);
        return plan;
    }

    public List<WorkoutPlan> listTeamPlans(UUID userId, UUID teamId) {
        teamService.requireMember(teamId, userId);
        return planMapper.findSharedToTeam(teamId);
    }

    /** Fork：复制 jsonb items 为本人新模板，forkedFrom 记软指针，原模板增删不影响副本。 */
    @Transactional
    public WorkoutPlan fork(UUID userId, UUID planId) {
        WorkoutPlan src = planMapper.selectById(planId);
        if (src == null) {
            throw AppException.notFound("模板不存在");
        }
        UUID teamId = src.getSharedToTeamId();
        if (teamId == null) {
            throw AppException.forbidden("该模板未发布到 Team，无法 Fork");
        }
        teamService.requireMember(teamId, userId); // 必须是发布所在 Team 的成员

        WorkoutPlan copy = new WorkoutPlan();
        copy.setId(Uuid7.generate());
        copy.setUserId(userId);
        copy.setName(src.getName());
        copy.setItems(src.getItems()); // 复制 jsonb 快照
        copy.setForkedFrom(src.getId());
        copy.setSharedToTeamId(null); // 副本默认私有
        planMapper.insert(copy);
        return copy;
    }

    private WorkoutPlan ownPlanOrThrow(UUID userId, UUID planId) {
        WorkoutPlan plan = planMapper.selectById(planId);
        if (plan == null) {
            throw AppException.notFound("模板不存在");
        }
        if (!plan.getUserId().equals(userId)) {
            throw AppException.forbidden("只能发布自己的模板");
        }
        return plan;
    }
}
