package com.dontlift.auth;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.dontlift.account.entity.AppUser;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.team.entity.CheckinReaction;
import com.dontlift.team.entity.Team;
import com.dontlift.team.entity.TeamCheckin;
import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.entity.TeamNudge;
import com.dontlift.team.mapper.CheckinReactionMapper;
import com.dontlift.team.mapper.TeamCheckinMapper;
import com.dontlift.team.mapper.TeamMapper;
import com.dontlift.team.mapper.TeamMemberMapper;
import com.dontlift.team.mapper.TeamNudgeMapper;
import com.dontlift.workout.entity.Workout;
import com.dontlift.workout.entity.WorkoutExercise;
import com.dontlift.workout.entity.WorkoutSet;
import com.dontlift.workout.mapper.WorkoutExerciseMapper;
import com.dontlift.workout.mapper.WorkoutMapper;
import com.dontlift.workout.mapper.WorkoutSetMapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * 本地开发账号与示例数据种子。
 * 仅在 APP_DEV_TOKEN=true 时随 DevAuthController 启用，生产环境不会注册。
 */
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "app.dev", name = "token-enabled", havingValue = "true")
public class DevDataSeeder {

    public static final UUID DEV_USER_ID = id("user:dev-owner");

    private static final UUID TEAMMATE_USER_ID = id("user:dev-teammate");
    private static final UUID TEAMMATE_TWO_USER_ID = id("user:dev-teammate-two");
    private static final UUID NUDGED_USER_ID = id("user:dev-nudged");
    private static final UUID DISABLED_USER_ID = id("user:dev-nudge-disabled");
    private static final UUID ELIGIBLE_USER_ID = id("user:dev-nudge-eligible");
    private static final UUID TEAM_ID = id("team:local-simulator");
    private static final UUID NUDGE_TEAM_ID = id("team:nudge-validation");
    private static final String DEV_USER_NAME = "本地测试账号";
    private static final String TEAMMATE_NAME = "测试队友";
    private static final String TEAMMATE_TWO_NAME = "测试成员阿凯";
    private static final String NUDGED_USER_NAME = "老周";
    private static final String DISABLED_USER_NAME = "小满";
    private static final String ELIGIBLE_USER_NAME = "阿岳";
    private static final String TEAM_NAME = "本地测试 Team";
    private static final String NUDGE_TEAM_NAME = "拍一拍验收 Team";
    private static final String INVITE_CODE = "DEVGYM";
    private static final String NUDGE_INVITE_CODE = "NUDGE1";
    private static final ZoneId DEV_ZONE = ZoneId.of("Asia/Shanghai");
    private static final ZoneOffset DEV_OFFSET = ZoneOffset.ofHours(8);

    private final AppUserMapper appUserMapper;
    private final TeamMapper teamMapper;
    private final TeamMemberMapper memberMapper;
    private final WorkoutMapper workoutMapper;
    private final WorkoutExerciseMapper exerciseMapper;
    private final WorkoutSetMapper setMapper;
    private final TeamCheckinMapper checkinMapper;
    private final CheckinReactionMapper reactionMapper;
    private final TeamNudgeMapper nudgeMapper;
    private final ObjectMapper objectMapper;

