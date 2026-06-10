package com.meigei.common.web;

import com.meigei.auth.AppleTokenVerifier.AppleTokenException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * 全局异常 → ProblemDetail 统一出口，并按严重程度规范化日志：
 * <ul>
 *   <li>Spring MVC 标准异常（@Valid 400 / 反序列化失败 / 405 等）由父类 {@link ResponseEntityExceptionHandler}
 *       正确映射为 4xx；{@link #handleExceptionInternal} 是其统一出口，在此补一行日志，不改变状态码契约。</li>
 *   <li>{@link AppleTokenException} → 401（外部 token 不可信，warn）。</li>
 *   <li>{@link AppException} → 自带状态（404/403/409/400，客户端可预期，debug 留痕不告警）。</li>
 *   <li>其余未预期异常 → 500，error 级别带堆栈（含 MDC traceId/userId），并经 Sentry 上报。</li>
 * </ul>
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    /** Apple identityToken 校验失败 → 401。 */
    @ExceptionHandler(AppleTokenException.class)
    public ProblemDetail handleAppleToken(AppleTokenException e) {
        log.warn("Apple token 校验失败: {}", e.getMessage());
        return ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, e.getMessage());
    }

    /** 业务规则违规 → 自带状态。 */
    @ExceptionHandler(AppException.class)
    public ProblemDetail handleApp(AppException e) {
        log.debug("业务异常 {}: {}", e.getStatus().value(), e.getMessage());
        return ProblemDetail.forStatusAndDetail(e.getStatus(), e.getMessage());
    }

    /** 兜底：未被上面与父类处理的异常 → 500 带堆栈。 */
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception e) {
        log.error("未处理异常", e);
        return ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR, "服务器内部错误");
    }

    /** 父类标准 MVC 异常的统一出口：在此补日志（4xx 多为客户端问题，warn 级别）。 */
    @Override
    protected ResponseEntity<Object> handleExceptionInternal(
            Exception ex, Object body, HttpHeaders headers,
            HttpStatusCode statusCode, WebRequest request) {
        log.warn("请求异常 {}: {}", statusCode.value(), ex.getMessage());
        return super.handleExceptionInternal(ex, body, headers, statusCode, request);
    }
}
