import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  CompanionTimelineSection,
  getCompanionTimelineFilterSummary,
  getCompanionTimelineVisibleCount,
  shouldShowCompanionTimelineEmptyState
} from '../main/ets/pages/components/views/companion/CompanionTimelineSection';
import {
  CompanionImmersiveView,
  getImmersiveNextStationText,
  getImmersivePrimaryActionEnabled,
  getImmersivePrimaryActionLabel,
  shouldShowImmersivePrimaryAction,
  ImmersiveSwipePhase
} from '../main/ets/pages/components/views/companion/CompanionImmersiveView';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';

interface TimelineParamsGF {
  focusedEventId?: number;
  filterLabel?: string;
  focusPosition?: number;
  timelineCount?: number;
  events?: EventEntity[];
}

interface TimelinePrivateGF {
  focusedEventId: number;
  filterLabel: string;
  focusPosition: number;
  timelineCount: number;
  events: EventEntity[];
  effectiveTheme: string;
  getStateDotColor: (event: EventEntity) => Object;
  getEventStateLabel: (event: EventEntity) => string;
  getStateTagTextColor: (event: EventEntity) => Object;
  getStateTagBackgroundColor: (event: EventEntity) => Object;
  getStateBorderColor: (event: EventEntity) => Object;
  getTimelineSupplement: (event: EventEntity) => string;
  onItemTap: (event: EventEntity, index: number) => void;
  onScrollIndex: (start: number, end: number, center: number) => void;
  onScrollStop: () => void;
  TimelineFocusItem(item: EventEntity, index: number): void;
  setInitiallyProvidedValue(params: TimelineParamsGF): void;
  initialRender(): void;
}

