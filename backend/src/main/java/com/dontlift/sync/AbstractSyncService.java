package com.dontlift.sync;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.dontlift.common.entity.BaseEntity;
import com.dontlift.sync.dto.SyncConflict;
import com.dontlift.sync.dto.SyncPullResult;
import com.dontlift.sync.dto.SyncPushResult;
import com.dontlift.sync.dto.SyncTimestampAdjustment;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * 通用同步协议骨架（D2/D3/D4）：增量拉取 + 批量上传 + last-write-wins。
 *
 * <p>因 @TableLogic 会让标准 select 过滤掉软删行，而同步必须下发墓碑，
 * 故下拉/按 id 取值用子类提供的「含墓碑」原始查询（自定义 SQL）实现。
 * 具体实体的子类与 SQL 在各领域任务（训练）中实现并对真实库验证。
 *
 * @param <T> 同步聚合根，需带同步信封并标记归属
 */
public abstract class AbstractSyncService<T extends BaseEntity & UserOwned> {

    protected final BaseMapper<T> mapper;
    private final String syncDomain;

    protected AbstractSyncService(BaseMapper<T> mapper, String syncDomain) {
        this.mapper = mapper;
        this.syncDomain = syncDomain;
    }

    /** 子类实现：本用户自 since 起的全部变更（含软删墓碑）。since 为 null 视为全量。 */
    protected abstract List<T> findChangesSince(UUID userId, OffsetDateTime since);

    /** 子类实现：按 id 取值，含软删行（用于上传时判断 insert vs update）。 */
    protected abstract T findByIdIncludingDeleted(UUID id);

    /**
     * 子类实现：把行标记为软删（写入 item 的 deletedAt/updatedAt，version 取 serverVersion+1）。
     * 必须用自定义 SQL，因 MyBatis-Plus updateById 不会写 @TableLogic 字段，
     * 否则删除无法作为墓碑下发给其他设备（D2/D3）。
     */
    protected abstract void softDelete(T item, int serverVersion);

    /** 增量下拉。 */
    public SyncPullResult<T> pull(UUID userId, OffsetDateTime since) {
        return new SyncPullResult<>(findChangesSince(userId, since), OffsetDateTime.now());
    }

    /** 批量上传 + LWW。客户端编辑时间（updatedAt）较新或相等则覆盖服务端，否则记为冲突。 */
    public SyncPushResult<T> push(UUID userId, List<T> incoming) {
        OffsetDateTime serverTime = OffsetDateTime.now();
        List<UUID> applied = new ArrayList<>();
        List<SyncConflict<T>> conflicts = new ArrayList<>();
        List<SyncTimestampAdjustment> timestampAdjustments = new ArrayList<>();

        for (T item : incoming) {
            item.setUserId(userId); // 强制归属，忽略客户端伪造的 userId
            SyncTimestampGuard.Decision timestamp = SyncTimestampGuard.normalize(
                    item.getId(), syncDomain, item.getUpdatedAt(), serverTime);
            if (timestamp.adjusted()) {
                item.setUpdatedAt(timestamp.effectiveUpdatedAt());
                item.setDeletedAt(SyncTimestampGuard.normalizeDeletedAt(item.getDeletedAt(), timestamp.effectiveUpdatedAt()));
                timestampAdjustments.add(timestamp.adjustment());
            }
            T server = findByIdIncludingDeleted(item.getId());

            if (server == null) {
                mapper.insert(item);
                applied.add(item.getId());
                continue;
            }

            boolean incomingWins = !server.getUpdatedAt().isAfter(timestamp.lwwUpdatedAt());
            if (incomingWins) {
                if (item.getDeletedAt() != null) {
                    softDelete(item, server.getVersion()); // 墓碑：updateById 写不动 @TableLogic 字段
                } else {
                    item.setVersion(server.getVersion()); // 通过乐观锁校验
                    mapper.updateById(item);
                }
                applied.add(item.getId());
            } else {
                conflicts.add(new SyncConflict<>(item.getId(), server));
            }
        }

        return new SyncPushResult<>(applied, conflicts, serverTime, timestampAdjustments);
    }
}
