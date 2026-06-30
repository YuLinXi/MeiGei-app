package com.dontlift.team;

import com.dontlift.common.web.AppException;
import com.dontlift.push.PushService;
import com.dontlift.team.entity.CheckinReaction;
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
    void react_firstReactionFromTeammateSendsOnePush() {
        UUID ownerId = UUID.randomUUID();
        UUID reactorId = UUID.randomUUID();
        UUID checkinId = UUID.randomUUID();
        TeamCheckin checkin = checkinForReaction(checkinId, ownerId);
        when(checkinMapper.selectById(checkinId)).thenReturn(checkin);
        when(reactionMapper.findByCheckinAndUser(checkinId, reactorId)).thenReturn(null);
        when(reactionMapper.insertReactionIfAbsent(any(CheckinReaction.class))).thenReturn(1);
        when(reactionMapper.insertPushReceiptIfAbsent(
                any(UUID.class), eq(checkinId), eq(reactorId), any(OffsetDateTime.class)))
                .thenReturn(1);

        CheckinReaction result = service.react(reactorId, checkinId, "fire");

        assertThat(result.getCheckinId()).isEqualTo(checkinId);
        assertThat(result.getUserId()).isEqualTo(reactorId);
        assertThat(result.getEmoji()).isEqualTo("fire");
        verify(teamService).requireMember(teamId, reactorId);
        verify(reactionMapper).insertReactionIfAbsent(any(CheckinReaction.class));
        verify(pushService).sendToUser(eq(ownerId), eq("新的表情回应"), eq("有人为你的训练点了表情"), any());
    }

    @Test
    void react_switchingEmojiDoesNotSendDuplicatePushWhenReceiptExists() {
        UUID ownerId = UUID.randomUUID();
        UUID reactorId = UUID.randomUUID();
        UUID checkinId = UUID.randomUUID();
        TeamCheckin checkin = checkinForReaction(checkinId, ownerId);
        CheckinReaction existing = reaction(checkinId, reactorId, "fire");
        when(checkinMapper.selectById(checkinId)).thenReturn(checkin);
        when(reactionMapper.findByCheckinAndUser(checkinId, reactorId)).thenReturn(existing);
        when(reactionMapper.insertPushReceiptIfAbsent(
                any(UUID.class), eq(checkinId), eq(reactorId), any(OffsetDateTime.class)))
                .thenReturn(0);

        CheckinReaction result = service.react(reactorId, checkinId, "muscle");

        assertThat(result).isSameAs(existing);
        assertThat(existing.getEmoji()).isEqualTo("muscle");
        verify(reactionMapper).updateById(existing);
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void react_sameEmojiCancelsWithoutPushReceipt() {
        UUID ownerId = UUID.randomUUID();
        UUID reactorId = UUID.randomUUID();
        UUID checkinId = UUID.randomUUID();
        TeamCheckin checkin = checkinForReaction(checkinId, ownerId);
        CheckinReaction existing = reaction(checkinId, reactorId, "fire");
        when(checkinMapper.selectById(checkinId)).thenReturn(checkin);
        when(reactionMapper.findByCheckinAndUser(checkinId, reactorId)).thenReturn(existing);

        CheckinReaction result = service.react(reactorId, checkinId, "fire");

        assertThat(result).isNull();
        verify(reactionMapper).deleteById(existing.getId());
        verify(reactionMapper, never()).insertPushReceiptIfAbsent(
                any(UUID.class), any(UUID.class), any(UUID.class), any(OffsetDateTime.class));
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void react_relightingAfterCancelDoesNotSendDuplicatePushWhenReceiptExists() {
        UUID ownerId = UUID.randomUUID();
        UUID reactorId = UUID.randomUUID();
        UUID checkinId = UUID.randomUUID();
        TeamCheckin checkin = checkinForReaction(checkinId, ownerId);
        when(checkinMapper.selectById(checkinId)).thenReturn(checkin);
        when(reactionMapper.findByCheckinAndUser(checkinId, reactorId)).thenReturn(null);
        when(reactionMapper.insertReactionIfAbsent(any(CheckinReaction.class))).thenReturn(1);
        when(reactionMapper.insertPushReceiptIfAbsent(
                any(UUID.class), eq(checkinId), eq(reactorId), any(OffsetDateTime.class)))
                .thenReturn(0);

        CheckinReaction result = service.react(reactorId, checkinId, "heart");

        assertThat(result.getEmoji()).isEqualTo("heart");
        verify(reactionMapper).insertReactionIfAbsent(any(CheckinReaction.class));
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void react_selfReactionDoesNotCreatePushReceiptOrPush() {
        UUID ownerId = UUID.randomUUID();
        UUID checkinId = UUID.randomUUID();
        TeamCheckin checkin = checkinForReaction(checkinId, ownerId);
        when(checkinMapper.selectById(checkinId)).thenReturn(checkin);
        when(reactionMapper.findByCheckinAndUser(checkinId, ownerId)).thenReturn(null);
        when(reactionMapper.insertReactionIfAbsent(any(CheckinReaction.class))).thenReturn(1);

        CheckinReaction result = service.react(ownerId, checkinId, "clap");

        assertThat(result.getEmoji()).isEqualTo("clap");
        verify(reactionMapper).insertReactionIfAbsent(any(CheckinReaction.class));
        verify(reactionMapper, never()).insertPushReceiptIfAbsent(
                any(UUID.class), any(UUID.class), any(UUID.class), any(OffsetDateTime.class));
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void react_concurrentSameEmojiInsertReturnsExistingWithoutCancelling() {
        UUID ownerId = UUID.randomUUID();
        UUID reactorId = UUID.randomUUID();
        UUID checkinId = UUID.randomUUID();
        TeamCheckin checkin = checkinForReaction(checkinId, ownerId);
        CheckinReaction concurrent = reaction(checkinId, reactorId, "fire");
        when(checkinMapper.selectById(checkinId)).thenReturn(checkin);
        when(reactionMapper.findByCheckinAndUser(checkinId, reactorId)).thenReturn(null, concurrent);
        when(reactionMapper.insertReactionIfAbsent(any(CheckinReaction.class))).thenReturn(0);
        when(reactionMapper.insertPushReceiptIfAbsent(
                any(UUID.class), eq(checkinId), eq(reactorId), any(OffsetDateTime.class)))
                .thenReturn(0);

        CheckinReaction result = service.react(reactorId, checkinId, "fire");

        assertThat(result).isSameAs(concurrent);
        verify(reactionMapper, never()).deleteById(any(UUID.class));
        verify(reactionMapper, never()).updateById(any(CheckinReaction.class));
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
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

    private TeamCheckin checkinForReaction(UUID id, UUID ownerId) {
        TeamCheckin checkin = new TeamCheckin();
        checkin.setId(id);
        checkin.setTeamId(teamId);
        checkin.setUserId(ownerId);
        checkin.setWorkoutId(UUID.randomUUID());
        checkin.setCheckinDate(today);
        checkin.setSummary("{}");
        checkin.setCreatedAt(OffsetDateTime.parse("2026-06-24T12:00:00Z"));
        return checkin;
    }

    private CheckinReaction reaction(UUID checkinId, UUID reactorId, String emoji) {
        CheckinReaction reaction = new CheckinReaction();
        reaction.setId(UUID.randomUUID());
        reaction.setCheckinId(checkinId);
        reaction.setUserId(reactorId);
        reaction.setEmoji(emoji);
        reaction.setCreatedAt(OffsetDateTime.parse("2026-06-24T12:01:00Z"));
        reaction.setUpdatedAt(OffsetDateTime.parse("2026-06-24T12:01:00Z"));
        return reaction;
    }
}
