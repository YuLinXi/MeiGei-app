package com.dontlift.team;

import com.dontlift.common.id.Uuid7;
import com.dontlift.common.web.AppException;
import com.dontlift.team.dto.TeamPlanShareCard;
import com.dontlift.team.dto.TeamRequests.SharePlan;
import com.dontlift.team.entity.TeamPlanShare;
import com.dontlift.team.entity.TeamPlanShareEvent;
import com.dontlift.team.entity.TeamPlanShareVersion;
import com.dontlift.team.mapper.TeamPlanShareEventMapper;
import com.dontlift.team.mapper.TeamPlanShareMapper;
import com.dontlift.team.mapper.TeamPlanShareVersionMapper;
import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.entity.WorkoutPlan;
import com.dontlift.workout.mapper.WorkoutMapper;
import com.dontlift.workout.mapper.WorkoutPlanMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/** Team 计划分享、版本快照、Fork 与反馈统计。 */
@Service
public class TeamPlanService {

    private static final Set<String> EVENT_TYPES = Set.of("fork", "direct_start", "complete");

    private final WorkoutPlanMapper planMapper;
    private final WorkoutMapper workoutMapper;
    private final TeamPlanShareMapper shareMapper;
    private final TeamPlanShareVersionMapper versionMapper;
    private final TeamPlanShareEventMapper eventMapper;
    private final TeamService teamService;
    private final ObjectMapper objectMapper;

    public TeamPlanService(WorkoutPlanMapper planMapper,
                           WorkoutMapper workoutMapper,
                           TeamPlanShareMapper shareMapper,
                           TeamPlanShareVersionMapper versionMapper,
                           TeamPlanShareEventMapper eventMapper,
                           TeamService teamService,
                           ObjectMapper objectMapper) {
        this.planMapper = planMapper;
        this.workoutMapper = workoutMapper;
        this.shareMapper = shareMapper;
        this.versionMapper = versionMapper;
        this.eventMapper = eventMapper;
        this.teamService = teamService;
        this.objectMapper = objectMapper;
    }

    /** 兼容旧接口：把“发布”映射为创建 Team 分享版本，不再让原计划持续联动。 */
    @Transactional
    public WorkoutPlan publishToTeam(UUID userId, UUID planId, UUID teamId) {
        shareToTeam(userId, teamId, planId);
        return ownPlanOrThrow(userId, planId);
    }

    /** 创建或追加 Team 分享计划版本。 */
    @Transactional
    public TeamPlanShareVersion shareToTeam(UUID userId, UUID teamId, UUID planId) {
        return shareToTeam(userId, teamId, planId, null, null);
    }

    /** 创建或追加 Team 分享计划版本；新版客户端可直接携带当前无重量快照，避免弱网下固化旧同步版本。 */
    @Transactional
    public TeamPlanShareVersion shareToTeam(UUID userId, UUID teamId, SharePlan req) {
        return shareToTeam(userId, teamId, req.sourcePlanId(), req.planNameSnapshot(), req.items());
    }

    private TeamPlanShareVersion shareToTeam(UUID userId, UUID teamId, UUID planId,
                                             String planNameSnapshot, String snapshotItems) {
        WorkoutPlan plan = planMapper.selectById(planId);
        boolean hasSnapshot = hasText(planNameSnapshot) && hasText(snapshotItems);
        if (plan != null && !plan.getUserId().equals(userId)) {
            throw AppException.forbidden("只能分享自己的模板");
        }
        if (!hasSnapshot && plan == null) {
            throw AppException.notFound("模板不存在");
        }
        teamService.requireMember(teamId, userId);
        String planName = hasSnapshot ? planNameSnapshot.trim() : plan.getName();
        String itemsJson = hasSnapshot ? snapshotItems : plan.getItems();

        TeamPlanShare share = shareMapper.findByTeamOwnerSourceForUpdate(teamId, userId, planId);
        OffsetDateTime now = OffsetDateTime.now();
        if (share == null) {
            share = new TeamPlanShare();
            share.setId(Uuid7.generate());
            share.setTeamId(teamId);
            share.setOwnerUserId(userId);
            share.setSourcePlanId(planId);
            share.setTitle(planName);
            try {
                shareMapper.insert(share);
            } catch (DuplicateKeyException e) {
                share = shareMapper.findByTeamOwnerSourceForUpdate(teamId, userId, planId);
                if (share == null) {
                    throw e;
                }
            }
        }

        TeamPlanShareVersion version = new TeamPlanShareVersion();
        version.setId(Uuid7.generate());
        version.setShareId(share.getId());
        version.setVersionNumber(versionMapper.nextVersionNumber(share.getId()));
        version.setPlanNameSnapshot(planName);
        version.setMode("adaptive");
        version.setItems(stripWeights(itemsJson));
        version.setCreatedAt(now);
        versionMapper.insert(version);

        shareMapper.updateLatestVersion(share.getId(), planName, version.getId(), now);
        return version;
    }

