import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexHelpers, WeatherSuggestionContext } from '../main/ets/pages/index/IndexHelpers';

function buildScheduleEventHC(
  id: number,
  sortOrder: number,
 computedTime: string,
  duration: number,
  dynamicEndTime: number
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.status = 1;
  event.sort_order = sortOrder;
  event.computed_time = computedTime;
  event.duration = duration;
  event.dynamic_end_time = dynamicEndTime;
  return event;
}

export default function phase2BatchHCTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHC_index_helpers_edges', () => {
    it('combined: index_helpers_should_keep_single_empty_line_when_split_text_empty', 0, () => {
      const lines = IndexHelpers.splitLines('');

      expect(lines.length).assertEqual(1);
      expect(lines[0]).assertEqual('');
    });

    it('combined: index_helpers_should_build_weather_text_when_only_summary_or_strategy_present', 0, () => {
      const summaryOnly: WeatherSuggestionContext = {
        collabLabel: '',
        planningHint: '建议室内优先',
        collabSummary: '步行更少',
        strategyHint: ''
      };
      const strategyOnly: WeatherSuggestionContext = {
        collabLabel: '',
        planningHint: '建议上午出发',
        collabSummary: '',
        strategyHint: '避雨优先'
      };

      const summaryText = IndexHelpers.buildWeatherSuggestionText(summaryOnly);
      const strategyText = IndexHelpers.buildWeatherSuggestionText(strategyOnly);

      expect(summaryText).assertContain('建议室内优先');
      expect(summaryText).assertContain('步行更少');
      expect(strategyText).assertContain('建议上午出发');
      expect(strategyText).assertContain('避雨优先');
    });

    it('combined: index_helpers_should_use_dynamic_end_time_and_keep_zero_padding', 0, () => {
      const endTime = new Date(2026, 3, 25, 6, 3).getTime();
      const event = buildScheduleEventHC(951, 10, '', 0, endTime);

      const suggested = IndexHelpers.resolveBacklogSuggestedTime([event]);

      expect(suggested).assertEqual('06:03');
    });

    it('combined: index_helpers_should_parse_plain_computed_time_without_date_prefix', 0, () => {
      const event = buildScheduleEventHC(952, 10, '07:05', 25, 0);

      const suggested = IndexHelpers.resolveBacklogSuggestedTime([event]);

      expect(suggested).assertEqual('07:30');
    });
  });
}
