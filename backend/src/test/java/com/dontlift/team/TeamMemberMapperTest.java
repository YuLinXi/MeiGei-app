package com.dontlift.team;

import com.dontlift.team.entity.TeamMember;
import com.dontlift.team.mapper.TeamMemberMapper;
import org.apache.ibatis.annotations.Select;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.lang.reflect.ParameterizedType;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class TeamMemberMapperTest {

    @Test
    void customTeamMemberQueriesMapLegacyNotificationColumn() {
        List<String> queries = Arrays.stream(TeamMemberMapper.class.getDeclaredMethods())
                .filter(this::returnsTeamMember)
                .map(method -> method.getAnnotation(Select.class))
                .map(select -> String.join(" ", select.value()))
                .toList();

        assertThat(queries)
                .hasSize(4)
                .allSatisfy(query -> assertThat(query)
                        .contains("receive_workout_nudges AS receive_team_notifications"));
    }

    private boolean returnsTeamMember(Method method) {
        if (method.getReturnType() == TeamMember.class) {
            return true;
        }
        return method.getGenericReturnType() instanceof ParameterizedType type
                && Arrays.asList(type.getActualTypeArguments()).contains(TeamMember.class);
    }
}
