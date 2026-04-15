import { mapAiUpstreamHttpError } from '../src/modules/ai/ai.service';

describe('unit_test_case_generator_autofill_ai_service', () => {
  it('normal: map_ai_upstream_http_error_should_match_deepseek_status_codes', () => {
    // Arrange
    // Act
    const badRequest = mapAiUpstreamHttpError(400);
    const authFailed = mapAiUpstreamHttpError(401);
    const insufficientBalance = mapAiUpstreamHttpError(402);
    const invalidParams = mapAiUpstreamHttpError(422);
    const rateLimit = mapAiUpstreamHttpError(429);
    const serverError = mapAiUpstreamHttpError(500);
    const serverBusy = mapAiUpstreamHttpError(503);
    // Assert
    expect(badRequest).toBe('AI_DEEPSEEK_BAD_REQUEST');
    expect(authFailed).toBe('AI_DEEPSEEK_AUTH_FAILED');
    expect(insufficientBalance).toBe('AI_DEEPSEEK_INSUFFICIENT_BALANCE');
    expect(invalidParams).toBe('AI_DEEPSEEK_INVALID_PARAMETERS');
    expect(rateLimit).toBe('AI_DEEPSEEK_RATE_LIMIT');
    expect(serverError).toBe('AI_DEEPSEEK_SERVER_ERROR');
    expect(serverBusy).toBe('AI_DEEPSEEK_SERVER_BUSY');
  });

  it('regression: map_ai_upstream_http_error_should_fallback_to_generic_code', () => {
    // Arrange
    // Act
    const mapped = mapAiUpstreamHttpError(418);
    // Assert
    expect(mapped).toBe('AI_UPSTREAM_HTTP_418');
  });
});
