package com.dontlift.team;

import com.dontlift.common.web.AppException;
import com.dontlift.push.PushService;
import com.dontlift.team.entity.TeamCheckin;
import com.dontlift.team.mapper.CheckinReactionMapper;
import com.dontlift.team.mapper.TeamCheckinMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.mapper.WorkoutMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CheckinServiceTest {

    @Mock TeamMemberMapper memberMapper;
    @Mock TeamCheckinMapper checkinMapper;
    @Mock CheckinReactionMapper reactionMapper;
    @Mock TeamService teamService;
    @Mock PushService pushService;
    @Mock WorkoutMapper workoutMapper;

    @InjectMocks CheckinService service;

    private final UUID userId = UUID.randomUUID();
    private final UUID teamId = UUID.randomUUID();
    private final UUID workoutId = UUID.randomUUID();
    private final LocalDate today = LocalDate.parse("2026-06-24");

    @Test
    void checkIn_rejectsMissingTeamIds() {
        assertThatThrownBy(() -> service.checkIn(userId, workoutId, today, "{}", List.of()))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("请选择");

        verify(checkinMapper, never()).insert(any(TeamCheckin.class));
    }

    @Test
    void checkIn_createsOnlySelectedTeam() {
        givenShareableWorkout();

        List<TeamCheckin> result = service.checkIn(userId, workoutId, today, "{\"exerciseCount\":1}", List.of(teamId));

        assertThat(result).hasSize(1);
        TeamCheckin created = result.get(0);
        assertThat(created.getTeamId()).isEqualTo(teamId);
        assertThat(created.getUserId()).isEqualTo(userId);
        assertThat(created.getWorkoutId()).isEqualTo(workoutId);
        verify(teamService).requireMember(teamId, userId);
        verify(checkinMapper).insert(created);
    }

    @Test
    void checkIn_updatesExistingCheckinAndReturnsIt() {
        givenShareableWorkout();
        TeamCheckin existing = new TeamCheckin();
        existing.setId(UUID.randomUUID());
        existing.setTeamId(teamId);
        existing.setUserId(userId);
        existing.setWorkoutId(workoutId);
        existing.setSummary("{}");
        when(checkinMapper.findByTeamUserWorkout(teamId, userId, workoutId)).thenReturn(existing);

        List<TeamCheckin> result = service.checkIn(userId, workoutId, today, "{\"totalSets\":2}", List.of(teamId));

        assertThat(result).containsExactly(existing);
        assertThat(existing.getSummary()).isEqualTo("{\"totalSets\":2}");
        verify(checkinMapper).updateById(existing);
        verify(checkinMapper, never()).insert(any(TeamCheckin.class));
    }

    @Test
    void checkIn_propagatesForbiddenForNonMember() {
        givenShareableWorkout();
        when(teamService.requireMember(teamId, userId)).thenThrow(AppException.forbidden("非该 Team 成员"));

        assertThatThrownBy(() -> service.checkIn(userId, workoutId, today, "{}", List.of(teamId)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("非该 Team 成员");

        verify(checkinMapper, never()).insert(any(TeamCheckin.class));
    }

    @Test
    void checkIn_rejectsUnsyncedWorkout() {
        when(workoutMapper.findByIdIncludingDeleted(workoutId)).thenReturn(null);

        assertThatThrownBy(() -> service.checkIn(userId, workoutId, today, "{}", List.of(teamId)))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("训练尚未同步");

        verify(teamService, never()).requireMember(teamId, userId);
        verify(checkinMapper, never()).insert(any(TeamCheckin.class));
    }

    @Test
    void withdraw_deletesOnlySelectedTeamCheckin() {
        service.withdraw(userId, teamId, workoutId);

        verify(teamService).requireMember(teamId, userId);
        verify(checkinMapper).deleteByTeamUserWorkout(teamId, userId, workoutId);
    }

    private void givenShareableWorkout() {
        Workout workout = new Workout();
        workout.setId(workoutId);
        workout.setUserId(userId);
        when(workoutMapper.findByIdIncludingDeleted(workoutId)).thenReturn(workout);
    }
}
