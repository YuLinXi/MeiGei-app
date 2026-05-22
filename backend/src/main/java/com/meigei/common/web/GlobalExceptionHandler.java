package com.meigei.common.web;

import com.meigei.auth.AppleTokenVerifier.AppleTokenException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    /** Apple identityToken 校验失败 → 401（外部 token 不可信，非服务端错误）。 */
    @ExceptionHandler(AppleTokenException.class)
    public ProblemDetail handleAppleToken(AppleTokenException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, e.getMessage());
    }

    /** 业务规则违规 → 自带状态（404/403/409/400 等）。 */
    @ExceptionHandler(AppException.class)
    public ProblemDetail handleApp(AppException e) {
        return ProblemDetail.forStatusAndDetail(e.getStatus(), e.getMessage());
    }
}