    @Transactional
    public SeedResult seed() {
        LocalDate today = LocalDate.now(DEV_ZONE);
        boolean created = ensureUser(DEV_USER_ID, DEV_USER_NAME, "dev@dontlift.local", "male");
        ensureUser(TEAMMATE_USER_ID, TEAMMATE_NAME, "teammate@dontlift.local", "female");
        ensureUser(TEAMMATE_TWO_USER_ID, TEAMMATE_TWO_NAME, "teammate2@dontlift.local", "male");
        ensureUser(NUDGED_USER_ID, NUDGED_USER_NAME, "nudged@dontlift.local", "male");
        ensureUser(DISABLED_USER_ID, DISABLED_USER_NAME, "nudge-disabled@dontlift.local", "female");
        ensureUser(ELIGIBLE_USER_ID, ELIGIBLE_USER_NAME, "nudge-eligible@dontlift.local", "male");

        ensureTeam(TEAM_ID, TEAM_NAME, INVITE_CODE, teamCreatedAt(today, 60));
        ensureMember(TEAM_ID, DEV_USER_ID, memberId("owner"), "owner", true);
        ensureMember(TEAM_ID, TEAMMATE_USER_ID, memberId("teammate"), "member", true);
        ensureMember(TEAM_ID, TEAMMATE_TWO_USER_ID, memberId("teammate-two"), "member", true);

        ensureTeam(NUDGE_TEAM_ID, NUDGE_TEAM_NAME, NUDGE_INVITE_CODE, teamCreatedAt(today, 14));
        ensureMember(NUDGE_TEAM_ID, DEV_USER_ID, memberId("nudge:owner"), "owner", true);
        ensureMember(NUDGE_TEAM_ID, TEAMMATE_USER_ID, memberId("nudge:shared"), "member", true);
        ensureMember(NUDGE_TEAM_ID, TEAMMATE_TWO_USER_ID, memberId("nudge:available-one"), "member", true);
        ensureMember(NUDGE_TEAM_ID, NUDGED_USER_ID, memberId("nudge:already"), "member", true);
        ensureMember(NUDGE_TEAM_ID, DISABLED_USER_ID, memberId("nudge:disabled"), "member", false);
        ensureMember(NUDGE_TEAM_ID, ELIGIBLE_USER_ID, memberId("nudge:available-two"), "member", true);

        List<SeedWorkout> workouts = seedWorkouts();
        for (SeedWorkout workout : workouts) {
            ensureWorkout(today, workout);
        }
        ensureNudgeValidationData(today, workouts);

        return new SeedResult(DEV_USER_ID, created);
    }

    private boolean ensureUser(UUID userId, String displayName, String email, String sex) {
        AppUser existing = appUserMapper.findByIdIncludingDeleted(userId);
        if (existing == null) {
            AppUser user = new AppUser();
            user.setId(userId);
            user.setDisplayName(displayName);
            user.setFirstLoginEmail(email);
            user.setSex(sex);
            appUserMapper.insert(user);
            return true;
        }
        if (existing.getDeletedAt() != null
                || !displayName.equals(existing.getDisplayName())
                || existing.getFirstLoginEmail() == null
                || existing.getSex() == null) {
            appUserMapper.restoreDevProfile(userId, displayName, email, sex);
        }
        return false;
    }

    private void ensureTeam(UUID teamId, String teamName, String inviteCode, OffsetDateTime createdAt) {
        Team existing = teamMapper.findByIdIncludingDeleted(teamId);
        if (existing == null) {
            Team team = new Team();
            team.setId(teamId);
            team.setName(teamName);
            team.setOwnerUserId(DEV_USER_ID);
            team.setInviteCode(inviteCode);
            team.setCreatedAt(createdAt);
            team.setUpdatedAt(createdAt);
            teamMapper.insert(team);
            return;
        }
        if (existing.getDeletedAt() != null
                || !DEV_USER_ID.equals(existing.getOwnerUserId())
                || !inviteCode.equals(existing.getInviteCode())
                || !teamName.equals(existing.getName())
                || existing.getCreatedAt() == null
                || existing.getCreatedAt().isAfter(createdAt)) {
            teamMapper.restoreDevTeam(teamId, teamName, DEV_USER_ID, inviteCode, createdAt);
        }
    }

    private OffsetDateTime teamCreatedAt(LocalDate today, int daysAgo) {
        return OffsetDateTime.of(today.minusDays(daysAgo), LocalTime.of(9, 0), DEV_OFFSET);
    }

    private void ensureMember(UUID teamId,
                              UUID userId,
                              UUID memberId,
                              String role,
                              boolean receiveTeamNotifications) {
        TeamMember existing = memberMapper.findByTeamAndUser(teamId, userId);
        if (existing == null) {
            TeamMember member = new TeamMember();
            member.setId(memberId);
            member.setTeamId(teamId);
            member.setUserId(userId);
            member.setRole(role);
            member.setJoinedAt(OffsetDateTime.now(DEV_OFFSET).minusDays("owner".equals(role) ? 60 : 14));
            member.setAutoShareWorkouts(true);
            member.setReceiveTeamNotifications(receiveTeamNotifications);
            memberMapper.insert(member);
            return;
        }
        if (!role.equals(existing.getRole())) {
            memberMapper.updateRole(teamId, userId, role);
        }
        // 每次 dev token 登录恢复默认开启基线，便于反复验证开关成功/失败回滚。
        memberMapper.updateAutoShareWorkouts(teamId, userId, true);
        memberMapper.updateReceiveTeamNotifications(teamId, userId, receiveTeamNotifications);
    }

