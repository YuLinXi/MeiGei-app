package com.dontlift.common.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 同步信封基类：离线优先 + 云同步的聚合根表统一继承。
 * id 为 UUID v7、IdType.INPUT —— 由应用层赋值（客户端预生成或服务端 {@code Uuid7.generate()}），
 * 不依赖 ORM 自动生成，契合 localId == serverId。
 * updatedAt 为 last-write-wins 比较基准；deletedAt 为软删墓碑；version 为乐观锁。
 */
@Data
public abstract class BaseEntity {

    @TableId(type = IdType.INPUT)
    private UUID id;

    @TableField(fill = FieldFill.INSERT)
    private OffsetDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private OffsetDateTime updatedAt;

    @TableLogic
    private OffsetDateTime deletedAt;

    @Version
    @TableField(fill = FieldFill.INSERT)
    private Integer version;
}
