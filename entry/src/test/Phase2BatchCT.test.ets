import { describe, expect, it } from '@ohos/hypium';
import { AiRawItem, AiService } from '../main/ets/infrastructure/services/AiService';

interface AiGenerationRequirementCT {
  requestedDays: number;
  dailyMinItems: number;
  dailyMaxItems: number;
  totalMinItems: number;
  totalMaxItems: number;
  allowAccommodation: boolean;
}

interface AiServicePrivateCT {
  parseSimpleChineseNumber(raw: string): number;
  normalizeItemType(type: number): number;
  normalizeDurationByType(duration: number, type: number): number;
  enforceMaxItems(items: AiRawItem[], maxItems: number): AiRawItem[];
  isFallbackAcceptableForMultiDay(items: AiRawItem[], requirement: AiGenerationRequirementCT): boolean;
  isBestEffortAcceptableForLongTrip(items: AiRawItem[], requirement: AiGenerationRequirementCT): boolean;
  buildDailyRangeConstraintPrompt(requirement: AiGenerationRequirementCT): string;
}

function itemCT(name: string, type: number = 0): AiRawItem {
  const item: AiRawItem = {
    name: name,
    duration: 60,
    ai_reasoning: 'r',
    type: type
  };
  return item;
}

function requirementCT(days: number, allowAccommodation: boolean = false): AiGenerationRequirementCT {
  const req: AiGenerationRequirementCT = {
    requestedDays: days,
    dailyMinItems: 4,
    dailyMaxItems: 6,
    totalMinItems: days * 4,
    totalMaxItems: days * 6,
    allowAccommodation: allowAccommodation
  };
  return req;
}

function itemsCT(count: number, prefix: string = 'P'): AiRawItem[] {
  const result: AiRawItem[] = [];
  for (let i = 0; i < count; i++) {
    result.push(itemCT(`${prefix}${i}`, i % 2));
  }
  return result;
}

export default function phase2BatchCTTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCT_ai_service_private_rules_more', () => {
    it('normal: ai_service_chinese_number_should_parse_tens_and_aliases', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCT;
      // Act
      const ten = privateApi.parseSimpleChineseNumber('十');
      const twelve = privateApi.parseSimpleChineseNumber('十二');
      const twentyOne = privateApi.parseSimpleChineseNumber('二十一');
      const two = privateApi.parseSimpleChineseNumber('俩');
      // Assert
      expect(ten).assertEqual(10);
      expect(twelve).assertEqual(12);
      expect(twentyOne).assertEqual(21);
      expect(two).assertEqual(2);
    });

    it('boundary: ai_service_duration_normalization_should_clamp_by_type', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCT;
      // Act
      const scenic = privateApi.normalizeDurationByType(500, 0);
      const food = privateApi.normalizeDurationByType(5, 1);
      const hotel = privateApi.normalizeDurationByType(1000, 2);
      const invalid = privateApi.normalizeDurationByType(Number.NaN, 0);
      // Assert
      expect(scenic).assertEqual(180);
      expect(food).assertEqual(20);
      expect(hotel).assertEqual(720);
      expect(invalid).assertEqual(60);
    });

    it('invalid: ai_service_item_type_should_fallback_to_scenic_for_unknown_type', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCT;
      // Act
      const known = privateApi.normalizeItemType(2);
      const unknown = privateApi.normalizeItemType(99);
      // Assert
      expect(known).assertEqual(2);
      expect(unknown).assertEqual(0);
    });

    it('conflict: ai_service_enforce_max_items_should_keep_at_least_one_item_for_bad_limit', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCT;
      const source = itemsCT(3, 'cap');
      // Act
      const capped = privateApi.enforceMaxItems(source, Number.NaN);
      const one = privateApi.enforceMaxItems(source, 0);
      // Assert
      expect(capped.length).assertEqual(3);
      expect(one.length).assertEqual(1);
    });

    it('regression: ai_service_multiday_fallback_should_accept_one_less_than_daily_min', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCT;
      const req = requirementCT(3, false);
      // Act
      const acceptable = privateApi.isFallbackAcceptableForMultiDay(itemsCT(9), req);
      const tooFew = privateApi.isFallbackAcceptableForMultiDay(itemsCT(5), req);
      // Assert
      expect(acceptable).assertTrue();
      expect(tooFew).assertFalse();
    });

    it('combined: ai_service_long_trip_best_effort_and_daily_prompt_should_use_requirement_values', 0, () => {
      // Arrange
      const privateApi = AiService as Object as AiServicePrivateCT;
      const req = requirementCT(12, false);
      const withHotel = itemsCT(12);
      withHotel.push(itemCT('hotel', 2));
      // Act
      const accepted = privateApi.isBestEffortAcceptableForLongTrip(itemsCT(6), req);
      const rejectedHotel = privateApi.isBestEffortAcceptableForLongTrip(withHotel, req);
      const prompt = privateApi.buildDailyRangeConstraintPrompt(req);
      // Assert
      expect(accepted).assertTrue();
      expect(rejectedHotel).assertFalse();
      expect(prompt.indexOf('4-6') >= 0).assertTrue();
    });
  });
}
