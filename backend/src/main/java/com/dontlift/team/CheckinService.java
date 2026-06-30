package com.dontlift.team;

import com.dontlift.common.id.Uuid7;
import com.dontlift.common.web.AppException;
import com.dontlift.push.PushService;
import com.dontlift.team.dto.TeamCheckinFeed;
import com.dontlift.team.entity.CheckinReaction;
import com.dontlift.team.entity.TeamCheckin;
import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.mapper.CheckinReactionMapper;
import com.dontlift.team.mapper.TeamCheckinMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.mapper.WorkoutMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** 训练分享打卡 + 表情回应 + 事件推送（5.4）。 */
@Service
public class CheckinService {

    private static final Set<String> EMOJIS = Set.of("muscle", "fire", "clap", "heart");

    private final TeamMemberMapper memberMapper;
    private final TeamCheckinMapper checkinMapper;
    private final CheckinReactionMapper reactionMapper;
    private final TeamService teamService;
    private final PushService pushService;
    private final WorkoutMapper workoutMapper;

    public CheckinService(TeamMemberMapper memberMapper, TeamCheckinMapper checkinMapper, CheckinReactionMapper reactionMapper,
                          TeamService teamService, PushService pushService, WorkoutMapper workoutMapper) {
        this.memberMapper = memberMapper;
        this.checkinMapper = checkinMapper;
        this.reactionMapper = reactionMapper;
        this.teamService = teamService;
        this.pushService = pushService;
        this.workoutMapper = workoutMapper;
    }

    /**
     * 保存训练分享打卡：仅写入用户显式选择的 Team，按 (team,user,workout) 幂等。
     * summary 为成交时刻快照。新打卡推送给同团其他成员。
     */
    @Transactional
    public List<TeamCheckin> checkIn(UUID userId, UUID workoutId, LocalDate date, String summary, List<UUID> teamIds) {
        if (teamIds == null || teamIds.isEmpty()) {
            throw AppException.badRequest("请选择要分享的 Team");
        }
        requireShareableWorkout(userId, workoutId);
        List<TeamCheckin> affected = new ArrayList<>();
        for (UUID teamId : new LinkedHashSet<>(teamIds)) {
            teamService.requireMember(teamId, userId);
            TeamCheckin existing = checkinMapper.findByTeamUserWorkout(teamId, userId, workoutId);
            if (existing != null) {
                // 已打卡：编辑训练后更新摘要快照（不重复推送），保持本地与 Team 一致。
                existing.setSummary(summary);
                existing.setCheckinDate(date);
                checkinMapper.updateById(existing);
                affected.add(existing);
                continue;
            }
            TeamCheckin c = new TeamCheckin();
            c.setId(Uuid7.generate());
            c.setTeamId(teamId);
            c.setUserId(userId);
            c.setWorkoutId(workoutId);
            c.setCheckinDate(date);
            c.setSummary(summary);
            c.setCreatedAt(OffsetDateTime.now());
            checkinMapper.insert(c);
            affected.add(c);
            notifyOtherMembers(teamId, userId, "队友打卡了", "你的训练搭子完成了今天的训练");
        }
        return affected;
    }

    private void requireShareableWorkout(UUID userId, UUID workoutId) {
        Workout workout = workoutMapper.findByIdIncludingDeleted(workoutId);
        if (workout == null || !userId.equals(workout.getUserId()) || workout.getDeletedAt() != null) {
            throw AppException.notFound("训练尚未同步或已删除，暂不能分享");
        }
    }

    public List<TeamCheckin> listCheckins(UUID userId, UUID teamId, LocalDate date) {
        teamService.requireMember(teamId, userId);
        return checkinMapper.findByTeamAndDate(teamId, date);
    }

    public TeamCheckinFeed listCheckinFeed(UUID userId, UUID teamId, LocalDate date) {
        List<TeamCheckin> checkins = listCheckins(userId, teamId, date);
        return feedFor(checkins);
    }

    public TeamCheckinFeed listCheckinHistory(UUID userId, UUID teamId, YearMonth month) {
        teamService.requireMember(teamId, userId);
        LocalDate startDate = month.atDay(1);
        LocalDate endDate = month.plusMonths(1).atDay(1);
        List<TeamCheckin> checkins = checkinMapper.findByTeamAndDateRange(teamId, startDate, endDate);
        return feedFor(checkins);
    }

    private TeamCheckinFeed feedFor(List<TeamCheckin> checkins) {
        if (checkins.isEmpty()) {
            return new TeamCheckinFeed(checkins, List.of());
        }
        List<UUID> ids = checkins.stream().map(TeamCheckin::getId).toList();
        return new TeamCheckinFeed(checkins, reactionMapper.findByCheckins(ids));
    }

