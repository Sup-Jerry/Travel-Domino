import { describe, it, expect } from '@ohos/hypium';
import {
  CompanionImmersiveView,
  getImmersiveNextStationText,
  getImmersivePrimaryActionEnabled,
  getImmersivePrimaryActionLabel,
  resolveImmersiveCurrentRenderSections,
  resolveImmersiveNextRenderEvents,
  resolveImmersivePrimaryActionSlots,
  shouldShowImmersivePrimaryAction,
  ImmersiveSwipePhase
} from '../main/ets/pages/components/views/companion/CompanionImmersiveView';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionContext, CompanionRuntimeState } from '../main/ets/viewmodel/TimelineViewModel';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';

interface CompanionImmersivePaletteTest {
  textPrimary: Object;
  textSecondary: Object;
  immersiveBg: Object;
  primary: Object;
}

interface CompanionImmersiveViewParamsTest {
  context?: CompanionContext;
  immersiveText?: string;
  immersiveDragOffsetY?: number;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface CompanionImmersiveViewPrivateTest {
  context: CompanionContext;
  immersiveText: string;
  immersiveDragOffsetY: number;
  safeTopInset: number;
  safeBottomInset: number;
  effectiveTheme: string;
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
  hasCurrentEvent(): boolean;
  shouldRenderPrimaryAction(): boolean;
  getPrimaryActionBackgroundColor(): Object;
  hasNextEvent(): boolean;
  handlePrimaryActionClick(): Promise<void>;
  handleNavigateClick(): void;
  handleSwipeStart(event: GestureEvent): void;
  handleSwipeUpdate(event: GestureEvent): void;
  handleSwipeEnd(event: GestureEvent): void;
  setInitiallyProvidedValue(params: CompanionImmersiveViewParamsTest): void;
  updateStateVars(params: CompanionImmersiveViewParamsTest): void;
  getThemePalette(): CompanionImmersivePaletteTest;
}

function buildImmersiveEvent(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

function buildImmersiveContext(runtimeState: CompanionRuntimeState, current: EventEntity | null, next: EventEntity | null): CompanionContext {
  const context = {} as CompanionContext;
  context.runtimeState = runtimeState;
  context.currentEvent = current;
  context.nextEvent = next;
  context.hint = null;
  return context;
}

export default function companionImmersiveViewHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionImmersiveViewHelper', () => {
    it('normal: primary_action_should_show_when_pending', 0, () => {
      // Arrange
      const isPending = true;

      // Act
      const visible = shouldShowImmersivePrimaryAction(isPending, false, 'READY');

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: primary_action_should_show_when_runtime_paused_even_without_active_flags', 0, () => {
      // Arrange
      const runtimeState = 'PAUSED';

      // Act
      const visible = shouldShowImmersivePrimaryAction(false, false, runtimeState);

      // Assert
      expect(visible).assertTrue();
    });

    it('invalid: primary_action_enabled_should_be_false_when_guards_are_both_false', 0, () => {
      // Arrange
      const isPending = false;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, false, false);

      // Assert
      expect(enabled).assertFalse();
    });

