package com.dontlift.account;

import com.dontlift.account.dto.DeletionImpact;
import com.dontlift.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 账号自助管理。JWT 即身份，所有操作仅作用于当前登录用户。
 * 写接口（DELETE）遵守全站幂等键铁律：客户端带 Idempotency-Key；天然幂等（重复删除为空操作）。
 */
@RestController
@RequestMapping("/account")
@RequiredArgsConstructor
public class AccountController {

    private final AccountDeletionService accountDeletionService;

    /** 删除自身账号（物理硬删本人数据 + 多人 Team 转移 owner + 尽力撤销 Apple 授权）。 */
    @DeleteMapping
    public ResponseEntity<Void> deleteSelf() {
        accountDeletionService.deleteSelf(SecurityUtils.currentUserId());
        return ResponseEntity.noContent().build();
    }

    /** 删号影响面预览（只读）：返回 owner 转移、空 Team 删除与受影响成员摘要，供二次确认框展示。 */
    @GetMapping("/deletion-impact")
    public DeletionImpact deletionImpact() {
        return accountDeletionService.impact(SecurityUtils.currentUserId());
    }
}