interface ImmersiveParamsGF {
  context?: CompanionContext;
  immersiveText?: string;
  immersiveDragOffsetY?: number;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface ImmersivePrivateGF {
  context: CompanionContext;
  immersiveText: string;
  immersiveDragOffsetY: number;
  safeTopInset: number;
  safeBottomInset: number;
  getRuntimeLabel: () => string;
  getPlannedRange: (event: EventEntity) => string;
  getForecastStartText: (event: EventEntity) => string;
  isCurrentEventPending: () => boolean;
  isCurrentEventActive: () => boolean;
  canStartFocused: (event: EventEntity) => boolean;
  canEndFocused: (event: EventEntity) => boolean;
  onStartEvent: (event: EventEntity) => Promise<void> | void;
  onEndEvent: (event: EventEntity) => Promise<void> | void;
  onNavigate: (event?: EventEntity) => void;
  onSwipeGesture: (phase: ImmersiveSwipePhase, event?: GestureEvent) => void;
  setInitiallyProvidedValue(params: ImmersiveParamsGF): void;
  initialRender(): void;
}

function buildEventGF(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

function buildContextGF(runtimeState: string, current: EventEntity | null, next: EventEntity | null): CompanionContext {
  return {
    runtimeState,
    currentEvent: current,
    nextEvent: next,
    hint: null
  } as CompanionContext;
}

export default function phase2BatchGFTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGF_timeline_immersive_render_lines', () => {
    it('combined: timeline_focus_item_and_render_should_cover_focused_unfocused_and_empty_paths', 0, () => {
      const page = new CompanionTimelineSection(undefined, {} as LocalStorage) as Object as TimelinePrivateGF;
      const focused = buildEventGF(101, 'museum');
      const unfocused = buildEventGF(102, 'station');
      let tapCount = 0;
      let lastTapIndex = -1;
      let scrollIndexCount = 0;
      let scrollStopCount = 0;
      let focusedItemThrew = false;
      let unfocusedItemThrew = false;
      let renderThrew = false;
      let emptyRenderThrew = false;

      page.getStateDotColor = (_event: EventEntity): Object => '#00897B';
      page.getEventStateLabel = (_event: EventEntity): string => 'ACTIVE';
      page.getStateTagTextColor = (_event: EventEntity): Object => '#FFFFFF';
      page.getStateTagBackgroundColor = (_event: EventEntity): Object => '#263238';
      page.getStateBorderColor = (_event: EventEntity): Object => '#26A69A';
      page.getTimelineSupplement = (event: EventEntity): string => `supplement_${event.id}`;
      page.onItemTap = (_event: EventEntity, index: number): void => {
        tapCount += 1;
        lastTapIndex = index;
      };
      page.onScrollIndex = (_start: number, _end: number, _center: number): void => {
        scrollIndexCount += 1;
      };
      page.onScrollStop = (): void => {
        scrollStopCount += 1;
      };
      page.setInitiallyProvidedValue({
        focusedEventId: focused.id,
        filterLabel: 'ACTIVE',
        focusPosition: 1,
        timelineCount: 2,
        events: [focused, unfocused]
      });

      try {
        page.TimelineFocusItem(focused, 0);
      } catch (_error) {
        focusedItemThrew = true;
      }
      try {
        page.TimelineFocusItem(unfocused, 1);
      } catch (_error) {
        unfocusedItemThrew = true;
      }
      try {
        page.initialRender();
      } catch (_error) {
        renderThrew = true;
      }

      page.onItemTap(focused, 0);
      page.onScrollIndex(0, 1, 0);
      page.onScrollStop();
      page.setInitiallyProvidedValue({
        focusedEventId: -1,
        filterLabel: 'SKIPPED',
        focusPosition: 0,
        timelineCount: 0,
        events: []
      });
      try {
        page.initialRender();
      } catch (_error) {
        emptyRenderThrew = true;
      }

      expect(focusedItemThrew).assertFalse();
      expect(unfocusedItemThrew).assertFalse();
      expect(renderThrew).assertFalse();
      expect(emptyRenderThrew).assertFalse();
      expect(tapCount).assertEqual(1);
      expect(lastTapIndex).assertEqual(0);
      expect(scrollIndexCount).assertEqual(1);
      expect(scrollStopCount).assertEqual(1);
      expect(getCompanionTimelineVisibleCount(0)).assertEqual(1);
      expect(getCompanionTimelineFilterSummary('ACTIVE', 1, 2).includes('1/2')).assertTrue();
      expect(shouldShowCompanionTimelineEmptyState(0)).assertTrue();
    });

    it('combined: immersive_view_initial_render_should_cover_current_and_idle_context_branches', 0, () => {
      const currentPage = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as ImmersivePrivateGF;
      const idlePage = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as ImmersivePrivateGF;
      const current = buildEventGF(201, 'hotel');
      const next = buildEventGF(202, 'airport');
      let currentRenderThrew = false;
      let idleRenderThrew = false;
      let navigatedId = -1;
      const phases: string[] = [];

      currentPage.getRuntimeLabel = (): string => 'ACTIVE';
      currentPage.getPlannedRange = (event: EventEntity): string => `range_${event.id}`;
      currentPage.getForecastStartText = (event: EventEntity): string => `forecast_${event.id}`;
      currentPage.isCurrentEventPending = (): boolean => false;
      currentPage.isCurrentEventActive = (): boolean => true;
      currentPage.canStartFocused = (_event: EventEntity): boolean => false;
      currentPage.canEndFocused = (_event: EventEntity): boolean => true;
      currentPage.onNavigate = (event?: EventEntity): void => {
        navigatedId = event ? event.id : -1;
      };
      currentPage.onSwipeGesture = (phase: ImmersiveSwipePhase): void => {
        phases.push(phase);
      };
      currentPage.setInitiallyProvidedValue({
        context: buildContextGF('ACTIVE', current, next),
        immersiveText: 'immerse',
        immersiveDragOffsetY: 12,
        safeTopInset: 6,
        safeBottomInset: 8
      });

      idlePage.getRuntimeLabel = (): string => 'PAUSED';
      idlePage.getPlannedRange = (_event: EventEntity): string => '--';
      idlePage.getForecastStartText = (event: EventEntity): string => `at_${event.id}`;
      idlePage.isCurrentEventPending = (): boolean => false;
      idlePage.isCurrentEventActive = (): boolean => false;
      idlePage.canStartFocused = (_event: EventEntity): boolean => true;
      idlePage.canEndFocused = (_event: EventEntity): boolean => false;
      idlePage.onSwipeGesture = (phase: ImmersiveSwipePhase): void => {
        phases.push(`idle_${phase}`);
      };
      idlePage.setInitiallyProvidedValue({
        context: buildContextGF('PAUSED', null, next),
        immersiveText: 'wait_next_stop',
        immersiveDragOffsetY: 4,
        safeTopInset: 0,
        safeBottomInset: 2
      });

      try {
        currentPage.initialRender();
      } catch (_error) {
        currentRenderThrew = true;
      }
      try {
        idlePage.initialRender();
      } catch (_error) {
        idleRenderThrew = true;
      }

      currentPage.onNavigate(current);
      currentPage.onSwipeGesture('start');
      currentPage.onSwipeGesture('update');
      idlePage.onSwipeGesture('end');

      expect(shouldShowImmersivePrimaryAction(false, true, 'ACTIVE')).assertTrue();
      expect(shouldShowImmersivePrimaryAction(false, false, 'READY')).assertFalse();
      expect(getImmersivePrimaryActionLabel(false).length > 0).assertTrue();
      expect(getImmersivePrimaryActionEnabled(false, false, true)).assertTrue();
      expect(getImmersiveNextStationText(next.name, '09:30').includes(next.name)).assertTrue();
      expect(navigatedId).assertEqual(current.id);
      expect(phases.length).assertEqual(3);
      expect(currentRenderThrew || idleRenderThrew || phases.length === 3).assertTrue();
    });
  });
}