    private void ensureWorkout(LocalDate today, SeedWorkout seed) {
        LocalDate date = today.minusDays(seed.daysAgo());
        OffsetDateTime startedAt = OffsetDateTime.of(date, seed.startTime(), DEV_OFFSET);
        OffsetDateTime endedAt = startedAt.plusMinutes(seed.durationMinutes());
        UUID workoutId = workoutId(seed.key());

        Workout workout = new Workout();
        workout.setId(workoutId);
        workout.setUserId(seed.userId());
        workout.setTitle(seed.title());
        workout.setStartedAt(startedAt);
        workout.setEndedAt(endedAt);
        workout.setNote("本地开发测试数据");
        workout.setUpdatedAt(OffsetDateTime.now(DEV_OFFSET));

        Workout existing = workoutMapper.findByIdIncludingDeleted(workoutId);
        if (existing == null) {
            workoutMapper.insert(workout);
        } else if (existing.getDeletedAt() != null) {
            workoutMapper.restoreDevWorkout(workout);
        }

        ensureWorkoutChildren(seed, workoutId);
        UUID checkinId = ensureCheckin(seed, workoutId, date, endedAt.plusMinutes(2),
                summaryJson(seed, startedAt, endedAt));
        ensureReaction(seed, checkinId, endedAt.plusMinutes(8));
    }

    /**
     * 恢复拍一拍手工验收的固定基线：本人无动态、两人已分享、
     * 一人已拍、一人关闭接收、一人可拍。仅作用于独立的本地验收 Team。
     */
    private void ensureNudgeValidationData(LocalDate today, List<SeedWorkout> workouts) {
        checkinMapper.delete(new LambdaQueryWrapper<TeamCheckin>()
                .eq(TeamCheckin::getTeamId, NUDGE_TEAM_ID)
                .notIn(TeamCheckin::getUserId, List.of(TEAMMATE_USER_ID, TEAMMATE_TWO_USER_ID)));
        nudgeMapper.delete(new LambdaQueryWrapper<TeamNudge>()
                .eq(TeamNudge::getTeamId, NUDGE_TEAM_ID)
                .eq(TeamNudge::getSenderUserId, DEV_USER_ID)
                .eq(TeamNudge::getNudgeDate, today));

        SeedWorkout teammateWorkout = workouts.stream()
                .filter(workout -> "teammate-upper-current".equals(workout.key()))
                .findFirst()
                .orElseThrow();
        SeedWorkout teammateTwoWorkout = workouts.stream()
                .filter(workout -> "teammate-two-conditioning-current".equals(workout.key()))
                .findFirst()
                .orElseThrow();
        ensureNudgeTeamCheckin(today, teammateWorkout);
        ensureNudgeTeamCheckin(today, teammateTwoWorkout);

        TeamNudge nudge = new TeamNudge();
        nudge.setId(id("team-nudge:nudge-validation:" + today));
        nudge.setTeamId(NUDGE_TEAM_ID);
        nudge.setSenderUserId(DEV_USER_ID);
        nudge.setRecipientUserId(NUDGED_USER_ID);
        nudge.setNudgeDate(today);
        nudge.setCreatedAt(OffsetDateTime.now(DEV_OFFSET).minusMinutes(5));
        nudgeMapper.insert(nudge);
    }

