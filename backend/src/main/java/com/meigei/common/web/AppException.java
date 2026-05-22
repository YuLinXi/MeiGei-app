package com.meigei.common.web;

import org.springframework.http.HttpStatus;

/** 业务规则异常：携带 HTTP 状态，由 GlobalExceptionHandler 统一转 ProblemDetail。 */
public class AppException extends RuntimeException {

    private final HttpStatus status;

    public AppException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public static AppException notFound(String message) {
        return new AppException(HttpStatus.NOT_FOUND, message);
    }

    public static AppException forbidden(String message) {
        return new AppException(HttpStatus.FORBIDDEN, message);
    }

    public static AppException conflict(String message) {
        return new AppException(HttpStatus.CONFLICT, message);
    }

    public static AppException badRequest(String message) {
        return new AppException(HttpStatus.BAD_REQUEST, message);
    }
}