    it('conflict: pending_branch_should_prioritize_start_guard_over_end_guard', 0, () => {
      // Arrange
      const isPending = true;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, true, false);
      const label = getImmersivePrimaryActionLabel(isPending);

      // Assert
      expect(enabled).assertTrue();
      expect(label.length > 0).assertTrue();
    });

    it('regression: next_station_text_should_keep_name_and_forecast_placeholder', 0, () => {
      // Arrange
      const name = 'museum';
      const forecast = '--:--';

      // Act
      const text = getImmersiveNextStationText(name, forecast);

      // Assert
      expect(text.includes(name)).assertTrue();
      expect(text.includes(forecast)).assertTrue();
    });

    it('combined: action_visibility_and_label_should_match_pending_active_idle_matrix', 0, () => {
      // Arrange
      const idleVisible = shouldShowImmersivePrimaryAction(false, false, 'IDLE');
      const activeVisible = shouldShowImmersivePrimaryAction(false, true, 'ACTIVE');
      const pendingLabel = getImmersivePrimaryActionLabel(true);
      const endLabel = getImmersivePrimaryActionLabel(false);

      // Act
      const matrixPass = (!idleVisible) && activeVisible && endLabel.length > 0 && pendingLabel.length > 0 && endLabel !== pendingLabel;

      // Assert
      expect(matrixPass).assertTrue();
    });

    it('boundary: primary_action_should_hide_when_not_pending_not-active_and_not-paused', 0, () => {
      // Arrange
      const runtimeState = 'READY';

      // Act
      const visible = shouldShowImmersivePrimaryAction(false, false, runtimeState);

      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: pending_enabled_should_ignore_end_guard_when_start_guard_is_false', 0, () => {
      // Arrange
      const isPending = true;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, false, true);

      // Assert
      expect(enabled).assertFalse();
    });

    it('normal: end_enabled_should_follow_end_guard_when_not_pending', 0, () => {
      // Arrange
      const isPending = false;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, false, true);
      const label = getImmersivePrimaryActionLabel(isPending);

      // Assert
      expect(enabled).assertTrue();
      expect(label.length > 0).assertTrue();
    });

    it('regression: next_station_text_should_keep_stable_prefix_and_dynamic_payload', 0, () => {
      // Arrange
      const name = 'airport';
      const forecast = '09:30';

      // Act
      const text = getImmersiveNextStationText(name, forecast);

      // Assert
      expect(text.startsWith('下一站')).assertTrue();
      expect(text.includes(name)).assertTrue();
      expect(text.includes(forecast)).assertTrue();
    });

    it('combined: immersive_render_sections_should_cover_current_idle_primary_and_next_visibility', 0, () => {
      // Arrange
      const current = buildImmersiveEvent(41, 'museum');
      const next = buildImmersiveEvent(42, 'station');

      // Act
      const currentSections = resolveImmersiveCurrentRenderSections(current);
      const idleSections = resolveImmersiveCurrentRenderSections(null);
      const visibleActions = resolveImmersivePrimaryActionSlots(true);
      const hiddenActions = resolveImmersivePrimaryActionSlots(false);
      const nextEvents = resolveImmersiveNextRenderEvents(next);
      const noNextEvents = resolveImmersiveNextRenderEvents(null);

      // Assert
      expect(currentSections.currentEvents.length).assertEqual(1);
      expect(currentSections.idleSlots.length).assertEqual(0);
      expect(idleSections.currentEvents.length).assertEqual(0);
      expect(idleSections.idleSlots.length).assertEqual(1);
      expect(visibleActions.length).assertEqual(1);
      expect(hiddenActions.length).assertEqual(0);
      expect(nextEvents.length).assertEqual(1);
      expect(noNextEvents.length).assertEqual(0);
    });

    it('combined: immersive_view_instance_should_sync_props_and_keep_default_callbacks_stable', 0, async (done: Function) => {
      // Arrange
      const page = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as CompanionImmersiveViewPrivateTest;
      const current = buildImmersiveEvent(1, 'museum');
      const next = buildImmersiveEvent(2, 'station');
      const initContext = buildImmersiveContext('READY', current, next);
      const nextContext = buildImmersiveContext('PAUSED', null, next);

      // Act
      const runtimeLabel = page.getRuntimeLabel();
      const plannedRange = page.getPlannedRange(current);
      const forecastText = page.getForecastStartText(next);
      const pending = page.isCurrentEventPending();
      const active = page.isCurrentEventActive();
      const canStart = page.canStartFocused(current);
      const canEnd = page.canEndFocused(current);
      await page.onStartEvent(current);
      await page.onEndEvent(current);
      page.onNavigate(current);
      page.onSwipeGesture('start');
      page.setInitiallyProvidedValue({
        context: initContext,
        immersiveText: 'keep moving',
        immersiveDragOffsetY: 12,
        safeTopInset: 8,
        safeBottomInset: 10
      });
      page.updateStateVars({
        context: nextContext,
        immersiveText: 'next stop',
        immersiveDragOffsetY: 4,
        safeTopInset: 18,
        safeBottomInset: 20
      });
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(runtimeLabel).assertEqual('--');
      expect(plannedRange).assertEqual('--');
      expect(forecastText).assertEqual('--');
      expect(pending).assertFalse();
      expect(active).assertFalse();
      expect(canStart).assertFalse();
      expect(canEnd).assertFalse();
      expect(page.context.runtimeState).assertEqual('PAUSED');
      expect(page.immersiveText).assertEqual('next stop');
      expect(page.immersiveDragOffsetY).assertEqual(4);
      expect(page.safeTopInset).assertEqual(18);
      expect(page.safeBottomInset).assertEqual(20);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
      expect(palette.immersiveBg).assertEqual(ThemeCenter.getPalette('dark').immersiveBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      done();
    });

    it('combined: private_action_handlers_should_cover_start_end_and_empty_current_paths', 0, async (done: Function) => {
      // Arrange
      const page = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as CompanionImmersiveViewPrivateTest;
      const current = buildImmersiveEvent(10, 'museum');
      let startId = -1;
      let endId = -1;

      page.context = buildImmersiveContext('READY', current, null);
      page.onStartEvent = async (event: EventEntity): Promise<void> => {
        startId = event.id;
      };
      page.onEndEvent = async (event: EventEntity): Promise<void> => {
        endId = event.id;
      };
      page.isCurrentEventPending = (): boolean => true;

      // Act
      await page.handlePrimaryActionClick();
      page.isCurrentEventPending = (): boolean => false;
      await page.handlePrimaryActionClick();
      page.context = buildImmersiveContext('READY', null, null);
      await page.handlePrimaryActionClick();

      // Assert
      expect(startId).assertEqual(10);
      expect(endId).assertEqual(10);
      done();
    });

    it('combined: private_navigation_and_swipe_handlers_should_forward_current_event_and_phase', 0, () => {
      // Arrange
      const page = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as CompanionImmersiveViewPrivateTest;
      const current = buildImmersiveEvent(20, 'station');
      const phases: string[] = [];
      let navigateId = -1;
      const gesture = { offsetY: -80 } as GestureEvent;

      page.context = buildImmersiveContext('ACTIVE', current, null);
      page.onNavigate = (event?: EventEntity): void => {
        navigateId = event?.id ?? -1;
      };
      page.onSwipeGesture = (phase: ImmersiveSwipePhase, event?: GestureEvent): void => {
        phases.push(`${phase}:${event ? 'event' : 'none'}`);
      };

      // Act
      page.handleNavigateClick();
      page.handleSwipeStart(gesture);
      page.handleSwipeUpdate(gesture);
      page.handleSwipeEnd(gesture);
      page.context = buildImmersiveContext('ACTIVE', null, null);
      page.handleNavigateClick();

      // Assert
      expect(navigateId).assertEqual(-1);
      expect(phases.length).assertEqual(3);
      expect(phases[0]).assertEqual('start:event');
      expect(phases[1]).assertEqual('update:event');
      expect(phases[2]).assertEqual('end:event');
    });

    it('combined: private_view_state_helpers_should_cover_current_next_and_primary_action_branches', 0, () => {
      // Arrange
      const page = new CompanionImmersiveView(undefined, {} as LocalStorage) as Object as CompanionImmersiveViewPrivateTest;
      const current = buildImmersiveEvent(30, 'airport');
      const next = buildImmersiveEvent(31, 'hotel');

      page.context = buildImmersiveContext('PAUSED', current, next);
      page.effectiveTheme = 'dark';
      page.isCurrentEventPending = (): boolean => true;
      page.isCurrentEventActive = (): boolean => false;
      const successColor = ThemeCenter.getPalette('dark').success;
      const warningColor = ThemeCenter.getPalette('dark').warning;

      // Act
      const hasCurrent = page.hasCurrentEvent();
      const hasNext = page.hasNextEvent();
      const pausedVisible = page.shouldRenderPrimaryAction();
      const pendingColor = page.getPrimaryActionBackgroundColor();
      page.isCurrentEventPending = (): boolean => false;
      page.context = buildImmersiveContext('READY', null, null);
      const idleVisible = page.shouldRenderPrimaryAction();
      const endingColor = page.getPrimaryActionBackgroundColor();

      // Assert
      expect(hasCurrent).assertTrue();
      expect(hasNext).assertTrue();
      expect(pausedVisible).assertTrue();
      expect(idleVisible).assertFalse();
      expect(pendingColor).assertEqual(successColor);
      expect(endingColor).assertEqual(warningColor);
      expect(page.hasCurrentEvent()).assertFalse();
      expect(page.hasNextEvent()).assertFalse();
    });
  });
}