    private void ensureNudgeTeamCheckin(LocalDate today, SeedWorkout seed) {
        OffsetDateTime startedAt = OffsetDateTime.of(today, seed.startTime(), DEV_OFFSET);
        OffsetDateTime endedAt = startedAt.plusMinutes(seed.durationMinutes());
        UUID workoutId = workoutId(seed.key());
        String summary = summaryJson(seed, startedAt, endedAt);
        TeamCheckin existing = checkinMapper.findByTeamUserWorkout(
                NUDGE_TEAM_ID, seed.userId(), workoutId);
        if (existing == null) {
            TeamCheckin checkin = new TeamCheckin();
            checkin.setId(id("team-checkin:nudge-validation:" + seed.key()));
            checkin.setTeamId(NUDGE_TEAM_ID);
            checkin.setUserId(seed.userId());
            checkin.setWorkoutId(workoutId);
            checkin.setCheckinDate(today);
            checkin.setSummary(summary);
            checkin.setCreatedAt(endedAt.plusMinutes(2));
            checkinMapper.insert(checkin);
            return;
        }
        existing.setCheckinDate(today);
        existing.setSummary(summary);
        existing.setCreatedAt(endedAt.plusMinutes(2));
        checkinMapper.updateById(existing);
    }

    private void ensureWorkoutChildren(SeedWorkout seed, UUID workoutId) {
        for (int exerciseIndex = 0; exerciseIndex < seed.exercises().size(); exerciseIndex++) {
            SeedExercise seedExercise = seed.exercises().get(exerciseIndex);
            UUID exerciseId = exerciseId(seed.key(), exerciseIndex);
            if (exerciseMapper.selectById(exerciseId) == null) {
                WorkoutExercise exercise = new WorkoutExercise();
                exercise.setId(exerciseId);
                exercise.setWorkoutId(workoutId);
                exercise.setUserId(seed.userId());
                exercise.setBuiltinExerciseCode(seedExercise.code());
                exercise.setExerciseName(seedExercise.name());
                exercise.setPrimaryMuscle(seedExercise.primaryMuscle());
                exercise.setOrderIndex(exerciseIndex);
                exerciseMapper.insert(exercise);
            }

            for (int setIndex = 0; setIndex < seedExercise.sets().size(); setIndex++) {
                SeedSet seedSet = seedExercise.sets().get(setIndex);
                UUID setId = setId(seed.key(), exerciseIndex, setIndex);
                if (setMapper.selectById(setId) == null) {
                    WorkoutSet set = new WorkoutSet();
                    set.setId(setId);
                    set.setWorkoutExerciseId(exerciseId);
                    set.setSetIndex(setIndex);
                    set.setWeightKg(seedSet.weightKg());
                    set.setReps(seedSet.reps());
                    set.setCompleted(true);
                    set.setSetType("working");
                    setMapper.insert(set);
                }
            }
        }
    }

    private UUID ensureCheckin(SeedWorkout seed,
                               UUID workoutId,
                               LocalDate date,
                               OffsetDateTime createdAt,
                               String summary) {
        TeamCheckin existing = checkinMapper.findByTeamUserWorkout(TEAM_ID, seed.userId(), workoutId);
        if (existing != null) {
            return existing.getId();
        }

        TeamCheckin checkin = new TeamCheckin();
        checkin.setId(checkinId(seed.key()));
        checkin.setTeamId(TEAM_ID);
        checkin.setUserId(seed.userId());
        checkin.setWorkoutId(workoutId);
        checkin.setCheckinDate(date);
        checkin.setSummary(summary);
        checkin.setCreatedAt(createdAt);
        checkinMapper.insert(checkin);
        return checkin.getId();
    }

    private void ensureReaction(SeedWorkout seed, UUID checkinId, OffsetDateTime createdAt) {
        UUID reactorUserId = DEV_USER_ID.equals(seed.userId()) ? TEAMMATE_USER_ID : DEV_USER_ID;
        if (reactionMapper.findByCheckinAndUser(checkinId, reactorUserId) != null) {
            return;
        }

        CheckinReaction reaction = new CheckinReaction();
        reaction.setId(reactionId(seed.key()));
        reaction.setCheckinId(checkinId);
        reaction.setUserId(reactorUserId);
        reaction.setEmoji(seed.reactionEmoji());
        reaction.setCreatedAt(createdAt);
        reaction.setUpdatedAt(createdAt);
        reactionMapper.insert(reaction);
    }

