package com.meigei.team;

import com.meigei.security.SecurityUtils;
import com.meigei.team.dto.TeamRequests.CheckIn;
import com.meigei.team.dto.TeamRequests.React;
import com.meigei.team.entity.CheckinReaction;
import com.meigei.team.entity.TeamCheckin;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** 训练即打卡与表情回应（5.4）。 */
@RestController
@RequiredArgsConstructor
public class CheckinController {

    private final CheckinService checkinService;

    /** 保存训练后打卡：fan-out 到本人所有 Team。配合 Idempotency-Key 头防重。 */
    @PostMapping("/checkins")
    public List<TeamCheckin> checkIn(@Valid @RequestBody CheckIn req) {
        return checkinService.checkIn(SecurityUtils.currentUserId(),
                req.workoutId(), req.checkinDate(), req.summary().toString());
    }

    @GetMapping("/teams/{teamId}/checkins")
    public List<TeamCheckin> listCheckins(
            @PathVariable UUID teamId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return checkinService.listCheckins(SecurityUtils.currentUserId(), teamId, date);
    }

    @PostMapping("/checkins/{checkinId}/reactions")
    public CheckinReaction react(@PathVariable UUID checkinId, @Valid @RequestBody React req) {
        return checkinService.react(SecurityUtils.currentUserId(), checkinId, req.emoji());
    }

    @GetMapping("/checkins/{checkinId}/reactions")
    public List<CheckinReaction> listReactions(@PathVariable UUID checkinId) {
        return checkinService.listReactions(SecurityUtils.currentUserId(), checkinId);
    }
}
