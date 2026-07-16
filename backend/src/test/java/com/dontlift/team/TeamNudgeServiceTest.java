package com.dontlift.team;

import com.dontlift.common.web.AppException;
import com.dontlift.push.PushService;
import com.dontlift.team.dto.TeamMemberView;
import com.dontlift.team.dto.TeamNudgeResponses.TodayState;
import com.dontlift.team.entity.Team;
import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.entity.TeamNudge;
import com.dontlift.team.mapper.TeamCheckinMapper;
import com.dontlift.team.mapper.TeamMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import com.dontlift.team.mapper.TeamNudgeMapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TeamNudgeServiceTest {

    @Mock TeamNudgeMapper nudgeMapper;
    @Mock TeamMemberMapper memberMapper;
    @Mock TeamCheckinMapper checkinMapper;
    @Mock TeamMapper teamMapper;
    @Mock TeamService teamService;
    @Mock PushService pushService;

    @InjectMocks TeamNudgeService service;

    private final UUID teamId = UUID.randomUUID();
    private final UUID senderId = UUID.randomUUID();
    private final UUID recipientId = UUID.randomUUID();

    @Test
    void send_recordsNudgeAndPushesNamedTeamMessage() {
        givenEligibleMembers(true);
        TeamMemberView senderView = new TeamMemberView();
        senderView.setDisplayName("阿岳");
        when(memberMapper.findViewByTeamAndUser(teamId, senderId)).thenReturn(senderView);

        var result = service.send(senderId, teamId, recipientId);

        ArgumentCaptor<TeamNudge> captor = ArgumentCaptor.forClass(TeamNudge.class);
        verify(nudgeMapper).insert(captor.capture());
        TeamNudge created = captor.getValue();
        assertThat(created.getTeamId()).isEqualTo(teamId);
        assertThat(created.getSenderUserId()).isEqualTo(senderId);
        assertThat(created.getRecipientUserId()).isEqualTo(recipientId);
        assertThat(created.getNudgeDate()).isEqualTo(service.today());
        assertThat(result.recipientUserId()).isEqualTo(recipientId);
        verify(pushService).sendToUser(
                eq(recipientId),
                eq("队友拍了拍你"),
                contains("阿岳 在「深蹲小队」喊你一起练练"),
                argThat((Map<String, String> data) -> "team_nudge".equals(data.get("type"))
                        && teamId.toString().equals(data.get("teamId")))
        );
    }

    @Test
    void send_returnsExistingDailyNudgeWithoutAnotherPush() {
        givenEligibleMembers(true);
        TeamNudge existing = nudge(service.today());
        when(nudgeMapper.findDaily(teamId, senderId, recipientId, service.today())).thenReturn(existing);

        var result = service.send(senderId, teamId, recipientId);

        assertThat(result.createdAt()).isEqualTo(existing.getCreatedAt());
        verify(nudgeMapper, never()).insert(any(TeamNudge.class));
        verify(checkinMapper, never()).existsByTeamUserDate(any(), any(), any());
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void send_rejectsSelfNudge() {
        assertThatThrownBy(() -> service.send(senderId, teamId, senderId))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("不能拍自己");

        verify(teamService, never()).requireMember(any(), any());
        verify(nudgeMapper, never()).insert(any(TeamNudge.class));
    }

    @Test
    void send_rejectsRecipientWithTodayCheckin() {
        givenEligibleMembers(true);
        when(checkinMapper.existsByTeamUserDate(teamId, recipientId, service.today())).thenReturn(true);

        assertThatThrownBy(() -> service.send(senderId, teamId, recipientId))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("已有 Team 动态");

        verify(nudgeMapper, never()).insert(any(TeamNudge.class));
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void send_hidesDisabledRecipientPreferenceBehindGenericError() {
        givenEligibleMembers(false);

        assertThatThrownBy(() -> service.send(senderId, teamId, recipientId))
                .isInstanceOf(AppException.class)
                .hasMessage("暂时无法拍一拍该成员");

        verify(nudgeMapper, never()).insert(any(TeamNudge.class));
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void send_rejectsSixthDistinctRecipient() {
        givenEligibleMembers(true);
        when(nudgeMapper.countDistinctRecipients(senderId, service.today()))
                .thenReturn(TeamNudgeService.MAX_DISTINCT_RECIPIENTS_PER_DAY);

        assertThatThrownBy(() -> service.send(senderId, teamId, recipientId))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("次数已用完");

        verify(nudgeMapper, never()).insert(any(TeamNudge.class));
    }

    @Test
    void send_recordsButSuppressesFourthRecipientPush() {
        givenEligibleMembers(true);
        when(nudgeMapper.countForRecipient(recipientId, service.today()))
                .thenReturn(TeamNudgeService.MAX_PUSHES_PER_RECIPIENT_PER_DAY);

        var result = service.send(senderId, teamId, recipientId);

        assertThat(result.recipientUserId()).isEqualTo(recipientId);
        verify(nudgeMapper).insert(any(TeamNudge.class));
        verify(pushService, never()).sendToUser(any(), any(), any(), any());
    }

    @Test
    void todayState_returnsCurrentSendersRecipientsReceivableMembersAndOwnPreference() {
        TeamMember me = member(true);
        UUID receivableId = UUID.randomUUID();
        when(teamService.requireMember(teamId, senderId)).thenReturn(me);
        when(nudgeMapper.findRecipientIds(teamId, senderId, service.today()))
                .thenReturn(List.of(recipientId));
        when(memberMapper.findReceivableNudgeUserIds(teamId, senderId))
                .thenReturn(List.of(recipientId, receivableId));

        var state = service.todayState(senderId, teamId);

        assertThat(state.nudgedRecipientUserIds()).containsExactly(recipientId);
        assertThat(state.receivableRecipientUserIds()).containsExactly(recipientId, receivableId);
        assertThat(state.receiveTeamNotifications()).isTrue();
        assertThat(state.date()).isEqualTo(service.today());
    }

    @Test
    void updatePreference_returnsSavedValueInsteadOfCachedPreviousState() {
        TeamMember cachedPreviousState = member(false);
        when(teamService.requireMember(teamId, senderId)).thenReturn(cachedPreviousState);
        when(memberMapper.updateReceiveTeamNotifications(teamId, senderId, true)).thenReturn(1);
        when(nudgeMapper.findRecipientIds(teamId, senderId, service.today())).thenReturn(List.of());

        var state = service.updatePreference(senderId, teamId, true);

        verify(memberMapper).updateReceiveTeamNotifications(teamId, senderId, true);
        assertThat(state.receiveTeamNotifications()).isTrue();
    }

    @Test
    void todayState_serializesCurrentAndLegacyPreferenceNames() throws Exception {
        var state = new TodayState(service.today(), List.of(), List.of(), false);

        String json = new ObjectMapper().findAndRegisterModules().writeValueAsString(state);

        assertThat(json).contains("\"receiveTeamNotifications\":false");
        assertThat(json).contains("\"receiveWorkoutNudges\":false");
    }

    private void givenEligibleMembers(boolean recipientEnabled) {
        TeamMember sender = member(true);
        TeamMember recipient = member(recipientEnabled);
        when(teamService.requireMember(teamId, senderId)).thenReturn(sender);
        when(teamService.requireMember(teamId, recipientId)).thenReturn(recipient);
        when(memberMapper.findByTeamAndUserForUpdate(teamId, senderId)).thenReturn(sender);
        when(memberMapper.findByTeamAndUserForUpdate(teamId, recipientId)).thenReturn(recipient);
        Team team = new Team();
        team.setId(teamId);
        team.setName("深蹲小队");
        when(teamMapper.selectById(teamId)).thenReturn(team);
    }

    private TeamMember member(boolean enabled) {
        TeamMember member = new TeamMember();
        member.setReceiveTeamNotifications(enabled);
        return member;
    }

    private TeamNudge nudge(LocalDate date) {
        TeamNudge nudge = new TeamNudge();
        nudge.setId(UUID.randomUUID());
        nudge.setTeamId(teamId);
        nudge.setSenderUserId(senderId);
        nudge.setRecipientUserId(recipientId);
        nudge.setNudgeDate(date);
        nudge.setCreatedAt(OffsetDateTime.now());
        return nudge;
    }
}