    private String summaryJson(SeedWorkout seed, OffsetDateTime startedAt, OffsetDateTime endedAt) {
        List<Map<String, Object>> exercises = new ArrayList<>();
        int totalSets = 0;
        BigDecimal totalVolumeKg = BigDecimal.ZERO;

        for (SeedExercise exercise : seed.exercises()) {
            List<Map<String, Object>> sets = new ArrayList<>();
            for (SeedSet set : exercise.sets()) {
                totalSets++;
                if (set.weightKg() != null) {
                    totalVolumeKg = totalVolumeKg.add(set.weightKg().multiply(BigDecimal.valueOf(set.reps())));
                }
                Map<String, Object> setMap = new LinkedHashMap<>();
                setMap.put("weightKg", set.weightKg());
                setMap.put("reps", set.reps());
                sets.add(setMap);
            }
            Map<String, Object> exerciseMap = new LinkedHashMap<>();
            exerciseMap.put("name", exercise.name());
            exerciseMap.put("sets", sets);
            exercises.add(exerciseMap);
        }

        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("title", seed.title());
        summary.put("startedAt", startedAt);
        summary.put("endedAt", endedAt);
        summary.put("exerciseCount", seed.exercises().size());
        summary.put("totalSets", totalSets);
        summary.put("totalVolumeKg", totalVolumeKg);
        summary.put("exercises", exercises);

        try {
            return objectMapper.writeValueAsString(summary);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("生成本地开发打卡快照失败", e);
        }
    }

