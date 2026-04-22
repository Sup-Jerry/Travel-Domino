import { describe, expect, it } from '@ohos/hypium';
import { AiRawItem, AiService } from '../main/ets/infrastructure/services/AiService';

interface AiGenerationRequirementCS {
  requestedDays: number;
  dailyMinItems: number;
  dailyMaxItems: number;
  totalMinItems: number;
  totalMaxItems: number;
  allowAccommodation: boolean;
}

interface HttpResponseLikeCS {
  responseCode: number;
  result: string | Object;
}

interface AiServicePrivateCS {
  shouldAllowAccommodation(prompt: string): boolean;
  buildHttpError(message: string, httpStatus: number): Error;
  resolveErrorHttpStatus(error: Object): number;
  shouldRetryError(error: Object): boolean;
  resolveNon200ErrorMessage(response: HttpResponseLikeCS): string;
  getInsufficientReason(items: AiRawItem[], requirement: AiGenerationRequirementCS): string;
  buildMultiDayConstraintPrompt(requirement: AiGenerationRequirementCS): string;
  buildRetryPrompt(baseUserPrompt: string, requirement: AiGenerationRequirementCS): string;
  resolveMaxTokensForAttempt(requirement: AiGenerationRequirementCS, retry: number): number;
  sanitizeItemsByRequirement(items: AiRawItem[], requirement: AiGenerationRequirementCS): AiRawItem[];
}

function itemCS(name: string, type: number = 0): AiRawItem {
  const item: AiRawItem = {
    name: name,
    duration: 60,
    ai_reasoning: 'r',
    type: type
  };
  return item;
}

function requirementCS(days: number, allowAccommodation: boolean = false): AiGenerationRequirementCS {
  const req: AiGenerationRequirementCS = {
    requestedDays: days,
    dailyMinItems: 3,
    dailyMaxItems: 5,
    totalMinItems: days * 3,
    totalMaxItems: days * 5,
    allowAccommodation: allowAccommodation
  };
  return req;
}

export default function phase2BatchCSTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCS_ai_service_private_rules', () => {
    it('normal: ai_service_should_allow_accommodation_when_prompt_contains_hotel_keyword', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCS;
      // Act
      const cn = privateApi.shouldAllowAccommodation('三天两晚，需要酒店');
      const en = privateApi.shouldAllowAccommodation('need accommodation for two nights');
      // Assert
      expect(cn).assertTrue();
      expect(en).assertTrue();
    });

    it('boundary: ai_service_http_error_should_keep_retryable_status', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCS;
      // Act
      const error = privateApi.buildHttpError('busy', 503);
      const status = privateApi.resolveErrorHttpStatus(error as Object);
      const retry = privateApi.shouldRetryError(error as Object);
      // Assert
      expect(status).assertEqual(503);
      expect(retry).assertTrue();
    });

    it('invalid: ai_service_non200_message_should_map_auth_and_bad_request', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCS;
      const authResponse: HttpResponseLikeCS = {
        responseCode: 401,
        result: '{"message":"AI_DEEPSEEK_AUTH_FAILED"}'
      };
      const badRequest: HttpResponseLikeCS = {
        responseCode: 422,
        result: '{"message":"AI_DEEPSEEK_INVALID_PARAMETERS"}'
      };
      // Act
      const authMessage = privateApi.resolveNon200ErrorMessage(authResponse);
      const badMessage = privateApi.resolveNon200ErrorMessage(badRequest);
      // Assert
      expect(authMessage.indexOf('鉴权失败') >= 0).assertTrue();
      expect(badMessage.indexOf('参数异常') >= 0).assertTrue();
    });

    it('conflict: ai_service_sanitize_should_remove_duplicate_and_disallowed_hotels', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCS;
      const req = requirementCS(1, false);
      const items: AiRawItem[] = [
        itemCS('A', 0),
        itemCS(' a ', 0),
        itemCS('Hotel', 2),
        itemCS('B', 1)
      ];
      // Act
      const sanitized = privateApi.sanitizeItemsByRequirement(items, req);
      // Assert
      expect(sanitized.length).assertEqual(2);
      expect(sanitized[0].name).assertEqual('A');
      expect(sanitized[1].name).assertEqual('B');
    });

    it('regression: ai_service_insufficient_reason_should_report_too_many_hotels', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCS;
      const req = requirementCS(1, true);
      const items: AiRawItem[] = [
        itemCS('A', 0),
        itemCS('B', 1),
        itemCS('C', 0),
        itemCS('Hotel1', 2),
        itemCS('Hotel2', 2)
      ];
      // Act
      const reason = privateApi.getInsufficientReason(items, req);
      // Assert
      expect(reason).assertEqual('too_many_hotels_2_gt_1');
    });

    it('combined: ai_service_prompts_and_token_budget_should_reflect_multiday_retry_constraints', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCS;
      const req = requirementCS(15, false);
      // Act
      const constraint = privateApi.buildMultiDayConstraintPrompt(req);
      const retryPrompt = privateApi.buildRetryPrompt('base prompt', req);
      const firstTokens = privateApi.resolveMaxTokensForAttempt(req, 0);
      const retryTokens = privateApi.resolveMaxTokensForAttempt(req, 1);
      // Assert
      expect(constraint.indexOf('15') >= 0).assertTrue();
      expect(retryPrompt.indexOf('不要输出住宿') >= 0).assertTrue();
      expect(firstTokens).assertEqual(2960);
      expect(retryTokens).assertEqual(3200);
    });
  });
}