    /**
     * 训练被删除时连带移除其在所有 Team 的打卡，保持「删除后不再计入」与 Team 视图一致。
     * 表情回应由 checkin_reaction 的 ON DELETE CASCADE 自动清理。
     */
    @Transactional
    public void removeForWorkout(UUID userId, UUID workoutId) {
        checkinMapper.deleteByUserWorkout(userId, workoutId);
    }

    /** 撤回某次训练在单个 Team 的可见性。reaction 由 FK ON DELETE CASCADE 清理。 */
    @Transactional
    public void withdraw(UUID userId, UUID teamId, UUID workoutId) {
        teamService.requireMember(teamId, userId);
        checkinMapper.deleteByTeamUserWorkout(teamId, userId, workoutId);
    }

    /**
     * 表情回应（单选·可取消）：一人一打卡仅一条。
     * 再点同一个表情 = 取消（删除，返回 null，不推送）；点另一个 = 切换；未点过 = 新增。
     * 同一成员对同一打卡只在首次有效回应时推送一次，后续切换或重新点亮不再推送。
     */
    @Transactional
    public CheckinReaction react(UUID userId, UUID checkinId, String emoji) {
        if (!EMOJIS.contains(emoji)) {
            throw AppException.badRequest("不支持的表情：" + emoji);
        }
        TeamCheckin checkin = checkinMapper.selectById(checkinId);
        if (checkin == null) {
            throw AppException.notFound("打卡不存在");
        }
        teamService.requireMember(checkin.getTeamId(), userId);

        CheckinReaction existing = reactionMapper.findByCheckinAndUser(checkinId, userId);
        OffsetDateTime now = OffsetDateTime.now();
        CheckinReaction reaction;
        if (existing == null) {
            reaction = new CheckinReaction();
            reaction.setId(Uuid7.generate());
            reaction.setCheckinId(checkinId);
            reaction.setUserId(userId);
            reaction.setEmoji(emoji);
            reaction.setCreatedAt(now);
            reaction.setUpdatedAt(now);
            if (reactionMapper.insertReactionIfAbsent(reaction) == 0) {
                CheckinReaction concurrent = reactionMapper.findByCheckinAndUser(checkinId, userId);
                if (concurrent == null) {
                    throw AppException.conflict("表情回应状态已变化，请重试");
                }
                if (concurrent.getEmoji().equals(emoji)) {
                    reaction = concurrent;
                } else {
                    concurrent.setEmoji(emoji);
                    concurrent.setUpdatedAt(now);
                    reactionMapper.updateById(concurrent);
                    reaction = concurrent;
                }
            }
        } else if (existing.getEmoji().equals(emoji)) {
            // 再点同一个 → 取消：物理删除该条（uq_reaction 唯一约束允许重新点亮）
            reactionMapper.deleteById(existing.getId());
            return null;
        } else {
            existing.setEmoji(emoji);
            existing.setUpdatedAt(now);
            reactionMapper.updateById(existing);
            reaction = existing;
        }
        if (shouldSendReactionPush(checkin, userId, checkinId, now)) {
            pushService.sendToUser(checkin.getUserId(), "新的表情回应",
                    "有人为你的训练点了表情", Map.of("checkinId", checkinId.toString(), "emoji", emoji));
        }
        return reaction;
    }

    private boolean shouldSendReactionPush(TeamCheckin checkin, UUID reactorUserId, UUID checkinId, OffsetDateTime now) {
        if (checkin.getUserId().equals(reactorUserId)) {
            return false;
        }
        return reactionMapper.insertPushReceiptIfAbsent(Uuid7.generate(), checkinId, reactorUserId, now) == 1;
    }

    public List<CheckinReaction> listReactions(UUID userId, UUID checkinId) {
        TeamCheckin checkin = checkinMapper.selectById(checkinId);
        if (checkin == null) {
            throw AppException.notFound("打卡不存在");
        }
        teamService.requireMember(checkin.getTeamId(), userId);
        return reactionMapper.findByCheckin(checkinId);
    }

    private void notifyOtherMembers(UUID teamId, UUID actorUserId, String title, String body) {
        for (TeamMember m : memberMapper.findByTeam(teamId)) {
            if (!m.getUserId().equals(actorUserId)) {
                pushService.sendToUser(m.getUserId(), title, body, Map.of("teamId", teamId.toString()));
            }
        }
    }
}
