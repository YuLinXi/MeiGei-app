package com.dontlift.team;

import com.dontlift.common.web.AppException;
import com.dontlift.security.SecurityUtils;
import com.dontlift.team.dto.TeamRequests.CheckIn;
import com.dontlift.team.dto.TeamRequests.React;
import com.dontlift.team.dto.TeamCheckinFeed;
import com.dontlift.team.entity.CheckinReaction;
import com.dontlift.team.entity.TeamCheckin;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.UUID;

/** 训练分享打卡与表情回应（5.4）。 */
@RestController
@RequiredArgsConstructor
public class CheckinController {

    private final CheckinService checkinService;

    /** 保存训练后打卡：仅分享到用户显式选择的 Team。配合 Idempotency-Key 头防重。 */
    @PostMapping("/checkins")
    public List<TeamCheckin> checkIn(@Valid @RequestBody CheckIn req) {
        return checkinService.checkIn(SecurityUtils.currentUserId(),
                req.workoutId(), req.checkinDate(), req.summary().toString(), req.teamIds());
    }

    /** 撤回某次训练在单个 Team 的可见性；个人训练记录不受影响。 */
    @DeleteMapping("/teams/{teamId}/checkins/workouts/{workoutId}")
    public void withdrawCheckin(@PathVariable UUID teamId, @PathVariable UUID workoutId) {
        checkinService.withdraw(SecurityUtils.currentUserId(), teamId, workoutId);
    }

    @GetMapping("/teams/{teamId}/checkins")
    public List<TeamCheckin> listCheckins(
            @PathVariable UUID teamId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return checkinService.listCheckins(SecurityUtils.currentUserId(), teamId, date);
    }

    @GetMapping("/teams/{teamId}/checkins/feed")
    public TeamCheckinFeed listCheckinFeed(
            @PathVariable UUID teamId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return checkinService.listCheckinFeed(SecurityUtils.currentUserId(), teamId, date);
    }

    @GetMapping("/teams/{teamId}/checkins/history")
    public TeamCheckinFeed listCheckinHistory(@PathVariable UUID teamId, @RequestParam String month) {
        try {
            return checkinService.listCheckinHistory(SecurityUtils.currentUserId(), teamId, YearMonth.parse(month));
        } catch (DateTimeParseException e) {
            throw AppException.badRequest("month 必须为 yyyy-MM");
        }
    }

    @PostMapping("/checkins/{checkinId}/reactions")
    public CheckinReaction react(@PathVariable UUID checkinId,
                                 @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
                                 @Valid @RequestBody React req) {
        requireIdempotencyKey(idempotencyKey);
        return checkinService.react(SecurityUtils.currentUserId(), checkinId, req.emoji());
    }

    @GetMapping("/checkins/{checkinId}/reactions")
    public List<CheckinReaction> listReactions(@PathVariable UUID checkinId) {
        return checkinService.listReactions(SecurityUtils.currentUserId(), checkinId);
    }

    private void requireIdempotencyKey(String idempotencyKey) {
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            throw AppException.badRequest("缺少 Idempotency-Key");
        }
    }
}
