package com.dontlift.account.dto;

/**
 * 删号影响面预览（D7）：供客户端二次确认框展示真实后果。
 * @param ownedTeamsToTransfer 本人作为 owner、删号时将保留并转移 owner 的多人 Team 数
 * @param emptyOwnedTeamsToDelete 本人作为 owner 且无其他成员、删号时将删除的空 Team 数
 * @param affectedMembers 这些 Team 中除本人外的去重成员数
 */
public record DeletionImpact(int ownedTeamsToTransfer, int emptyOwnedTeamsToDelete, int affectedMembers) {
}