    private static List<SeedWorkout> seedWorkouts() {
        return List.of(
                new SeedWorkout("owner-push-current", DEV_USER_ID, 0, LocalTime.of(19, 5), 68,
                        "推日 A · 胸肩三头", "fire", List.of(
                        ex("barbell_bench_press", "平板杠铃卧推", "胸",
                                set("60", 10), set("75", 8), set("82.5", 6), set("82.5", 5)),
                        ex("dumbbell_shoulder_press", "哑铃肩推", "肩",
                                set("24", 10), set("26", 8), set("26", 8)),
                        ex("cable_triceps_pushdown", "绳索下压", "手臂",
                                set("35", 12), set("40", 10), set("40", 10)))),
                new SeedWorkout("teammate-upper-current", TEAMMATE_USER_ID, 0, LocalTime.of(12, 20), 47,
                        "午间上肢泵感", "heart", List.of(
                        ex("machine_chest_press", "器械推胸", "胸",
                                set("55", 12), set("60", 10), set("60", 10)),
                        ex("seated_cable_row", "坐姿划船", "背",
                                set("55", 12), set("60", 10), set("60", 10)),
                        ex("rope_face_pull", "绳索面拉", "肩",
                                set("25", 15), set("30", 12)))),
                new SeedWorkout("teammate-two-conditioning-current", TEAMMATE_TWO_USER_ID, 0, LocalTime.of(7, 45), 39,
                        "晨间全身循环", "clap", List.of(
                        ex("kettlebell_swing", "壶铃摆动", "腿",
                                set("24", 15), set("24", 15), set("28", 12)),
                        ex("push_up", "俯卧撑", "胸", body(20), body(18), body(15)),
                        ex("goblet_squat", "高脚杯深蹲", "腿",
                                set("28", 12), set("32", 10)))),
                new SeedWorkout("teammate-leg-current", TEAMMATE_USER_ID, 1, LocalTime.of(7, 30), 74,
                        "腿日 · 深蹲主项", "clap", List.of(
                        ex("barbell_back_squat", "杠铃深蹲", "腿",
                                set("80", 8), set("100", 6), set("110", 5), set("110", 5)),
                        ex("romanian_deadlift", "罗马尼亚硬拉", "腿",
                                set("80", 8), set("90", 8), set("90", 8)),
                        ex("leg_press", "腿举", "腿",
                                set("180", 12), set("200", 10), set("200", 10)))),
                new SeedWorkout("owner-accessory-day-one", DEV_USER_ID, 1, LocalTime.of(18, 50), 51,
                        "肩臂辅助", "muscle", List.of(
                        ex("standing_overhead_press", "站姿推举", "肩",
                                set("40", 8), set("45", 6), set("45", 6)),
                        ex("dumbbell_lateral_raise", "哑铃侧平举", "肩",
                                set("10", 14), set("10", 12), set("12", 10)),
                        ex("ez_bar_curl", "EZ 杠弯举", "手臂",
                                set("25", 10), set("25", 10)))),
                new SeedWorkout("teammate-two-back-day-one", TEAMMATE_TWO_USER_ID, 1, LocalTime.of(20, 15), 55,
                        "背部技术日", "fire", List.of(
                        ex("pull_up", "引体向上", "背", body(7), body(6), body(5)),
                        ex("chest_supported_row", "俯身支撑划船", "背",
                                set("50", 10), set("55", 8), set("55", 8)),
                        ex("straight_arm_pulldown", "直臂下拉", "背",
                                set("30", 12), set("35", 10)))),
                new SeedWorkout("teammate-two-push-week", TEAMMATE_TWO_USER_ID, 2, LocalTime.of(18, 15), 56,
                        "推日 · 轻重量容量", "heart", List.of(
                        ex("incline_barbell_bench_press", "上斜杠铃卧推", "胸",
                                set("50", 10), set("55", 8), set("55", 8)),
                        ex("machine_shoulder_press", "器械肩推", "肩",
                                set("40", 12), set("45", 10), set("45", 10)),
                        ex("dumbbell_lateral_raise", "哑铃侧平举", "肩",
                                set("8", 15), set("10", 12), set("10", 12)))),
                new SeedWorkout("owner-pull-day-two", DEV_USER_ID, 2, LocalTime.of(7, 25), 59,
                        "早训背二头", "clap", List.of(
                        ex("lat_pulldown", "高位下拉", "背",
                                set("55", 10), set("60", 8), set("60", 8)),
                        ex("single_arm_dumbbell_row", "单臂哑铃划船", "背",
                                set("32", 10), set("34", 8), set("34", 8)),
                        ex("hammer_curl", "锤式弯举", "手臂",
                                set("16", 10), set("18", 8)))),
                new SeedWorkout("teammate-leg-day-two", TEAMMATE_USER_ID, 2, LocalTime.of(12, 40), 63,
                        "腿部容量补课", "muscle", List.of(
                        ex("front_squat", "前蹲", "腿",
                                set("60", 8), set("70", 6), set("70", 6)),
                        ex("leg_extension", "腿屈伸", "腿",
                                set("45", 12), set("50", 10), set("50", 10)),
                        ex("seated_leg_curl", "坐姿腿弯举", "腿",
                                set("45", 12), set("50", 10)))),
                new SeedWorkout("teammate-pull-week", TEAMMATE_USER_ID, 3, LocalTime.of(20, 5), 61,
                        "背部容量训练", "muscle", List.of(
                        ex("lat_pulldown", "高位下拉", "背",
                                set("50", 12), set("55", 10), set("60", 8)),
                        ex("seated_cable_row", "坐姿划船", "背",
                                set("55", 12), set("60", 10), set("65", 8)),
                        ex("face_pull", "面拉", "肩",
                                set("25", 15), set("30", 12), set("30", 12)))),
                new SeedWorkout("owner-push-day-three", DEV_USER_ID, 3, LocalTime.of(8, 0), 54,
                        "推日技术组", "heart", List.of(
                        ex("close_grip_bench_press", "窄握卧推", "胸",
                                set("55", 10), set("65", 8), set("65", 8)),
                        ex("dips", "双杠臂屈伸", "胸", body(10), body(9), body(8)),
                        ex("cable_triceps_extension", "绳索臂屈伸", "手臂",
                                set("30", 12), set("35", 10)))),
                new SeedWorkout("teammate-two-lower-day-three", TEAMMATE_TWO_USER_ID, 3, LocalTime.of(18, 30), 66,
                        "下肢力量维持", "fire", List.of(
                        ex("barbell_back_squat", "杠铃深蹲", "腿",
                                set("75", 8), set("90", 6), set("95", 5)),
                        ex("romanian_deadlift", "罗马尼亚硬拉", "腿",
                                set("75", 8), set("85", 8), set("85", 8)),
                        ex("calf_raise", "提踵", "腿",
                                set("60", 15), set("70", 12)))),
                new SeedWorkout("owner-pull-week", DEV_USER_ID, 4, LocalTime.of(18, 40), 62,
                        "拉日 · 背二头", "muscle", List.of(
                        ex("pull_up", "引体向上", "背", body(8), body(7), body(6)),
                        ex("barbell_row", "杠铃划船", "背",
                                set("70", 8), set("75", 8), set("75", 7)),
                        ex("dumbbell_curl", "哑铃弯举", "手臂",
                                set("16", 10), set("16", 10), set("18", 8)))),
                new SeedWorkout("teammate-push-day-four", TEAMMATE_USER_ID, 4, LocalTime.of(7, 55), 48,
                        "胸肩短课", "clap", List.of(
                        ex("incline_dumbbell_press", "上斜哑铃卧推", "胸",
                                set("22", 10), set("24", 9), set("24", 8)),
                        ex("arnold_press", "阿诺德推举", "肩",
                                set("16", 10), set("18", 8), set("18", 8)),
                        ex("lateral_raise", "侧平举", "肩",
                                set("8", 15), set("10", 12)))),
                new SeedWorkout("teammate-two-back-day-four", TEAMMATE_TWO_USER_ID, 4, LocalTime.of(21, 0), 52,
                        "夜训背部", "heart", List.of(
                        ex("seated_cable_row", "坐姿划船", "背",
                                set("55", 12), set("60", 10), set("60", 10)),
                        ex("lat_pulldown", "高位下拉", "背",
                                set("50", 12), set("55", 10), set("55", 10)),
                        ex("rear_delt_fly", "反向飞鸟", "肩",
                                set("12", 15), set("12", 15)))),
                new SeedWorkout("teammate-two-lower-week", TEAMMATE_TWO_USER_ID, 5, LocalTime.of(8, 10), 69,
                        "腿日 · 臀腿辅助", "fire", List.of(
                        ex("front_squat", "前蹲", "腿",
                                set("60", 8), set("70", 6), set("70", 6)),
                        ex("hip_thrust", "臀推", "腿",
                                set("90", 10), set("100", 8), set("100", 8)),
                        ex("walking_lunge", "行走弓步", "腿",
                                set("20", 12), set("20", 12)))),
                new SeedWorkout("owner-fullbody-day-five", DEV_USER_ID, 5, LocalTime.of(12, 10), 46,
                        "全身维持训练", "heart", List.of(
                        ex("trap_bar_deadlift", "六角杠硬拉", "背",
                                set("90", 8), set("100", 6), set("100", 6)),
                        ex("dumbbell_bench_press", "哑铃卧推", "胸",
                                set("26", 10), set("28", 8), set("28", 8)),
                        ex("cable_row", "绳索划船", "背",
                                set("55", 12), set("60", 10)))),
                new SeedWorkout("teammate-upper-day-five", TEAMMATE_USER_ID, 5, LocalTime.of(19, 40), 57,
                        "上肢密度训练", "muscle", List.of(
                        ex("bench_press", "卧推", "胸",
                                set("50", 10), set("60", 8), set("60", 7)),
                        ex("one_arm_cable_row", "单臂绳索划船", "背",
                                set("30", 12), set("35", 10), set("35", 10)),
                        ex("rope_pushdown", "绳索下压", "手臂",
                                set("35", 12), set("40", 10)))),
                new SeedWorkout("teammate-conditioning-week", TEAMMATE_USER_ID, 6, LocalTime.of(12, 45), 44,
                        "午间全身循环", "clap", List.of(
                        ex("goblet_squat", "高脚杯深蹲", "腿",
                                set("28", 12), set("32", 10), set("32", 10)),
                        ex("push_up", "俯卧撑", "胸", body(18), body(16), body(14)),
                        ex("kettlebell_swing", "壶铃摆动", "腿",
                                set("24", 15), set("24", 15), set("24", 15)))),
                new SeedWorkout("owner-squat-day-six", DEV_USER_ID, 6, LocalTime.of(8, 35), 64,
                        "深蹲容量日", "fire", List.of(
                        ex("barbell_back_squat", "杠铃深蹲", "腿",
                                set("80", 8), set("95", 6), set("100", 5)),
                        ex("leg_press", "腿举", "腿",
                                set("180", 12), set("200", 10), set("200", 10)),
                        ex("calf_raise", "提踵", "腿",
                                set("60", 15), set("70", 12)))),
                new SeedWorkout("teammate-two-pull-day-six", TEAMMATE_TWO_USER_ID, 6, LocalTime.of(19, 15), 53,
                        "背二头轻课", "heart", List.of(
                        ex("neutral_grip_pulldown", "中立握下拉", "背",
                                set("50", 12), set("55", 10), set("55", 10)),
                        ex("dumbbell_row", "哑铃划船", "背",
                                set("30", 10), set("32", 10), set("32", 8)),
                        ex("incline_dumbbell_curl", "上斜哑铃弯举", "手臂",
                                set("12", 12), set("14", 10)))),
                new SeedWorkout("teammate-upper-week", TEAMMATE_USER_ID, 9, LocalTime.of(20, 10), 58,
                        "上肢容量", "heart", List.of(
                        ex("incline_dumbbell_press", "上斜哑铃卧推", "胸",
                                set("24", 10), set("26", 9), set("26", 8)),
                        ex("seated_cable_row", "坐姿划船", "背",
                                set("55", 12), set("60", 10), set("60", 10)),
                        ex("dumbbell_lateral_raise", "哑铃侧平举", "肩",
                                set("10", 14), set("10", 13), set("10", 12)))),
                new SeedWorkout("owner-lower-month", DEV_USER_ID, 17, LocalTime.of(12, 20), 65,
                        "腿后侧强化", "clap", List.of(
                        ex("deadlift", "硬拉", "背",
                                set("100", 5), set("120", 5), set("130", 3)),
                        ex("bulgarian_split_squat", "保加利亚分腿蹲", "腿",
                                set("22", 10), set("22", 10), set("24", 8)),
                        ex("seated_leg_curl", "坐姿腿弯举", "腿",
                                set("45", 12), set("50", 10), set("50", 10)))),
                new SeedWorkout("teammate-previous-month", TEAMMATE_USER_ID, 34, LocalTime.of(18, 0), 52,
                        "上月拉伸恢复训练", "fire", List.of(
                        ex("lat_pulldown", "高位下拉", "背",
                                set("45", 12), set("50", 10), set("50", 10)),
                        ex("machine_chest_press", "器械推胸", "胸",
                                set("50", 12), set("55", 10), set("55", 10)),
                        ex("face_pull", "面拉", "肩",
                                set("25", 15), set("25", 15)))));
    }

