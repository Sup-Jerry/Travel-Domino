import { describe, expect, it } from '@ohos/hypium';
import { AiRawItem, AiService } from '../main/ets/infrastructure/services/AiService';

interface AiServicePrivateGY {
  isSufficientForRequirement(items: AiRawItem[], requirement: Object): boolean;
  isFallbackAcceptableForMultiDay(items: AiRawItem[], requirement: Object): boolean;
  getInsufficientReason(items: AiRawItem[], requirement: Object): string;
  isTimeoutLikeError(error: Object): boolean;
  shouldRetryError(error: Object): boolean;
  resolveNon200ErrorMessage(response: Object): string;
}

class RequirementStubGY {
  requestedDays: number = 1;
  dailyMinItems: number = 1;
  dailyMaxItems: number = 3;
  totalMinItems: number = 1;
  totalMaxItems: number = 3;
  allowAccommodation: boolean = false;
}

class EmptyErrorStubGY {
}

class HttpResponseStubGY {
  responseCode: number = 200;
  result: string = '';
}

function createRequirementGY(
  requestedDays: number,
  dailyMinItems: number,
  dailyMaxItems: number,
  totalMinItems: number,
  totalMaxItems: number,
  allowAccommodation: boolean
): RequirementStubGY {
  const requirement = new RequirementStubGY();
  requirement.requestedDays = requestedDays;
  requirement.dailyMinItems = dailyMinItems;
  requirement.dailyMaxItems = dailyMaxItems;
  requirement.totalMinItems = totalMinItems;
  requirement.totalMaxItems = totalMaxItems;
  requirement.allowAccommodation = allowAccommodation;
  return requirement;
}

function createItemGY(name: string, type: number, duration: number = 60): AiRawItem {
  return {
    name: name,
    duration: duration,
    ai_reasoning: `${name}_reason`,
    type: type
  };
}

