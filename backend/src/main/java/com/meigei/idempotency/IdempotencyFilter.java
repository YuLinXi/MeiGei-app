package com.meigei.idempotency;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.meigei.common.id.Uuid7;
import com.meigei.idempotency.entity.IdempotencyKey;
import com.meigei.idempotency.mapper.IdempotencyKeyMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.Set;
import java.util.UUID;

/**
 * 幂等中间件（D4）：对带 Idempotency-Key 头的写请求，
 * 首次执行后缓存 (user, key) -> (status, body)；重复请求直接回放首次结果。
 * 排在安全过滤链之后，故此时已可取到当前用户。
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE)
@RequiredArgsConstructor
public class IdempotencyFilter extends OncePerRequestFilter {

    private static final String HEADER = "Idempotency-Key";
    private static final Set<String> MUTATING = Set.of("POST", "PUT", "PATCH", "DELETE");

    private final IdempotencyKeyMapper mapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String key = request.getHeader(HEADER);
        UUID userId = currentUserIdOrNull();
        if (key == null || userId == null || !MUTATING.contains(request.getMethod())) {
            chain.doFilter(request, response);
            return;
        }

        IdempotencyKey existing = mapper.selectOne(new LambdaQueryWrapper<IdempotencyKey>()
                .eq(IdempotencyKey::getUserId, userId)
                .eq(IdempotencyKey::getIdemKey, key));
        if (existing != null && existing.getResponseStatus() != null) {
            replay(response, existing);
            return;
        }

        ContentCachingResponseWrapper wrapper = new ContentCachingResponseWrapper(response);
        chain.doFilter(request, wrapper);

        int status = wrapper.getStatus();
        // 仅缓存确定性结果（2xx/4xx）；5xx 允许后续重试
        if (status < 500) {
            String body = new String(wrapper.getContentAsByteArray(), StandardCharsets.UTF_8);
            persist(userId, key, status, body);
        }
        wrapper.copyBodyToResponse();
    }

    private void persist(UUID userId, String key, int status, String body) {
        try {
            IdempotencyKey rec = new IdempotencyKey();
            rec.setId(Uuid7.generate());
            rec.setUserId(userId);
            rec.setIdemKey(key);
            rec.setResponseStatus(status);
            rec.setResponseBody(body == null || body.isBlank() ? null : body);
            mapper.insert(rec);
        } catch (DuplicateKeyException ignore) {
            // 并发下首次已落库，忽略
        }
    }

    private void replay(HttpServletResponse response, IdempotencyKey rec) throws IOException {
        response.setStatus(rec.getResponseStatus());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        if (rec.getResponseBody() != null) {
            response.getWriter().write(rec.getResponseBody());
        }
    }

    private UUID currentUserIdOrNull() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof UUID id) {
            return id;
        }
        return null;
    }
}
