import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  resolveIndexBacklogItems,
  shouldIncludeIndexBacklogEvent
} from '../main/ets/pages/index/IndexBacklogView';
import { shouldShowIndexTopAreaWeatherHintBar } from '../main/ets/pages/index/IndexTopArea';

function buildBacklogEventHI(id: number, status: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `hi_${id}`;
  event.status = status;
  return event;
}

export default function phase2BatchHITest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHI_backlog_and_top_area_edges', () => {
    it('combined: index_backlog_view_should_keep_negative_status_included', 0, () => {
      const include = shouldIncludeIndexBacklogEvent(-1);

      expect(include).assertTrue();
    });

    it('combined: index_backlog_view_should_preserve_original_order_for_non_completed_events', 0, () => {
      const first = buildBacklogEventHI(501, 2);
      const second = buildBacklogEventHI(502, 0);
      const third = buildBacklogEventHI(503, 1);

      const items = resolveIndexBacklogItems([first, second, third]);

      expect(items.length).assertEqual(2);
      expect(items[0].id).assertEqual(501);
      expect(items[1].id).assertEqual(502);
    });

    it('combined: index_top_area_weather_hint_should_hide_for_repeated_false_input', 0, () => {
      const first = shouldShowIndexTopAreaWeatherHintBar(false);
      const second = shouldShowIndexTopAreaWeatherHintBar(false);

      expect(first).assertFalse();
      expect(second).assertFalse();
    });

    it('combined: index_top_area_weather_hint_should_count_only_true_flags_in_sparse_matrix', 0, () => {
      const flags: boolean[] = [false, true, false, true, false, false];

      const visibleCount = flags.filter((flag) => shouldShowIndexTopAreaWeatherHintBar(flag)).length;

      expect(visibleCount).assertEqual(2);
    });
  });
}