export default function phase2BatchGYTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGY_ai_service_private_requirement_callbacks', () => {
    it('conflict: ai_service_should_reject_when_hotel_count_exceeds_requested_days', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const requirement = createRequirementGY(2, 1, 3, 2, 6, true);
      const items: AiRawItem[] = [
        createItemGY('hotel_1', 2, 600),
        createItemGY('hotel_2', 2, 600),
        createItemGY('hotel_3', 2, 600),
        createItemGY('spot_1', 0),
        createItemGY('spot_2', 0)
      ];

      // Act
      const accepted = privateApi.isSufficientForRequirement(items, requirement as Object);

      // Assert
      expect(accepted).assertFalse();
    });

    it('boundary: ai_service_should_reject_multi_day_fallback_when_hotel_count_exceeds_requested_days', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const requirement = createRequirementGY(2, 3, 5, 6, 10, true);
      const items: AiRawItem[] = [
        createItemGY('hotel_1', 2, 600),
        createItemGY('hotel_2', 2, 600),
        createItemGY('hotel_3', 2, 600),
        createItemGY('spot_1', 0),
        createItemGY('spot_2', 0),
        createItemGY('food_1', 1)
      ];

      // Act
      const accepted = privateApi.isFallbackAcceptableForMultiDay(items, requirement as Object);

      // Assert
      expect(accepted).assertFalse();
    });

    it('regression: ai_service_should_report_unexpected_accommodation_reason_when_hotels_are_disallowed', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const requirement = createRequirementGY(1, 1, 3, 1, 3, false);
      const items: AiRawItem[] = [
        createItemGY('hotel_1', 2, 600),
        createItemGY('spot_1', 0)
      ];

      // Act
      const reason = privateApi.getInsufficientReason(items, requirement as Object);

      // Assert
      expect(reason).assertEqual('unexpected_accommodation');
    });

    it('normal: ai_service_should_accept_sufficient_non_hotel_items_when_requirement_is_met', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const requirement = createRequirementGY(2, 1, 3, 2, 6, false);
      const items: AiRawItem[] = [
        createItemGY('spot_1', 0),
        createItemGY('food_1', 1),
        createItemGY('spot_2', 0)
      ];

      // Act
      const accepted = privateApi.isSufficientForRequirement(items, requirement as Object);

      // Assert
      expect(accepted).assertTrue();
    });

    it('boundary: ai_service_should_default_requested_days_for_blank_prompt_and_zero_day_phrase', 0, () => {
      // Arrange
      const blankPrompt = '   ';
      const zeroDayPrompt = '零天行程';

      // Act
      const blankDays = AiService.resolveRequestedDaysFromPrompt(blankPrompt);
      const zeroDays = AiService.resolveRequestedDaysFromPrompt(zeroDayPrompt);

      // Assert
      expect(blankDays).assertEqual(1);
      expect(zeroDays).assertEqual(1);
    });

    it('normal: ai_service_should_accept_multi_day_fallback_when_counts_and_hotel_limits_are_safe', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const requirement = createRequirementGY(2, 3, 5, 6, 10, true);
      const items: AiRawItem[] = [
        createItemGY('hotel_1', 2, 600),
        createItemGY('spot_1', 0),
        createItemGY('food_1', 1),
        createItemGY('spot_2', 0),
        createItemGY('food_2', 1)
      ];

      // Act
      const accepted = privateApi.isFallbackAcceptableForMultiDay(items, requirement as Object);

      // Assert
      expect(accepted).assertTrue();
    });

    it('boundary: ai_service_should_reject_multi_day_fallback_for_single_day_or_empty_items', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const singleDayRequirement = createRequirementGY(1, 2, 4, 2, 4, false);
      const multiDayRequirement = createRequirementGY(2, 2, 4, 4, 8, false);

      // Act
      const singleDayAccepted = privateApi.isFallbackAcceptableForMultiDay(
        [createItemGY('spot_1', 0), createItemGY('food_1', 1)],
        singleDayRequirement as Object
      );
      const emptyAccepted = privateApi.isFallbackAcceptableForMultiDay([], multiDayRequirement as Object);

      // Assert
      expect(singleDayAccepted).assertFalse();
      expect(emptyAccepted).assertFalse();
    });

    it('invalid: ai_service_private_error_guards_should_not_retry_plain_objects_or_unknown_messages', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const unknownResponse = new HttpResponseStubGY();
      unknownResponse.responseCode = 418;
      unknownResponse.result = '{"message":"teapot"}';
      const plainError = new EmptyErrorStubGY();

      // Act
      const timeoutLike = privateApi.isTimeoutLikeError(plainError as Object);
      const retryable = privateApi.shouldRetryError(plainError as Object);
      const message = privateApi.resolveNon200ErrorMessage(unknownResponse as Object);

      // Assert
      expect(timeoutLike).assertFalse();
      expect(retryable).assertFalse();
      expect(message).assertEqual('网络请求失败');
    });

    it('combined: ai_service_should_report_non_hotel_shortage_and_unknown_reason_for_private_requirement_paths', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateGY;
      const strictRequirement = createRequirementGY(3, 1, 3, 3, 9, true);
      const strictItems: AiRawItem[] = [
        createItemGY('hotel_1', 2, 600),
        createItemGY('spot_1', 0),
        createItemGY('spot_2', 0)
      ];
      const balancedRequirement = createRequirementGY(2, 1, 3, 2, 6, true);
      const balancedItems: AiRawItem[] = [
        createItemGY('hotel_1', 2, 600),
        createItemGY('spot_1', 0),
        createItemGY('food_1', 1)
      ];

      // Act
      const shortageReason = privateApi.getInsufficientReason(strictItems, strictRequirement as Object);
      const unknownReason = privateApi.getInsufficientReason(balancedItems, balancedRequirement as Object);

      // Assert
      expect(shortageReason).assertEqual('insufficient_non_hotel_2_lt_3');
      expect(unknownReason).assertEqual('unknown');
    });
  });
}
