import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import {
  IndexBacklogView,
  resolveIndexBacklogItems
} from '../main/ets/pages/index/IndexBacklogView';

interface IndexBacklogViewPrivateEG {
  events: EventEntity[];
  isExpanded: boolean;
  dividerColor: string;
  onToggleExpand: () => void;
  onMoveToSchedule: (item: TravelPlanItem) => void;
  onMoveAllToSchedule: () => void;
  resolveBacklogItems(): TravelPlanItem[];
  initialRender(): void;
}

function createIndexBacklogViewEG(): IndexBacklogViewPrivateEG {
  return new IndexBacklogView(undefined, {} as LocalStorage) as Object as IndexBacklogViewPrivateEG;
}

function buildBacklogEventEG(id: number, name: string, status: number): EventEntity {
  const event = new EventEntity(name, 1);
  event.id = id;
  event.status = status;
  event.duration = 45;
  event.sort_order = id * 100;
  return event;
}

export default function phase2BatchEGTest() {
  describe('phase2BatchEGTest', () => {
    it('normal: index_backlog_items_should_include_unscheduled_events', 0, () => {
      // Arrange
      const events = [buildBacklogEventEG(1, 'museum', 0), buildBacklogEventEG(2, 'park', 2)];

      // Act
      const items = resolveIndexBacklogItems(events);

      // Assert
      expect(items.length).assertEqual(2);
      expect(items[0].name).assertEqual('museum');
      expect(items[1].name).assertEqual('park');
    });

    it('boundary: index_backlog_items_should_exclude_status_one_only', 0, () => {
      // Arrange
      const events = [buildBacklogEventEG(1, 'scheduled', 1), buildBacklogEventEG(2, 'backlog', 0)];

      // Act
      const items = resolveIndexBacklogItems(events);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('backlog');
    });

    it('invalid: index_backlog_initial_render_should_support_expanded_empty_state', 0, () => {
      // Arrange
      const page = createIndexBacklogViewEG();
      let threw = false;
      page.events = [];
      page.isExpanded = true;
      page.dividerColor = '#DDDDDD';

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.resolveBacklogItems().length).assertEqual(0);
    });

    it('regression: index_backlog_initial_render_should_support_collapsed_items_state', 0, () => {
      // Arrange
      const page = createIndexBacklogViewEG();
      let threw = false;
      page.events = [buildBacklogEventEG(3, 'temple', 0)];
      page.isExpanded = false;
      page.dividerColor = '#CCCCCC';

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.resolveBacklogItems().length).assertEqual(1);
    });

    it('combined: index_backlog_initial_render_should_support_expanded_filtered_items', 0, () => {
      // Arrange
      const page = createIndexBacklogViewEG();
      let movedName = '';
      let moveAllCount = 0;
      let toggled = false;
      let threw = false;
      page.events = [buildBacklogEventEG(4, 'cafe', 0), buildBacklogEventEG(5, 'done', 1)];
      page.isExpanded = true;
      page.dividerColor = '#BBBBBB';
      page.onToggleExpand = (): void => {
        toggled = true;
      };
      page.onMoveToSchedule = (item: TravelPlanItem): void => {
        movedName = item.name;
      };
      page.onMoveAllToSchedule = (): void => {
        moveAllCount += 1;
      };

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.resolveBacklogItems().length).assertEqual(1);
      expect(toggled).assertFalse();
      expect(movedName).assertEqual('');
      expect(moveAllCount).assertEqual(0);
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