    /** 兼容旧接口：返回最新分享版本伪装成 ServerPlanDTO 可解码的 WorkoutPlan。 */
    public List<WorkoutPlan> listTeamPlans(UUID userId, UUID teamId) {
        return listShareCards(userId, teamId).stream()
                .map(this::legacyPlanFromCard)
                .toList();
    }

    public List<TeamPlanShareCard> listShareCards(UUID userId, UUID teamId) {
        teamService.requireMember(teamId, userId);
        return shareMapper.findCardsByTeam(teamId);
    }

    /** 取消自己分享到 Team 的计划；只移除分享线索，不影响已 Fork 的个人计划。 */
    @Transactional
    public void deleteShare(UUID userId, UUID teamId, UUID shareId) {
        TeamPlanShare share = shareOrThrow(shareId);
        if (!teamId.equals(share.getTeamId())) {
            throw AppException.notFound("分享计划不存在");
        }
        teamService.requireMember(teamId, userId);
        if (!userId.equals(share.getOwnerUserId())) {
            throw AppException.forbidden("只能取消自己分享的计划");
        }
        int deleted = shareMapper.softDelete(shareId, userId, OffsetDateTime.now());
        if (deleted == 0) {
            throw AppException.notFound("分享计划不存在");
        }
    }

    /** 兼容旧接口：既支持旧 WorkoutPlan.id，也支持新 shareVersion.id。 */
    @Transactional
    public WorkoutPlan fork(UUID userId, UUID planId) {
        WorkoutPlan src = planMapper.selectById(planId);
        if (src != null) {
            UUID teamId = src.getSharedToTeamId();
            if (teamId == null) {
                throw AppException.forbidden("该模板未分享到 Team，无法 Fork");
            }
            TeamPlanShare share = shareMapper.findByTeamOwnerSource(teamId, src.getUserId(), src.getId());
            TeamPlanShareVersion version;
            if (share == null) {
                version = shareToTeam(src.getUserId(), teamId, src.getId());
            } else {
                version = versionMapper.findLatestByShare(share.getId());
            }
            return forkVersion(userId, version.getId());
        }

        return forkVersion(userId, planId);
    }

    /** Fork 分享版本为当前用户的独立私有计划。 */
    @Transactional
    public WorkoutPlan forkVersion(UUID userId, UUID versionId) {
        TeamPlanShareVersion version = versionOrThrow(versionId);
        TeamPlanShare share = shareOrThrow(version.getShareId());
        teamService.requireMember(share.getTeamId(), userId);

        WorkoutPlan copy = new WorkoutPlan();
        copy.setId(Uuid7.generate());
        copy.setUserId(userId);
        copy.setName(version.getPlanNameSnapshot());
        copy.setItems(stripWeights(version.getItems()));
        copy.setMode("adaptive");
        copy.setForkedFrom(share.getSourcePlanId());
        copy.setForkedFromShareVersionId(versionId);
        copy.setSharedToTeamId(null); // 副本默认私有
        copy.setGroupId(null); // 不复制发布者的个人分组结构
        copy.setSortOrder(planMapper.nextUngroupedSortOrder(userId));
        planMapper.insert(copy);
        recordEvent(userId, versionId, "fork", null, LocalDate.now());
        return copy;
    }

