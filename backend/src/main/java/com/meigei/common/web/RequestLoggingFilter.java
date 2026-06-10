package com.meigei.common.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * 请求级日志与链路追踪（最高优先级，包裹整条过滤链）：
 * <ul>
 *   <li>为每个请求生成短 traceId，写入 MDC 并回传 {@code X-Trace-Id} 响应头，全链路日志（含认证、业务、异常）可串联。</li>
 *   <li>请求结束统一记录一行摘要：方法 / 路径 / 状态码 / 耗时。userId 由 {@link com.meigei.security.JwtAuthFilter} 认证后写入 MDC。</li>
 *   <li>finally 中 {@link MDC#clear()} 清理本线程所有 MDC，避免线程池复用串号。</li>
 * </ul>
 * 健康检查 / 文档等噪音路径只设 traceId，不打摘要，避免刷屏。
 */
@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestLoggingFilter extends OncePerRequestFilter {

    static final String TRACE_ID = "traceId";
    static final String USER_ID = "userId";
    private static final String TRACE_HEADER = "X-Trace-Id";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String traceId = UUID.randomUUID().toString().substring(0, 8);
        MDC.put(TRACE_ID, traceId);
        response.setHeader(TRACE_HEADER, traceId);

        long start = System.currentTimeMillis();
        try {
            chain.doFilter(request, response);
        } finally {
            if (!isQuietPath(request.getRequestURI())) {
                long cost = System.currentTimeMillis() - start;
                log.info("{} {} -> {} ({}ms)",
                        request.getMethod(), request.getRequestURI(), response.getStatus(), cost);
            }
            MDC.clear();
        }
    }

    /** 健康检查 / Swagger / API 文档等高频或静态路径，不记录请求摘要。 */
    private boolean isQuietPath(String uri) {
        return uri.startsWith("/actuator")
                || uri.startsWith("/swagger-ui")
                || uri.startsWith("/v3/api-docs");
    }
}
