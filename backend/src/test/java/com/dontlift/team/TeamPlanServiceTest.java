package com.dontlift.team;

import com.dontlift.workout.entity.WorkoutPlan;
import com.dontlift.workout.mapper.WorkoutPlanMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TeamPlanServiceTest {

    @Mock WorkoutPlanMapper planMapper;
    @Mock TeamService teamService;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private TeamPlanService service;

    @BeforeEach
    void setUp() {
        service = new TeamPlanService(planMapper, teamService, objectMapper);
    }

    @Test
    void fork_preservesExerciseSnapshotFieldsWhenStrippingWeights() throws Exception {
        UUID userId = UUID.randomUUID();
        UUID planId = UUID.randomUUID();
        UUID teamId = UUID.randomUUID();
        WorkoutPlan source = new WorkoutPlan();
        source.setId(planId);
        source.setUserId(UUID.randomUUID());
        source.setName("胸背");
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
        when(planMapper.selectById(planId)).thenReturn(source);
        when(planMapper.nextUngroupedSortOrder(userId)).thenReturn(0);

        service.fork(userId, planId);

        ArgumentCaptor<WorkoutPlan> captor = ArgumentCaptor.forClass(WorkoutPlan.class);
        verify(planMapper).insert(captor.capture());
        JsonNode item = objectMapper.readTree(captor.getValue().getItems()).get(0);
        assertThat(item.get("exerciseName").asText()).isEqualTo("新版动作");
        assertThat(item.get("primaryMuscle").asText()).isEqualTo("胸");
        assertThat(item.get("equipmentType").asText()).isEqualTo("哑铃");
        assertThat(item.get("suggestedWeightKg").isNull()).isTrue();
    }
}
