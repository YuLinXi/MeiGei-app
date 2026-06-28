package com.dontlift.team;

import com.dontlift.common.web.AppException;
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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TeamPlanServiceTest {

    @Mock WorkoutPlanMapper planMapper;
    @Mock WorkoutMapper workoutMapper;
    @Mock TeamPlanShareMapper shareMapper;
    @Mock TeamPlanShareVersionMapper versionMapper;
    @Mock TeamPlanShareEventMapper eventMapper;
    @Mock TeamService teamService;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private TeamPlanService service;

    @BeforeEach
    void setUp() {
        service = new TeamPlanService(planMapper, workoutMapper, shareMapper, versionMapper,
                eventMapper, teamService, objectMapper);
    }

    @Test
    void shareToTeam_createsWeightlessImmutableVersion() throws Exception {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();
        WorkoutPlan source = sourcePlan(userId, planId, teamId);
        source.setMode("strict");
        when(planMapper.selectById(planId)).thenReturn(source);
        when(versionMapper.nextVersionNumber(any())).thenReturn(1);

        service.shareToTeam(userId, teamId, planId);

        ArgumentCaptor<TeamPlanShareVersion> versionCaptor = ArgumentCaptor.forClass(TeamPlanShareVersion.class);
        verify(versionMapper).insert(versionCaptor.capture());
        TeamPlanShareVersion version = versionCaptor.getValue();
        JsonNode item = objectMapper.readTree(version.getItems()).get(0);
        assertThat(version.getVersionNumber()).isEqualTo(1);
        assertThat(version.getMode()).isEqualTo("adaptive");
        assertThat(item.has("suggestedWeightKg")).isFalse();
        assertThat(item.get("exerciseName").asText()).isEqualTo("新版动作");
        assertThat(item.get("primaryMuscle").asText()).isEqualTo("胸");
    }

    @Test
    void shareToTeam_afterPlanEditAppendsVersionAndUpdatesLatestPointer() {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();
        UUID shareId = UUID.randomUUID();
        WorkoutPlan source = sourcePlan(userId, planId, teamId);
        source.setName("胸背新版");
        TeamPlanShare share = share(shareId, teamId, userId, planId);
        when(planMapper.selectById(planId)).thenReturn(source);
        when(shareMapper.findByTeamOwnerSourceForUpdate(teamId, userId, planId)).thenReturn(share);
        when(versionMapper.nextVersionNumber(shareId)).thenReturn(2);

        service.shareToTeam(userId, teamId, planId);

        ArgumentCaptor<TeamPlanShareVersion> versionCaptor = ArgumentCaptor.forClass(TeamPlanShareVersion.class);
        verify(versionMapper).insert(versionCaptor.capture());
        TeamPlanShareVersion version = versionCaptor.getValue();
        assertThat(version.getVersionNumber()).isEqualTo(2);
        assertThat(version.getPlanNameSnapshot()).isEqualTo("胸背新版");
        verify(shareMapper).updateLatestVersion(eq(shareId), eq("胸背新版"), eq(version.getId()), any(OffsetDateTime.class));
    }

    @Test
    void shareToTeam_usesClientSnapshotWhenProvided() throws Exception {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();
        when(versionMapper.nextVersionNumber(any())).thenReturn(1);
        SharePlan req = new SharePlan(planId, "客户端新版", """
                [{
                  "itemId":"%s",
                  "exerciseName":"客户端动作",
                  "orderIndex":0,
                  "suggestedSets":3,
                  "suggestedReps":12,
                  "suggestedWeightKg":90
                }]
                """.formatted(UUID.randomUUID()));

        service.shareToTeam(userId, teamId, req);

        ArgumentCaptor<TeamPlanShareVersion> versionCaptor = ArgumentCaptor.forClass(TeamPlanShareVersion.class);
        verify(versionMapper).insert(versionCaptor.capture());
        TeamPlanShareVersion version = versionCaptor.getValue();
        JsonNode item = objectMapper.readTree(version.getItems()).get(0);
        assertThat(version.getPlanNameSnapshot()).isEqualTo("客户端新版");
        assertThat(item.get("exerciseName").asText()).isEqualTo("客户端动作");
        assertThat(item.has("suggestedWeightKg")).isFalse();
    }

    @Test
    void shareToTeam_rejectsMalformedPlanItemsInsteadOfLeakingRawJson() {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();
        WorkoutPlan source = sourcePlan(userId, planId, teamId);
        source.setItems("[{\"exerciseName\":\"坏数据\",\"suggestedWeightKg\":80");
        when(planMapper.selectById(planId)).thenReturn(source);
        when(versionMapper.nextVersionNumber(any())).thenReturn(1);

        assertThatThrownBy(() -> service.shareToTeam(userId, teamId, planId))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("计划数据异常");
    }

    @Test
    void deleteShare_allowsOwnerOnly() {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID shareId = UUID.randomUUID();
        TeamPlanShare share = share(shareId, teamId, userId, UUID.randomUUID());
        when(shareMapper.selectById(shareId)).thenReturn(share);
        when(shareMapper.softDelete(eq(shareId), eq(userId), any(OffsetDateTime.class))).thenReturn(1);

        service.deleteShare(userId, teamId, shareId);

        verify(teamService).requireMember(teamId, userId);
        verify(shareMapper).softDelete(eq(shareId), eq(userId), any(OffsetDateTime.class));
    }

    @Test
    void deleteShare_rejectsOtherMembersShare() {
        UUID ownerId = UUID.randomUUID();
        UUID otherUserId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID shareId = UUID.randomUUID();
        TeamPlanShare share = share(shareId, teamId, ownerId, UUID.randomUUID());
        when(shareMapper.selectById(shareId)).thenReturn(share);

        assertThatThrownBy(() -> service.deleteShare(otherUserId, teamId, shareId))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("只能取消自己分享的计划");
        verify(shareMapper, never()).softDelete(any(), any(), any());
    }

    @Test
    void forkVersion_createsPrivatePlanAndRecordsForkEvent() throws Exception {
        UUID userId = UUID.randomUUID();
        UUID ownerId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID shareId = UUID.randomUUID();
        UUID versionId = UUID.randomUUID();
        UUID sourcePlanId = UUID.randomUUID();
        TeamPlanShare share = share(shareId, teamId, ownerId, sourcePlanId);
        TeamPlanShareVersion version = version(versionId, shareId);
        when(versionMapper.selectById(versionId)).thenReturn(version);
        when(shareMapper.selectById(shareId)).thenReturn(share);
        when(planMapper.nextUngroupedSortOrder(userId)).thenReturn(3);

        service.forkVersion(userId, versionId);

        ArgumentCaptor<WorkoutPlan> planCaptor = ArgumentCaptor.forClass(WorkoutPlan.class);
        verify(planMapper).insert(planCaptor.capture());
        WorkoutPlan copy = planCaptor.getValue();
        JsonNode item = objectMapper.readTree(copy.getItems()).get(0);
        assertThat(copy.getUserId()).isEqualTo(userId);
        assertThat(copy.getForkedFrom()).isEqualTo(sourcePlanId);
        assertThat(copy.getSharedToTeamId()).isNull();
        assertThat(copy.getGroupId()).isNull();
        assertThat(copy.getMode()).isEqualTo("adaptive");
        assertThat(copy.getSortOrder()).isEqualTo(3);
        assertThat(item.has("suggestedWeightKg")).isFalse();

        ArgumentCaptor<TeamPlanShareEvent> eventCaptor = ArgumentCaptor.forClass(TeamPlanShareEvent.class);
        verify(eventMapper).insertIgnoreDuplicate(eventCaptor.capture());
        assertThat(eventCaptor.getValue().getEventType()).isEqualTo("fork");
        assertThat(eventCaptor.getValue().getShareId()).isEqualTo(shareId);
    }

    @Test
    void recordCompleteEvent_validatesWorkoutAndStoresMinimalEvent() {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID shareId = UUID.randomUUID();
        UUID versionId = UUID.randomUUID();
        UUID workoutId = UUID.randomUUID();
        when(versionMapper.selectById(versionId)).thenReturn(version(versionId, shareId));
        when(shareMapper.selectById(shareId)).thenReturn(share(shareId, teamId, UUID.randomUUID(), UUID.randomUUID()));
        Workout workout = new Workout();
        workout.setId(workoutId);
        workout.setUserId(userId);
        when(workoutMapper.findByIdIncludingDeleted(workoutId)).thenReturn(workout);

        service.recordEvent(userId, versionId, "complete", workoutId, LocalDate.of(2026, 6, 28));

        ArgumentCaptor<TeamPlanShareEvent> eventCaptor = ArgumentCaptor.forClass(TeamPlanShareEvent.class);
        verify(eventMapper).insertIgnoreDuplicate(eventCaptor.capture());
        TeamPlanShareEvent event = eventCaptor.getValue();
        assertThat(event.getEventType()).isEqualTo("complete");
        assertThat(event.getWorkoutId()).isEqualTo(workoutId);
        assertThat(event.getEventDate()).isEqualTo(LocalDate.of(2026, 6, 28));
    }

    @Test
    void recordCompleteEvent_allowsUnsyncedWorkoutSoftReference() {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID shareId = UUID.randomUUID();
        UUID versionId = UUID.randomUUID();
        UUID workoutId = UUID.randomUUID();
        when(versionMapper.selectById(versionId)).thenReturn(version(versionId, shareId));
        when(shareMapper.selectById(shareId)).thenReturn(share(shareId, teamId, UUID.randomUUID(), UUID.randomUUID()));
        when(workoutMapper.findByIdIncludingDeleted(workoutId)).thenReturn(null);

        service.recordEvent(userId, versionId, "complete", workoutId, LocalDate.of(2026, 6, 28));

        ArgumentCaptor<TeamPlanShareEvent> eventCaptor = ArgumentCaptor.forClass(TeamPlanShareEvent.class);
        verify(eventMapper).insertIgnoreDuplicate(eventCaptor.capture());
        assertThat(eventCaptor.getValue().getWorkoutId()).isEqualTo(workoutId);
        assertThat(eventCaptor.getValue().getEventType()).isEqualTo("complete");
    }

    @Test
    void recordDirectStartEvent_allowsUnsyncedWorkoutSoftReference() {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID shareId = UUID.randomUUID();
        UUID versionId = UUID.randomUUID();
        UUID workoutId = UUID.randomUUID();
        when(versionMapper.selectById(versionId)).thenReturn(version(versionId, shareId));
        when(shareMapper.selectById(shareId)).thenReturn(share(shareId, teamId, UUID.randomUUID(), UUID.randomUUID()));
        when(workoutMapper.findByIdIncludingDeleted(workoutId)).thenReturn(null);

        service.recordEvent(userId, versionId, "direct_start", workoutId, LocalDate.of(2026, 6, 28));

        ArgumentCaptor<TeamPlanShareEvent> eventCaptor = ArgumentCaptor.forClass(TeamPlanShareEvent.class);
        verify(eventMapper).insertIgnoreDuplicate(eventCaptor.capture());
        assertThat(eventCaptor.getValue().getWorkoutId()).isEqualTo(workoutId);
        assertThat(eventCaptor.getValue().getEventType()).isEqualTo("direct_start");
    }


    @Test
    void shareToTeam_rejectsNonMember() {
        UUID userId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();
        when(planMapper.selectById(planId)).thenReturn(sourcePlan(userId, planId, teamId));
        when(teamService.requireMember(teamId, userId)).thenThrow(AppException.forbidden("非该 Team 成员"));

        assertThatThrownBy(() -> service.shareToTeam(userId, teamId, planId))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("非该 Team 成员");
    }

    private WorkoutPlan sourcePlan(UUID userId, UUID planId, UUID teamId) {
        WorkoutPlan source = new WorkoutPlan();
        source.setId(planId);
        source.setUserId(userId);
        source.setName("胸背");
        source.setMode("adaptive");
        source.setSharedToTeamId(teamId);
        source.setItems("""
                [{
                  "itemId":"%s",
                  "builtinExerciseCode":"FUTURE_BUILTIN",
                  "exerciseName":"新版动作",
                  "primaryMuscle":"胸",
                  "equipmentType":"哑铃",
                  "orderIndex":0,
                  "suggestedSets":4,
                  "suggestedReps":8,
                  "suggestedWeightKg":80
                }]
                """.formatted(UUID.randomUUID()));
        return source;
    }

    private TeamPlanShare share(UUID shareId, UUID teamId, UUID ownerId, UUID sourcePlanId) {
        TeamPlanShare share = new TeamPlanShare();
        share.setId(shareId);
        share.setTeamId(teamId);
        share.setOwnerUserId(ownerId);
        share.setSourcePlanId(sourcePlanId);
        share.setTitle("胸背");
        return share;
    }

    private TeamPlanShareVersion version(UUID versionId, UUID shareId) {
        TeamPlanShareVersion version = new TeamPlanShareVersion();
        version.setId(versionId);
        version.setShareId(shareId);
        version.setVersionNumber(2);
        version.setPlanNameSnapshot("胸背");
        version.setMode("strict");
        version.setItems("""
                [{
                  "itemId":"%s",
                  "exerciseName":"新版动作",
                  "orderIndex":0,
                  "suggestedSets":4,
                  "suggestedReps":8
                }]
                """.formatted(UUID.randomUUID()));
        return version;
    }
}
