package com.dontlift.sync;

import java.util.UUID;

/** 同步实体的归属标记，供同步引擎强制 user 归属、过滤本人数据。 */
public interface UserOwned {

    UUID getUserId();

    void setUserId(UUID userId);
}
