package com.meigei.config;

import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import org.apache.ibatis.reflection.MetaObject;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;

/**
 * 自动填充：插入时补 createdAt/updatedAt/version，更新时刷新 updatedAt。
 * id 不在此填充——它是 IdType.INPUT，由应用层（客户端预生成或服务端 Uuid7）显式赋值。
 */
@Component
public class MetaObjectHandlerImpl implements MetaObjectHandler {

    @Override
    public void insertFill(MetaObject metaObject) {
        OffsetDateTime now = OffsetDateTime.now();
        fillIfNull(metaObject, "createdAt", now);
        fillIfNull(metaObject, "updatedAt", now);
        fillIfNull(metaObject, "version", 0);
    }

    @Override
    public void updateFill(MetaObject metaObject) {
        // 仅在未提供时填 now()：同步写入保留客户端编辑时间（LWW 比较基准）；
        // 服务端权威更新若需刷新 updatedAt，由 service 显式设置。
        fillIfNull(metaObject, "updatedAt", OffsetDateTime.now());
    }

    private void fillIfNull(MetaObject metaObject, String field, Object value) {
        if (metaObject.hasGetter(field) && getFieldValByName(field, metaObject) == null) {
            setFieldValByName(field, value, metaObject);
        }
    }
}