    private static SeedExercise ex(String code, String name, String primaryMuscle, SeedSet... sets) {
        return new SeedExercise(code, name, primaryMuscle, List.of(sets));
    }

    private static SeedSet set(String weightKg, int reps) {
        return new SeedSet(new BigDecimal(weightKg), reps);
    }

    private static SeedSet body(int reps) {
        return new SeedSet(null, reps);
    }

    private static UUID memberId(String key) {
        return id("team-member:" + key);
    }

    private static UUID workoutId(String key) {
        return id("workout:" + key);
    }

    private static UUID exerciseId(String key, int exerciseIndex) {
        return id("workout-exercise:" + key + ":" + exerciseIndex);
    }

    private static UUID setId(String key, int exerciseIndex, int setIndex) {
        return id("workout-set:" + key + ":" + exerciseIndex + ":" + setIndex);
    }

    private static UUID checkinId(String key) {
        return id("team-checkin:" + key);
    }

    private static UUID reactionId(String key) {
        return id("checkin-reaction:" + key);
    }

    private static UUID id(String key) {
        return UUID.nameUUIDFromBytes(("dontlift-dev-seed:" + key).getBytes(StandardCharsets.UTF_8));
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    public record SeedResult(UUID userId, boolean created) {
    }

    private record SeedWorkout(String key,
                               UUID userId,
                               int daysAgo,
                               LocalTime startTime,
                               int durationMinutes,
                               String title,
                               String reactionEmoji,
                               List<SeedExercise> exercises) {
    }

    private record SeedExercise(String code,
                                String name,
                                String primaryMuscle,
                                List<SeedSet> sets) {
    }

    private record SeedSet(BigDecimal weightKg, int reps) {
    }
}
