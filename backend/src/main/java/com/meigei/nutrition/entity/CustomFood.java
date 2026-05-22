package com.meigei.nutrition.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.meigei.common.entity.BaseEntity;
import com.meigei.sync.UserOwned;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * 用户自定义食材（搜不到权威库时补充）。source 仅 'personal'，
 * 权威库为内置 seed 目录不入库。7 项营养素按 unitBasis（默认 100g）计。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("custom_food")
public class CustomFood extends BaseEntity implements UserOwned {

    private UUID userId;

    private String name;

    private String source;

    private String unitBasis;

    private BigDecimal kcal;

    private BigDecimal proteinG;

    private BigDecimal carbG;

    private BigDecimal fatG;

    private BigDecimal fiberG;

    private BigDecimal sugarG;

    private BigDecimal sodiumMg;
}
