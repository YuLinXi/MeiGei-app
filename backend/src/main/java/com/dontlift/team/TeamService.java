package com.dontlift.team;

import com.dontlift.common.id.Uuid7;
import com.dontlift.common.web.AppException;
import com.dontlift.team.dto.TeamMemberView;
import com.dontlift.team.entity.Team;
import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.mapper.TeamMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Team 生命周期与成员管理（5.2）。上限：每团 ≤10 人、每用户 ≤3 团。 */
@Service
public class TeamService {

    static final int MAX_MEMBERS = 10;
    static final int MAX_TEAMS_PER_USER = 3;
    private static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 去掉易混 I/O/0/1
    private static final int CODE_LEN = 6;

    private final TeamMapper teamMapper;
    private final TeamMemberMapper memberMapper;
    private final SecureRandom random = new SecureRandom();

    public TeamService(TeamMapper teamMapper, TeamMemberMapper memberMapper) {
        this.teamMapper = teamMapper;
        this.memberMapper = memberMapper;
    }

    @Transactional
    public Team createTeam(UUID userId, String name) {
        if (memberMapper.countActiveByUser(userId) >= MAX_TEAMS_PER_USER) {
            throw AppException.conflict("最多加入 " + MAX_TEAMS_PER_USER + " 个 Team");
        }
        Team team = new Team();
        team.setId(Uuid7.generate());
        team.setName(name);
        team.setOwnerUserId(userId);
        insertWithUniqueCode(team);
        addMember(team.getId(), userId, "owner");
        return team;
    }

    @Transactional
    public Team joinByInviteCode(UUID userId, String code) {
        Team team = teamMapper.findByInviteCode(code);
        if (team == null) {
            throw AppException.notFound("邀请码无效或 Team 已解散");
        }
        if (memberMapper.findByTeamAndUser(team.getId(), userId) != null) {
            return team; // 已是成员，幂等返回
        }
        if (memberMapper.countActiveByUser(userId) >= MAX_TEAMS_PER_USER) {
            throw AppException.conflict("最多加入 " + MAX_TEAMS_PER_USER + " 个 Team");
        }
        if (memberMapper.countByTeam(team.getId()) >= MAX_MEMBERS) {
            throw AppException.conflict("该 Team 已满 " + MAX_MEMBERS + " 人");
        }
        addMember(team.getId(), userId, "member");
        return team;
    }

    public List<Team> listMyTeams(UUID userId) {
        return teamMapper.findByMember(userId);
    }

    public List<TeamMemberView> getMembers(UUID teamId, UUID userId) {
        requireMember(teamId, userId);
        return memberMapper.findViewByTeam(teamId);
    }

    /** 成员退出；群主不可退出（需解散或后续支持转让）。 */
    @Transactional
    public void leaveTeam(UUID userId, UUID teamId) {
        TeamMember m = requireMember(teamId, userId);
        if ("owner".equals(m.getRole())) {
            throw AppException.conflict("群主不能退出，请解散 Team");
        }
        memberMapper.deleteByTeamAndUser(teamId, userId);
    }

    /** 群主解散：软删 Team + 清成员关系。 */
    @Transactional
    public void dissolveTeam(UUID userId, UUID teamId) {
        Team team = activeTeamOrThrow(teamId);
        if (!team.getOwnerUserId().equals(userId)) {
            throw AppException.forbidden("仅群主可解散 Team");
        }
        memberMapper.deleteByTeam(teamId);
        teamMapper.deleteById(teamId); // @TableLogic 软删
    }

    /** 校验并返回成员关系；非成员 → 403。 */
    public TeamMember requireMember(UUID teamId, UUID userId) {
        activeTeamOrThrow(teamId);
        TeamMember m = memberMapper.findByTeamAndUser(teamId, userId);
        if (m == null) {
            throw AppException.forbidden("非该 Team 成员");
        }
        return m;
    }

    private Team activeTeamOrThrow(UUID teamId) {
        Team team = teamMapper.selectById(teamId); // @TableLogic 已过滤已解散
        if (team == null) {
            throw AppException.notFound("Team 不存在或已解散");
        }
        return team;
    }

    private void addMember(UUID teamId, UUID userId, String role) {
        TeamMember m = new TeamMember();
        m.setId(Uuid7.generate());
        m.setTeamId(teamId);
        m.setUserId(userId);
        m.setRole(role);
        m.setJoinedAt(OffsetDateTime.now());
        memberMapper.insert(m);
    }

    private void insertWithUniqueCode(Team team) {
        for (int attempt = 0; attempt < 5; attempt++) {
            team.setInviteCode(randomCode());
            try {
                teamMapper.insert(team);
                return;
            } catch (DuplicateKeyException e) {
                // 邀请码碰撞，重试
            }
        }
        throw AppException.conflict("生成邀请码失败，请重试");
    }

    private String randomCode() {
        StringBuilder sb = new StringBuilder(CODE_LEN);
        for (int i = 0; i < CODE_LEN; i++) {
            sb.append(CODE_ALPHABET.charAt(random.nextInt(CODE_ALPHABET.length())));
        }
        return sb.toString();
    }
}
