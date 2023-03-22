package com.gradle.enterprise.api.client;

import java.net.URL;

public class FailedRequestException extends ApiClientException {

    private final int httpStatusCode;

    private final String responseBody;

    public FailedRequestException(String message, int httpStatusCode, String responseBody) {
        this(message, httpStatusCode, responseBody, null);
    }

    public FailedRequestException(String message, int httpStatusCode, String responseBody, Throwable cause) {
        super(message, cause);
        this.httpStatusCode = httpStatusCode;
        this.responseBody = responseBody;
    }

    public int httpStatusCode() {
        return httpStatusCode;
    }

    public String getResponseBody() {
        return responseBody;
    }

    public static FailedRequestException authenticationFailed(URL gradleEnterpriseServer, String buildScanId, int httpStatusCode, String responseBody, Throwable cause) {
        final String message = String.format("Failed to authenticate while attempting to fetch build scan %s.",
                buildScanUrl(gradleEnterpriseServer, buildScanId));
        return new FailedRequestException(message, httpStatusCode, responseBody, cause);
    }

    public static FailedRequestException buildScanNotFound(URL gradleEnterpriseServer, String buildScanId, int httpStatusCode, String responseBody, Throwable cause) {
        final String message = String.format("Failed to authenticate while attempting to fetch build scan %s.",
                buildScanUrl(gradleEnterpriseServer, buildScanId));
        return new FailedRequestException(message, httpStatusCode, responseBody, cause);
    }

    public static FailedRequestException unexpectedResponse(URL gradleEnterpriseServer, String buildScanId, int httpStatusCode, String responseBody, Throwable cause) {
        final String message = String.format("Encountered an unexpected response while fetching build scan %s.", buildScanUrl(gradleEnterpriseServer, buildScanId));
        return new FailedRequestException(message, httpStatusCode, responseBody, cause);
    }
}
