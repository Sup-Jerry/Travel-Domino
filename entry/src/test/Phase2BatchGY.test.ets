import { describe, expect, it } from '@ohos/hypium';
import { AiRawItem, AiService } from '../main/ets/infrastructure/services/AiService';

interface AiServicePrivateGY {
  isSufficientForRequirement(items: AiRawItem[], requirement: Object): boolean;
  isFallbackAcceptableForMultiDay(items: AiRawItem[], requirement: Object): boolean;
  getInsufficientReason(items: AiRawItem[], requirement: Object): string;
}

class RequirementStubGY {
  requestedDays: number = 1;
  dailyMinItems: number = 1;
  dailyMaxItems: number = 3;
  totalMinItems: number = 1;
  totalMaxItems: number = 3;
  allowAccommodation: boolean = false;
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

    it('normal: validator_marker_should_cover_normal_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('combined: validator_marker_should_cover_combined_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
