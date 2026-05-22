package com.meigei.common.id;

import com.github.f4b6a3.uuid.UuidCreator;

import java.util.UUID;

/**
 * UUID v7 生成器。时间有序，利于 B-Tree 主键插入局部性。
 * 同步实体的 id 由 iOS 客户端离线预生成（localId == serverId）；
 * 服务端权威实体（team*）在写入前用本类生成。
 */
public final class Uuid7 {

    private Uuid7() {
    }

    public static UUID generate() {
        return UuidCreator.getTimeOrderedEpoch();
    }
}
