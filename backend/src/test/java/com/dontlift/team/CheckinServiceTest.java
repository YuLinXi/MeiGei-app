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
import java.time.OffsetDateTime;
import java.time.YearMonth;
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

    @Test
    void listCheckinHistory_requiresMemberAndReturnsMonthlyFeed() {
        TeamCheckin newer = checkin(UUID.randomUUID(), LocalDate.parse("2026-06-24"), "2026-06-24T12:00:00Z");
        TeamCheckin older = checkin(UUID.randomUUID(), LocalDate.parse("2026-06-01"), "2026-06-01T12:00:00Z");
        when(checkinMapper.findByTeamAndDateRange(
                teamId, LocalDate.parse("2026-06-01"), LocalDate.parse("2026-07-01")))
                .thenReturn(List.of(newer, older));
        when(reactionMapper.findByCheckins(List.of(newer.getId(), older.getId()))).thenReturn(List.of());

        var feed = service.listCheckinHistory(userId, teamId, YearMonth.parse("2026-06"));

        assertThat(feed.checkins()).containsExactly(newer, older);
        assertThat(feed.reactions()).isEmpty();
        verify(teamService).requireMember(teamId, userId);
        verify(checkinMapper).findByTeamAndDateRange(
                teamId, LocalDate.parse("2026-06-01"), LocalDate.parse("2026-07-01"));
    }

    @Test
    void listCheckinHistory_rejectsNonMemberBeforeQueryingCheckins() {
        when(teamService.requireMember(teamId, userId)).thenThrow(AppException.forbidden("非该 Team 成员"));

        assertThatThrownBy(() -> service.listCheckinHistory(userId, teamId, YearMonth.parse("2026-06")))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("非该 Team 成员");

        verify(checkinMapper, never()).findByTeamAndDateRange(any(), any(), any());
        verify(reactionMapper, never()).findByCheckins(any());
    }

    @Test
    void listCheckinHistory_returnsEmptyFeedWithoutReactionQuery() {
        when(checkinMapper.findByTeamAndDateRange(
                teamId, LocalDate.parse("2026-06-01"), LocalDate.parse("2026-07-01")))
                .thenReturn(List.of());

        var feed = service.listCheckinHistory(userId, teamId, YearMonth.parse("2026-06"));

        assertThat(feed.checkins()).isEmpty();
        assertThat(feed.reactions()).isEmpty();
        verify(reactionMapper, never()).findByCheckins(any());
    }

    private void givenShareableWorkout() {
        Workout workout = new Workout();
        workout.setId(workoutId);
        workout.setUserId(userId);
        when(workoutMapper.findByIdIncludingDeleted(workoutId)).thenReturn(workout);
    }

    private TeamCheckin checkin(UUID id, LocalDate date, String createdAt) {
        TeamCheckin checkin = new TeamCheckin();
        checkin.setId(id);
        checkin.setTeamId(teamId);
        checkin.setUserId(userId);
        checkin.setWorkoutId(UUID.randomUUID());
        checkin.setCheckinDate(date);
        checkin.setSummary("{}");
        checkin.setCreatedAt(OffsetDateTime.parse(createdAt));
        return checkin;
    }
}