    @Transactional
    public TeamPlanShareEvent recordEvent(UUID userId, UUID versionId, String eventType,
                                          UUID workoutId, LocalDate eventDate) {
        if (!EVENT_TYPES.contains(eventType)) {
            throw AppException.badRequest("不支持的计划反馈事件：" + eventType);
        }
        TeamPlanShareVersion version = versionOrThrow(versionId);
        TeamPlanShare share = shareOrThrow(version.getShareId());
        teamService.requireMember(share.getTeamId(), userId);
        if (workoutId != null) {
            if ("complete".equals(eventType)) {
                requireOwnWorkoutIfPresent(userId, workoutId);
            } else if ("direct_start".equals(eventType)) {
                requireOwnWorkoutIfPresent(userId, workoutId);
            } else {
                requireOwnWorkout(userId, workoutId);
            }
        }

        TeamPlanShareEvent event = new TeamPlanShareEvent();
        event.setId(Uuid7.generate());
        event.setTeamId(share.getTeamId());
        event.setShareId(share.getId());
        event.setVersionId(versionId);
        event.setUserId(userId);
        event.setEventType(eventType);
        event.setWorkoutId(workoutId);
        event.setEventDate(eventDate != null ? eventDate : LocalDate.now());
        event.setCreatedAt(OffsetDateTime.now());
        eventMapper.insertIgnoreDuplicate(event);
        return event;
    }

    /** 把 items jsonb 里的重量字段递归移除；解析失败时拒绝分享，避免隐私字段原样流出。 */
    private String stripWeights(String itemsJson) {
        if (itemsJson == null || itemsJson.isBlank()) {
            return "[]";
        }
        try {
            JsonNode root = objectMapper.readTree(itemsJson);
            if (root.isArray()) {
                stripWeightFields(root);
                return objectMapper.writeValueAsString(root);
            }
            return "[]";
        } catch (Exception e) {
            throw AppException.badRequest("计划数据异常，无法分享到 Team");
        }
    }

    private void stripWeightFields(JsonNode node) {
        if (node == null) {
            return;
        }
        if (node.isArray()) {
            for (JsonNode child : node) {
                stripWeightFields(child);
            }
            return;
        }
        if (node instanceof ObjectNode obj) {
            obj.remove(List.of("suggestedWeightKg", "suggestedWeight", "weightKg", "weight"));
            obj.fields().forEachRemaining(entry -> stripWeightFields(entry.getValue()));
        }
    }

    private WorkoutPlan ownPlanOrThrow(UUID userId, UUID planId) {
        WorkoutPlan plan = planMapper.selectById(planId);
        if (plan == null) {
            throw AppException.notFound("模板不存在");
        }
        if (!plan.getUserId().equals(userId)) {
            throw AppException.forbidden("只能分享自己的模板");
        }
        return plan;
    }

    private TeamPlanShareVersion versionOrThrow(UUID versionId) {
        TeamPlanShareVersion version = versionMapper.selectById(versionId);
        if (version == null) {
            throw AppException.notFound("分享计划版本不存在");
        }
        return version;
    }

    private TeamPlanShare shareOrThrow(UUID shareId) {
        TeamPlanShare share = shareMapper.selectById(shareId);
        if (share == null) {
            throw AppException.notFound("分享计划不存在");
        }
        return share;
    }

    private void requireOwnWorkout(UUID userId, UUID workoutId) {
        Workout workout = workoutMapper.findByIdIncludingDeleted(workoutId);
        if (workout == null || !userId.equals(workout.getUserId()) || workout.getDeletedAt() != null) {
            throw AppException.notFound("训练尚未同步或已删除，暂不能记录计划反馈");
        }
    }

    private void requireOwnWorkoutIfPresent(UUID userId, UUID workoutId) {
        Workout workout = workoutMapper.findByIdIncludingDeleted(workoutId);
        if (workout == null) {
            return;
        }
        if (!userId.equals(workout.getUserId()) || workout.getDeletedAt() != null) {
            throw AppException.notFound("训练尚未同步或已删除，暂不能记录计划反馈");
        }
    }

    private WorkoutPlan legacyPlanFromCard(TeamPlanShareCard card) {
        WorkoutPlan plan = new WorkoutPlan();
        plan.setId(card.getVersionId());
        plan.setUserId(card.getOwnerUserId());
        plan.setName(card.getPlanNameSnapshot());
        plan.setItems(card.getItems());
        plan.setMode(normalizedMode(card.getMode()));
        plan.setForkedFrom(card.getSourcePlanId());
        plan.setSharedToTeamId(card.getTeamId());
        plan.setCreatedAt(card.getCreatedAt());
        plan.setUpdatedAt(card.getCreatedAt());
        plan.setVersion(card.getVersionNumber());
        return plan;
    }

    private String normalizedMode(String mode) {
        return "strict".equals(mode) ? "strict" : "adaptive";
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

}
