package com.dontlift.account;

import com.dontlift.account.dto.ProfileResponse;
import com.dontlift.account.entity.AppUser;
import com.dontlift.account.mapper.AppUserMapper;
import com.dontlift.common.web.AppException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProfileServiceTest {

    @Mock AppUserMapper appUserMapper;
    @InjectMocks ProfileService service;

    private final ObjectMapper om = new ObjectMapper();
    private final UUID userId = UUID.randomUUID();

    private AppUser user(String name, String sex) {
        AppUser u = new AppUser();
        u.setId(userId);
        u.setDisplayName(name);
        u.setSex(sex);
        u.setFirstLoginEmail("a@b.com");
        return u;
    }

    private JsonNode body(String json) {
        try {
            return om.readTree(json);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    /** GET /me：字段完整回灌；sex 未设置时原样回传 null（不兜底），由客户端保留本地。 */
    @Test
    void me_returnsCompleteProfile_keepsSexNullWhenUnset() {
        when(appUserMapper.selectById(userId)).thenReturn(user("阿强", null));

        ProfileResponse r = service.me(userId);

        assertThat(r.userId()).isEqualTo(userId);
        assertThat(r.displayName()).isEqualTo("阿强");
        assertThat(r.sex()).isNull();
        assertThat(r.email()).isEqualTo("a@b.com");
    }

    /** GET /me：sex 已设置时原样回传。 */
    @Test
    void me_returnsSetSex() {
        when(appUserMapper.selectById(userId)).thenReturn(user("阿强", "female"));

        assertThat(service.me(userId).sex()).isEqualTo("female");
    }

    /** PATCH 部分更新：仅含 sex 时称呼保持原值。 */
    @Test
    void update_partialOnlySex_keepsDisplayName() {
        AppUser u = user("阿强", "male");
        when(appUserMapper.selectById(userId)).thenReturn(u);

        ProfileResponse r = service.update(userId, body("{\"sex\":\"female\"}"));

        assertThat(r.sex()).isEqualTo("female");
        assertThat(r.displayName()).isEqualTo("阿强");
        verify(appUserMapper).updateById(u);
    }

    /** 称呼去空白后写入。 */
    @Test
    void update_trimsDisplayName() {
        AppUser u = user(null, "male");
        when(appUserMapper.selectById(userId)).thenReturn(u);

        ProfileResponse r = service.update(userId, body("{\"displayName\":\"  小美  \"}"));

        assertThat(r.displayName()).isEqualTo("小美");
    }

    /** 称呼空白被拒（400），不落库。 */
    @Test
    void update_rejectsBlankDisplayName() {
        when(appUserMapper.selectById(userId)).thenReturn(user(null, "male"));

        assertThatThrownBy(() -> service.update(userId, body("{\"displayName\":\"   \"}")))
                .isInstanceOf(AppException.class);
        verify(appUserMapper, never()).updateById(any(AppUser.class));
    }

    /** 称呼超 20 字符被拒。 */
    @Test
    void update_rejectsTooLongDisplayName() {
        when(appUserMapper.selectById(userId)).thenReturn(user(null, "male"));
        String longName = "\"" + "字".repeat(21) + "\"";

        assertThatThrownBy(() -> service.update(userId, body("{\"displayName\":" + longName + "}")))
                .isInstanceOf(AppException.class);
        verify(appUserMapper, never()).updateById(any(AppUser.class));
    }

    /** 性别枚举非法被拒。 */
    @Test
    void update_rejectsInvalidSex() {
        when(appUserMapper.selectById(userId)).thenReturn(user("阿强", "male"));

        assertThatThrownBy(() -> service.update(userId, body("{\"sex\":\"other\"}")))
                .isInstanceOf(AppException.class);
        verify(appUserMapper, never()).updateById(any(AppUser.class));
    }

    /** 称呼缺省（字段不出现）时不改动既有称呼。 */
    @Test
    void update_absentDisplayNameLeavesItUnchanged() {
        AppUser u = user("老名字", "male");
        when(appUserMapper.selectById(userId)).thenReturn(u);

        ProfileResponse r = service.update(userId, body("{\"sex\":\"female\"}"));

        assertThat(r.displayName()).isEqualTo("老名字");
    }

    /** 用户不存在抛 notFound。 */
    @Test
    void update_throwsWhenUserMissing() {
        when(appUserMapper.selectById(userId)).thenReturn(null);

        assertThatThrownBy(() -> service.update(userId, body("{\"sex\":\"male\"}")))
                .isInstanceOf(AppException.class);
    }
}
