package com.dontlift.account.dto;

/**
 * 删号影响面预览（D7）：供客户端二次确认框展示真实后果。
 * @param ownedTeams      本人作为 owner、删号时将被解散的团队数
 * @param affectedMembers 这些团队中除本人外受影响的去重成员数
 */
public record DeletionImpact(int ownedTeams, int affectedMembers) {
}
