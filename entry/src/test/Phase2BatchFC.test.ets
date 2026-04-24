import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  CompanionCardPhase,
  getCompanionCardOpacity,
  getCompanionCardScale,
  getCompanionCardTranslateX,
  getCompanionInteractiveEnabled
} from '../main/ets/pages/components/views/companion/CompanionAnimationHelper';
import {
  getCompanionSwipeUpdate,
  shouldCompanionEnterControlMode
} from '../main/ets/pages/components/views/companion/CompanionSwipeHelper';
import {
  CompanionFilterState,
  getCompanionFilterBorderType,
  getCompanionFilterBorderWidth,
  isCompanionFilterSelected,
  shouldShowCompanionFilterPage
} from '../main/ets/pages/components/views/companion/CompanionFilterPage';
import {
  getCompanionControlCurrentEventId,
  resolveCompanionControlCardOpacity,
  resolveCompanionControlCardScale,
  resolveCompanionControlCardTranslateX,
  shouldShowCompanionWeatherCard
} from '../main/ets/pages/components/views/companion/CompanionControlPage';
import {
  getCompanionPopupHeight,
  getCompanionPopupLine,
  getCompanionPopupWidth
} from '../main/ets/pages/components/views/companion/CompanionWeatherPopups';

function buildEventFC(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  return event;
}

export default function phase2BatchFCTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFC_companion_helpers', () => {
    it('normal: companion_animation_helpers_should_resolve_interaction_and_switch_phases', 0, () => {
      const outgoing: CompanionCardPhase = 'outgoing';
      const incoming: CompanionCardPhase = 'incoming';

      expect(getCompanionInteractiveEnabled('immersive', 'both')).assertTrue();
      expect(getCompanionInteractiveEnabled('control', 'control')).assertTrue();
      expect(getCompanionInteractiveEnabled('immersive', 'control')).assertFalse();
      expect(getCompanionCardTranslateX(false, 0.5, outgoing)).assertEqual(0);
      expect(getCompanionCardTranslateX(true, 0.5, outgoing)).assertEqual(-9);
      expect(getCompanionCardTranslateX(true, 0.5, incoming)).assertEqual(9);
      expect(getCompanionCardOpacity(false, 0.5, outgoing)).assertEqual(1);
      expect(getCompanionCardOpacity(true, 0.25, outgoing)).assertEqual(0.75);
      expect(getCompanionCardOpacity(true, 0.25, incoming)).assertEqual(0.25);
      expect(getCompanionCardScale(false, 0.5, incoming)).assertEqual(1);
      expect(getCompanionCardScale(true, 1, outgoing)).assertEqual(0.985);
      expect(getCompanionCardScale(true, 1, incoming)).assertEqual(1);
    });

    it('boundary: companion_swipe_helpers_should_clamp_drag_and_detect_velocity', 0, () => {
      const positive = getCompanionSwipeUpdate(12, 20, 1000);
      const upward = getCompanionSwipeUpdate(-100, 20, 1001);
      const clamped = getCompanionSwipeUpdate(-1000, 20, 1002);

      expect(positive.peakDistance).assertEqual(20);
      expect(positive.dragOffsetY).assertEqual(0);
      expect(upward.peakDistance).assertEqual(100);
      expect(upward.dragOffsetY).assertEqual(-38);
      expect(clamped.peakDistance).assertEqual(1000);
      expect(clamped.dragOffsetY).assertEqual(-150);
      expect(shouldCompanionEnterControlMode(120, 0, 100, 200, 100, 2)).assertTrue();
      expect(shouldCompanionEnterControlMode(0, -40, 100, 110, 100, 2)).assertTrue();
      expect(shouldCompanionEnterControlMode(0, -20, 100, 200, 100, 2)).assertFalse();
    });

    it('combined: companion_filter_helpers_should_resolve_selection_and_border_types', 0, () => {
      const pending: CompanionFilterState = 'PENDING';
      const skipped: CompanionFilterState = 'SKIPPED';
      const completed: CompanionFilterState = 'COMPLETED';
      const all: CompanionFilterState = 'ALL';

      expect(shouldShowCompanionFilterPage(true)).assertTrue();
      expect(shouldShowCompanionFilterPage(false)).assertFalse();
      expect(isCompanionFilterSelected(pending, pending)).assertTrue();
      expect(isCompanionFilterSelected(pending, all)).assertFalse();
      expect(getCompanionFilterBorderWidth(pending, pending)).assertEqual(1);
      expect(getCompanionFilterBorderWidth(pending, all)).assertEqual(0);
      expect(getCompanionFilterBorderType(pending)).assertEqual('pending');
      expect(getCompanionFilterBorderType(skipped)).assertEqual('skipped');
      expect(getCompanionFilterBorderType(completed)).assertEqual('completed');
      expect(getCompanionFilterBorderType(all)).assertEqual('default');
    });

    it('regression: companion_control_helpers_should_delegate_card_animation_and_current_event', 0, () => {
      const event = buildEventFC(42);

      expect(shouldShowCompanionWeatherCard(true)).assertTrue();
      expect(shouldShowCompanionWeatherCard(false)).assertFalse();
      expect(getCompanionControlCurrentEventId(event)).assertEqual(42);
      expect(getCompanionControlCurrentEventId(null)).assertEqual(-1);
      expect(resolveCompanionControlCardTranslateX(true, 0.5, 'outgoing')).assertEqual(-9);
      expect(resolveCompanionControlCardOpacity(true, 0.5, 'incoming')).assertEqual(0.5);
      expect(resolveCompanionControlCardScale(true, 1, 'incoming')).assertEqual(1);
    });

    it('invalid: companion_popup_helpers_should_guard_missing_lines_and_unknown_kinds', 0, () => {
      const lines: string[] = ['a', '', 'c'];

      expect(getCompanionPopupLine(lines, -1)).assertEqual('');
      expect(getCompanionPopupLine(lines, 0)).assertEqual('a');
      expect(getCompanionPopupLine(lines, 1)).assertEqual('');
      expect(getCompanionPopupLine(lines, 3)).assertEqual('');
      expect(getCompanionPopupHeight('suggestion')).assertEqual(240);
      expect(getCompanionPopupHeight('score')).assertEqual(230);
      expect(getCompanionPopupWidth('suggestion')).assertEqual(290);
      expect(getCompanionPopupWidth('hint')).assertEqual(280);
    });
  });
}
