package com.dontlift.team;

import com.dontlift.common.web.AppException;
import com.dontlift.team.dto.TeamMemberView;
import com.dontlift.team.entity.Team;
import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.mapper.TeamMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TeamServiceTest {

    @Mock TeamMapper teamMapper;
    @Mock TeamMemberMapper memberMapper;

    @InjectMocks TeamService service;

    private final UUID userId = UUID.randomUUID();
    private final UUID teamId = UUID.randomUUID();

    @Test
    void listMySharePreferences_returnsCurrentUsersActiveMemberships() {
        TeamMemberView view = new TeamMemberView();
        view.setTeamId(teamId);
        view.setUserId(userId);
        view.setAutoShareWorkouts(false);
        when(memberMapper.findMyActiveViews(userId)).thenReturn(List.of(view));

        List<TeamMemberView> result = service.listMySharePreferences(userId);

        assertThat(result).containsExactly(view);
        assertThat(result.get(0).isAutoShareWorkouts()).isFalse();
    }

    @Test
    void updateSharePreference_requiresMembershipAndPersistsChoice() {
        when(teamMapper.selectById(teamId)).thenReturn(activeTeam());
        when(memberMapper.findByTeamAndUser(teamId, userId)).thenReturn(member());
        TeamMemberView updated = new TeamMemberView();
        updated.setTeamId(teamId);
        updated.setUserId(userId);
        updated.setAutoShareWorkouts(true);
        when(memberMapper.findViewByTeamAndUser(teamId, userId)).thenReturn(updated);

        TeamMemberView result = service.updateSharePreference(userId, teamId, true);

        assertThat(result.isAutoShareWorkouts()).isTrue();
        verify(memberMapper).updateAutoShareWorkouts(teamId, userId, true);
    }

    @Test
    void updateSharePreference_rejectsNonMember() {
        when(teamMapper.selectById(teamId)).thenReturn(activeTeam());

        assertThatThrownBy(() -> service.updateSharePreference(userId, teamId, true))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("非该 Team 成员");

        verify(memberMapper, never()).updateAutoShareWorkouts(teamId, userId, true);
    }

    private Team activeTeam() {
        Team team = new Team();
        team.setId(teamId);
        team.setName("测试 Team");
        team.setOwnerUserId(UUID.randomUUID());
        return team;
    }

    private TeamMember member() {
        TeamMember member = new TeamMember();
        member.setTeamId(teamId);
        member.setUserId(userId);
        member.setRole("member");
        return member;
    }
}
