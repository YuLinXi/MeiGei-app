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
import com.dontlift.team.mapper.CheckinReactionMapper;
import com.dontlift.team.mapper.TeamCheckinMapper;
import com.dontlift.team.mapper.TeamMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import com.dontlift.workout.mapper.CustomExerciseMapper;
import com.dontlift.workout.mapper.WorkoutMapper;
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
import static org.mockito.ArgumentMatchers.eq;
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
    @Mock WorkoutMapper workoutMapper;
    @Mock TeamMapper teamMapper;
    @Mock TeamMemberMapper teamMemberMapper;
    @Mock TeamCheckinMapper teamCheckinMapper;
    @Mock CheckinReactionMapper checkinReactionMapper;
    @Mock AppleClientSecretFactory clientSecretFactory;
    @Mock AppleTokenClient appleTokenClient;

    @InjectMocks AccountDeletionService service;

    private final UUID userId = UUID.randomUUID();

    /** 3.1/3.2：删号按 FK 拓扑先子后父逐表删，覆盖团主解散维度与自身维度，最后删 app_user。 */
    @Test
    void deleteSelf_cascadesAllTablesInTopologicalOrder() {
        when(appUserMapper.selectById(userId)).thenReturn(new AppUser());

        service.deleteSelf(userId);

        InOrder order = inOrder(checkinReactionMapper, teamCheckinMapper, teamMemberMapper, teamMapper,
                workoutMapper, workoutPlanMapper, customExerciseMapper,
                deviceTokenMapper, idempotencyKeyMapper, userIdentityMapper, appUserMapper);
        // Team 维度：reaction → checkin → member → team（先子后父，避免 FK 违例）
        order.verify(checkinReactionMapper).deleteByUserOrOwnedTeams(userId);
        order.verify(teamCheckinMapper).deleteByUserOrOwnedTeams(userId);
        order.verify(teamMemberMapper).deleteByUserOrOwnedTeams(userId);
        order.verify(teamMapper).deleteOwnedTeams(userId);
        // 自身训练数据
        order.verify(workoutMapper).deleteAllByUser(userId);
        order.verify(workoutPlanMapper).deleteAllByUser(userId);
        order.verify(customExerciseMapper).deleteAllByUser(userId);
        // 账户附属
        order.verify(deviceTokenMapper).deleteAllByUser(userId);
        order.verify(idempotencyKeyMapper).deleteAllByUser(userId);
        order.verify(userIdentityMapper).deleteAllByUser(userId);
        // 主体最后删
        order.verify(appUserMapper).hardDeleteById(userId);
    }

    /** 3.2 边界：user 已不存在时为幂等空操作，不触碰任何表。 */
    @Test
    void deleteSelf_isNoOpWhenUserAlreadyGone() {
        when(appUserMapper.selectById(userId)).thenReturn(null);

        service.deleteSelf(userId);

        verify(appUserMapper, never()).hardDeleteById(userId);
        verifyNoInteractions(checkinReactionMapper, teamCheckinMapper, teamMemberMapper, teamMapper,
                workoutMapper, workoutPlanMapper, customExerciseMapper,
                deviceTokenMapper, idempotencyKeyMapper);
    }

    /** 3.3：revoke 凭据缺失时降级——不调 Apple，仍完整执行本地删除。 */
    @Test
    void deleteSelf_degradesWhenRevokeCredentialsMissing() {
        when(appUserMapper.selectById(userId)).thenReturn(new AppUser());
        when(clientSecretFactory.available()).thenReturn(false);

        service.deleteSelf(userId);

        verifyNoInteractions(appleTokenClient);
        verify(appUserMapper).hardDeleteById(userId); // 删除照常完成
    }

    /** 3.4：凭据齐备且存有 refresh_token 时，删号触发 Apple revoke 调用。 */
    @Test
    void deleteSelf_invokesAppleRevokeWhenTokenPresent() {
        when(appUserMapper.selectById(userId)).thenReturn(new AppUser());
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
        when(teamMapper.countOwnedActiveTeams(userId)).thenReturn(2);
        when(teamMapper.countAffectedMembers(userId)).thenReturn(5);

        DeletionImpact impact = service.impact(userId);

        assertThat(impact.ownedTeams()).isEqualTo(2);
        assertThat(impact.affectedMembers()).isEqualTo(5);
    }
}
