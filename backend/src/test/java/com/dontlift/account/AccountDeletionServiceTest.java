package com.dontlift.account;

import com.dontlift.account.dto.DeletionImpact;
import com.dontlift.account.entity.AppUser;
import com.dontlift.account.entity.UserIdentity;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.account.mapper.UserIdentityMapper;
import com.dontlift.auth.AppleClientSecretFactory;
import com.dontlift.auth.AppleTokenClient;
import com.dontlift.idempotency.mapper.IdempotencyKeyMapper;
import com.dontlift.push.mapper.DeviceTokenMapper;
import com.dontlift.team.entity.Team;
import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.mapper.CheckinReactionMapper;
import com.dontlift.team.mapper.TeamCheckinMapper;
import com.dontlift.team.mapper.TeamMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import com.dontlift.workout.mapper.CustomExerciseMapper;
import com.dontlift.workout.mapper.WorkoutMapper;
import com.dontlift.workout.mapper.WorkoutPlanGroupMapper;
import com.dontlift.workout.mapper.WorkoutPlanMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AccountDeletionServiceTest {

    @Mock AppUserMapper appUserMapper;
    @Mock UserIdentityMapper userIdentityMapper;
    @Mock IdempotencyKeyMapper idempotencyKeyMapper;
    @Mock DeviceTokenMapper deviceTokenMapper;
    @Mock CustomExerciseMapper customExerciseMapper;
    @Mock WorkoutPlanMapper workoutPlanMapper;
    @Mock WorkoutPlanGroupMapper workoutPlanGroupMapper;
    @Mock WorkoutMapper workoutMapper;
    @Mock TeamMapper teamMapper;
    @Mock TeamMemberMapper teamMemberMapper;
    @Mock TeamCheckinMapper teamCheckinMapper;
    @Mock CheckinReactionMapper checkinReactionMapper;
    @Mock AppleClientSecretFactory clientSecretFactory;
    @Mock AppleTokenClient appleTokenClient;

    @InjectMocks AccountDeletionService service;

    private final UUID userId = UUID.randomUUID();

    /** 账号删除：按 FK 拓扑只删除本人数据，最后删 app_user，不解散多人 Team。 */
    @Test
    void deleteSelf_cascadesAllTablesInTopologicalOrder() {
        givenExistingUserWithoutOwnedTeams();

        service.deleteSelf(userId);

        InOrder order = inOrder(checkinReactionMapper, teamCheckinMapper, teamMapper, teamMemberMapper,
                workoutMapper, workoutPlanMapper, workoutPlanGroupMapper, customExerciseMapper,
                deviceTokenMapper, idempotencyKeyMapper, userIdentityMapper, appUserMapper);
        // Team 个人维度：只删本人 reaction/checkin/member，不删除 owner 名下其他成员历史
        order.verify(checkinReactionMapper).deleteByUser(userId);
        order.verify(teamCheckinMapper).deleteByUser(userId);
        order.verify(teamMapper).findActiveOwnedTeams(userId);
        order.verify(teamMemberMapper).deleteByUser(userId);
        // 自身训练数据
        order.verify(workoutMapper).deleteAllByUser(userId);
        order.verify(workoutPlanMapper).deleteAllByUser(userId);
        order.verify(workoutPlanGroupMapper).deleteAllByUser(userId);
        order.verify(customExerciseMapper).deleteAllByUser(userId);
        // 账户附属
        order.verify(deviceTokenMapper).deleteAllByUser(userId);
        order.verify(idempotencyKeyMapper).deleteAllByUser(userId);
        order.verify(userIdentityMapper).deleteAllByUser(userId);
        // 主体最后删
        order.verify(appUserMapper).hardDeleteById(userId);
        verify(teamMapper, never()).deleteOwnedTeams(userId);
        verify(teamMemberMapper, never()).deleteByUserOrOwnedTeams(userId);
        verify(teamCheckinMapper, never()).deleteByUserOrOwnedTeams(userId);
        verify(checkinReactionMapper, never()).deleteByUserOrOwnedTeams(userId);
    }

    /** 3.2 边界：user 已不存在时为幂等空操作，不触碰任何表。 */
    @Test
    void deleteSelf_isNoOpWhenUserAlreadyGone() {
        when(appUserMapper.selectById(userId)).thenReturn(null);

        service.deleteSelf(userId);

        verify(appUserMapper, never()).hardDeleteById(userId);
        verifyNoInteractions(checkinReactionMapper, teamCheckinMapper, teamMemberMapper, teamMapper,
                workoutMapper, workoutPlanMapper, workoutPlanGroupMapper, customExerciseMapper,
                deviceTokenMapper, idempotencyKeyMapper);
    }

    /** 3.3：revoke 凭据缺失时降级——不调 Apple，仍完整执行本地删除。 */
    @Test
    void deleteSelf_degradesWhenRevokeCredentialsMissing() {
        givenExistingUserWithoutOwnedTeams();
        when(clientSecretFactory.available()).thenReturn(false);

        service.deleteSelf(userId);

        verifyNoInteractions(appleTokenClient);
        verify(appUserMapper).hardDeleteById(userId); // 删除照常完成
    }

    /** 3.4：凭据齐备且存有 refresh_token 时，删号触发 Apple revoke 调用。 */
    @Test
    void deleteSelf_invokesAppleRevokeWhenTokenPresent() {
        givenExistingUserWithoutOwnedTeams();
        when(clientSecretFactory.available()).thenReturn(true);
        when(clientSecretFactory.clientId()).thenReturn("com.example.app");
        when(clientSecretFactory.create()).thenReturn("signed-client-secret");
        UserIdentity identity = new UserIdentity();
        identity.setAppleRefreshToken("rt-123");
        when(userIdentityMapper.selectList(org.mockito.ArgumentMatchers.any())).thenReturn(List.of(identity));

        service.deleteSelf(userId);

        verify(appleTokenClient).revokeToken("com.example.app", "signed-client-secret", "rt-123");
        verify(appUserMapper).hardDeleteById(userId);
    }

    /** 3.4：影响面计数直接委托 mapper。 */
    @Test
    void impact_returnsCountsFromMapper() {
        when(teamMapper.countOwnedTeamsToTransfer(userId)).thenReturn(2);
        when(teamMapper.countEmptyOwnedTeamsToDelete(userId)).thenReturn(1);
        when(teamMapper.countAffectedMembers(userId)).thenReturn(5);

        DeletionImpact impact = service.impact(userId);

        assertThat(impact.ownedTeamsToTransfer()).isEqualTo(2);
        assertThat(impact.emptyOwnedTeamsToDelete()).isEqualTo(1);
        assertThat(impact.affectedMembers()).isEqualTo(5);
    }

    @Test
    void deleteSelf_transfersOwnedTeamToOldestRemainingMember() {
        when(appUserMapper.selectById(userId)).thenReturn(new AppUser());
        Team team = team(UUID.randomUUID());
        TeamMember replacement = member(team.getId(), UUID.randomUUID());
        when(teamMapper.findActiveOwnedTeams(userId)).thenReturn(List.of(team));
        when(teamMemberMapper.findOldestOtherMember(team.getId(), userId)).thenReturn(replacement);

        service.deleteSelf(userId);

        verify(teamMapper).transferOwner(team.getId(), userId, replacement.getUserId());
        verify(teamMemberMapper).updateRole(team.getId(), replacement.getUserId(), "owner");
        verify(teamMemberMapper).deleteByUser(userId);
        verify(teamCheckinMapper, never()).deleteByTeam(team.getId());
        verify(teamMapper, never()).hardDeleteById(team.getId());
    }

    @Test
    void deleteSelf_deletesOwnedTeamOnlyWhenNoOtherMembersRemain() {
        when(appUserMapper.selectById(userId)).thenReturn(new AppUser());
        Team team = team(UUID.randomUUID());
        when(teamMapper.findActiveOwnedTeams(userId)).thenReturn(List.of(team));
        when(teamMemberMapper.findOldestOtherMember(team.getId(), userId)).thenReturn(null);

        service.deleteSelf(userId);

        verify(teamCheckinMapper).deleteByTeam(team.getId());
        verify(teamMemberMapper).deleteByTeam(team.getId());
        verify(teamMapper).hardDeleteById(team.getId());
        verify(teamMapper, never()).transferOwner(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
    }

    private void givenExistingUserWithoutOwnedTeams() {
        when(appUserMapper.selectById(userId)).thenReturn(new AppUser());
        when(teamMapper.findActiveOwnedTeams(userId)).thenReturn(List.of());
    }

    private Team team(UUID teamId) {
        Team team = new Team();
        team.setId(teamId);
        team.setOwnerUserId(userId);
        return team;
    }

    private TeamMember member(UUID teamId, UUID memberId) {
        TeamMember member = new TeamMember();
        member.setId(UUID.randomUUID());
        member.setTeamId(teamId);
        member.setUserId(memberId);
        member.setRole("member");
        return member;
    }
}
