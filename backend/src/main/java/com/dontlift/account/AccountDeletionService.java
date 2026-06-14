package com.dontlift.account;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
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
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * 账号删除（合规 5.1.1(v)）：单事务级联物理硬删该 user 名下全部数据，团主删号连带解散团队。
 *
 * <p>删除前尽力主动撤销 Apple 授权（D3）：用已存 refresh_token + client_secret 调 Apple revoke，
 * 凭据缺失或失败时记日志降级、不阻断删除。本地删除按 FK 拓扑先子后父逐表执行，任一步异常整体回滚。
 *
 * <p>新增挂 app_user 的表时，务必在此补对应删除调用并加测试覆盖（删除逻辑集中此处，见 design Risks）。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AccountDeletionService {

    private static final String PROVIDER_APPLE = "apple";

    private final AppUserMapper appUserMapper;
    private final UserIdentityMapper userIdentityMapper;
    private final IdempotencyKeyMapper idempotencyKeyMapper;
    private final DeviceTokenMapper deviceTokenMapper;
    private final CustomExerciseMapper customExerciseMapper;
    private final WorkoutPlanMapper workoutPlanMapper;
    private final WorkoutMapper workoutMapper;
    private final TeamMapper teamMapper;
    private final TeamMemberMapper teamMemberMapper;
    private final TeamCheckinMapper teamCheckinMapper;
    private final CheckinReactionMapper checkinReactionMapper;
    private final AppleClientSecretFactory clientSecretFactory;
    private final AppleTokenClient appleTokenClient;

    /** 删号影响面（只读，不改数据）。 */
    @Transactional(readOnly = true)
    public DeletionImpact impact(UUID userId) {
        return new DeletionImpact(
                teamMapper.countOwnedActiveTeams(userId),
                teamMapper.countAffectedMembers(userId));
    }

    /**
     * 删除自身账号。天然幂等：user 已不存在则空操作直接返回。
     */
    @Transactional
    public void deleteSelf(UUID userId) {
        AppUser user = appUserMapper.selectById(userId);
        if (user == null) {
            log.info("删号空操作：user {} 已不存在", userId);
            return;
        }

        // 1) 尽力主动撤销 Apple 授权（降级容错，不阻断删除）
        revokeAppleIfPossible(userId);

        // 2) Team 维度：先子后父（reaction → checkin → member → team），
        //    覆盖「本人作为 owner 的团队整体解散」与「本人在他人团队的成员/打卡/表情」两维度
        checkinReactionMapper.deleteByUserOrOwnedTeams(userId);
        teamCheckinMapper.deleteByUserOrOwnedTeams(userId);
        teamMemberMapper.deleteByUserOrOwnedTeams(userId);
        teamMapper.deleteOwnedTeams(userId);

        // 3) 自身训练数据（workout 子树随 ON DELETE CASCADE 连带删）
        workoutMapper.deleteAllByUser(userId);
        workoutPlanMapper.deleteAllByUser(userId);
        customExerciseMapper.deleteAllByUser(userId);

        // 4) 账户附属
        deviceTokenMapper.deleteAllByUser(userId);
        idempotencyKeyMapper.deleteAllByUser(userId);
        userIdentityMapper.deleteAllByUser(userId);

        // 5) 主体
        appUserMapper.hardDeleteById(userId);

        log.info("已物理删除账号及全部数据 user={}", userId);
    }

    private void revokeAppleIfPossible(UUID userId) {
        if (!clientSecretFactory.available()) {
            log.warn("Apple client_secret 凭据缺失，跳过 revoke，仅本地删除 user={}", userId);
            return;
        }
        List<UserIdentity> identities = userIdentityMapper.selectList(new LambdaQueryWrapper<UserIdentity>()
                .eq(UserIdentity::getUserId, userId)
                .eq(UserIdentity::getProvider, PROVIDER_APPLE));
        for (UserIdentity identity : identities) {
            String refreshToken = identity.getAppleRefreshToken();
            if (refreshToken == null || refreshToken.isBlank()) {
                log.warn("用户无可撤销 refresh_token，跳过 revoke user={}", userId);
                continue;
            }
            try {
                String clientSecret = clientSecretFactory.create();
                boolean ok = appleTokenClient.revokeToken(clientSecretFactory.clientId(), clientSecret, refreshToken);
                log.info("Apple revoke {} user={}", ok ? "成功" : "失败(降级,不阻断)", userId);
            } catch (Exception e) {
                // revoke 失败绝不回滚本地删除（D3.4）
                log.warn("Apple revoke 异常（降级,不阻断删除）user={}", userId, e);
            }
        }
    }
}
