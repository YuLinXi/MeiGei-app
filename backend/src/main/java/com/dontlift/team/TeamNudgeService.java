package com.dontlift.team;

import com.dontlift.common.id.Uuid7;
import com.dontlift.common.web.AppException;
import com.dontlift.push.PushService;
import com.dontlift.team.dto.TeamMemberView;
import com.dontlift.team.dto.TeamNudgeResponses.SendResult;
import com.dontlift.team.dto.TeamNudgeResponses.TodayState;
import com.dontlift.team.entity.Team;
import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.entity.TeamNudge;
import com.dontlift.team.mapper.TeamCheckinMapper;
import com.dontlift.team.mapper.TeamMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import com.dontlift.team.mapper.TeamNudgeMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Map;
import java.util.UUID;

/** Team 成员一次性拍一拍：服务端自然日去重、跨 Team 限频并按需发送 APNs。 */
@Service
public class TeamNudgeService {

    static final ZoneId NUDGE_ZONE = ZoneId.of("Asia/Shanghai");
    static final int MAX_DISTINCT_RECIPIENTS_PER_DAY = 5;
    static final int MAX_PUSHES_PER_RECIPIENT_PER_DAY = 3;

    private final TeamNudgeMapper nudgeMapper;
    private final TeamMemberMapper memberMapper;
    private final TeamCheckinMapper checkinMapper;
    private final TeamMapper teamMapper;
    private final TeamService teamService;
    private final PushService pushService;

    public TeamNudgeService(TeamNudgeMapper nudgeMapper,
                            TeamMemberMapper memberMapper,
                            TeamCheckinMapper checkinMapper,
                            TeamMapper teamMapper,
                            TeamService teamService,
                            PushService pushService) {
        this.nudgeMapper = nudgeMapper;
        this.memberMapper = memberMapper;
        this.checkinMapper = checkinMapper;
        this.teamMapper = teamMapper;
        this.teamService = teamService;
        this.pushService = pushService;
    }

    public TodayState todayState(UUID userId, UUID teamId) {
        TeamMember member = teamService.requireMember(teamId, userId);
        LocalDate date = today();
        return new TodayState(
                date,
                nudgeMapper.findRecipientIds(teamId, userId, date),
                memberMapper.findReceivableNudgeUserIds(teamId, userId),
                member.isReceiveWorkoutNudges()
        );
    }

    @Transactional
    public TodayState updatePreference(UUID userId, UUID teamId, boolean enabled) {
        teamService.requireMember(teamId, userId);
        memberMapper.updateReceiveWorkoutNudges(teamId, userId, enabled);
        return todayState(userId, teamId);
    }

    @Transactional
    public SendResult send(UUID senderUserId, UUID teamId, UUID recipientUserId) {
        if (senderUserId.equals(recipientUserId)) {
            throw AppException.badRequest("不能拍自己");
        }

        teamService.requireMember(teamId, senderUserId);
        teamService.requireMember(teamId, recipientUserId);
        lockUsers(senderUserId, recipientUserId);

        // 退出/解散可能与发送并发；锁住成员行后再次确认，避免失效成员写入事件。
        TeamMember sender = memberMapper.findByTeamAndUserForUpdate(teamId, senderUserId);
        TeamMember recipient = memberMapper.findByTeamAndUserForUpdate(teamId, recipientUserId);
        Team team = teamMapper.selectById(teamId);
        if (sender == null || recipient == null || team == null) {
            throw AppException.conflict("暂时无法拍一拍该成员");
        }

        LocalDate date = today();
        TeamNudge existing = nudgeMapper.findDaily(teamId, senderUserId, recipientUserId, date);
        if (existing != null) {
            return toResult(existing);
        }
        if (!recipient.isReceiveWorkoutNudges()) {
            throw AppException.conflict("暂时无法拍一拍该成员");
        }
        if (checkinMapper.existsByTeamUserDate(teamId, recipientUserId, date)) {
            throw AppException.conflict("对方今天已有 Team 动态");
        }

        boolean alreadyCounted = nudgeMapper.hasRecipient(senderUserId, recipientUserId, date);
        if (!alreadyCounted
                && nudgeMapper.countDistinctRecipients(senderUserId, date) >= MAX_DISTINCT_RECIPIENTS_PER_DAY) {
            throw AppException.conflict("今天拍一拍次数已用完");
        }
        boolean shouldPush = nudgeMapper.countForRecipient(recipientUserId, date)
                < MAX_PUSHES_PER_RECIPIENT_PER_DAY;

        TeamNudge nudge = new TeamNudge();
        nudge.setId(Uuid7.generate());
        nudge.setTeamId(teamId);
        nudge.setSenderUserId(senderUserId);
        nudge.setRecipientUserId(recipientUserId);
        nudge.setNudgeDate(date);
        nudge.setCreatedAt(OffsetDateTime.now());
        nudgeMapper.insert(nudge);

        if (shouldPush) {
            TeamMemberView senderView = memberMapper.findViewByTeamAndUser(teamId, senderUserId);
            String displayName = senderView == null ? null : senderView.getDisplayName();
            String senderName = displayName == null || displayName.isBlank() ? "队友" : displayName.trim();
            pushService.sendToUser(
                    recipientUserId,
                    "队友拍了拍你",
                    senderName + " 在「" + team.getName() + "」喊你一起练练",
                    Map.of("type", "team_nudge", "teamId", teamId.toString())
            );
        }
        return toResult(nudge);
    }

    LocalDate today() {
        return LocalDate.now(NUDGE_ZONE);
    }

    private void lockUsers(UUID firstUserId, UUID secondUserId) {
        if (firstUserId.toString().compareTo(secondUserId.toString()) < 0) {
            nudgeMapper.lockUser(firstUserId);
            nudgeMapper.lockUser(secondUserId);
        } else {
            nudgeMapper.lockUser(secondUserId);
            nudgeMapper.lockUser(firstUserId);
        }
    }

    private SendResult toResult(TeamNudge nudge) {
        return new SendResult(nudge.getRecipientUserId(), nudge.getNudgeDate(), nudge.getCreatedAt());
    }
}
