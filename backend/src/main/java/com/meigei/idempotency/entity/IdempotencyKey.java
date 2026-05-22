package com.meigei.idempotency.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@TableName("idempotency_key")
public class IdempotencyKey {

    @TableId(type = IdType.INPUT)
    private UUID id;

    private UUID userId;

    private String idemKey;

    private String requestHash;

    private Integer responseStatus;

    /** jsonb 列；datasource stringtype=unspecified 允许 String 隐式入库。 */
    private String responseBody;

    @TableField(fill = FieldFill.INSERT)
    private OffsetDateTime createdAt;
}
