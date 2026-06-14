package com.dontlift.account.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.dontlift.common.entity.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 业务主体（D1 身份三层模型的根）。Apple sub 绝不作主键，登录方式挂在 user_identity。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("app_user")
public class AppUser extends BaseEntity {

    private String displayName;

    /** 首登邮箱，持久化用于账号恢复线索。 */
    private String firstLoginEmail;

    /** 生理性别（资料 + 驱动肌群图底图），取值 male/female，可空（null=未设置）。 */
    private String sex;
}
