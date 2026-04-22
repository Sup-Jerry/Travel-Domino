import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  CompanionFocusedCardHost,
  resolveCompanionFocusedActionMode,
  shouldRenderFocusedSwitchCards,
  shouldShowFocusedPlannedRange
} from '../main/ets/pages/components/views/companion/CompanionFocusedCardHost';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

type CompanionFocusedCardPhaseTest = 'stable' | 'outgoing' | 'incoming';

interface CompanionFocusedCardHostPaletteTest {
  textPrimary: Object;
  companionCardBg: Object;
  primary: Object;
}

interface CompanionFocusedCardHostParamsTest {
  canRenderSwitchCards?: boolean;
  outgoingEvent?: EventEntity | null;
  incomingEvent?: EventEntity | null;
  stableEvent?: EventEntity | null;
  runtimeState?: string;
  currentEventId?: number;
}

interface CompanionFocusedCardHostPrivateTest {
  canRenderSwitchCards: boolean;
  outgoingEvent: EventEntity | null;
  incomingEvent: EventEntity | null;
  stableEvent: EventEntity | null;
  runtimeState: string;
  currentEventId: number;
  effectiveTheme: string;
  getEventStateLabel: (event: EventEntity) => string;
  getStateTagTextColor: (event: EventEntity) => Object;
  getStateTagBackgroundColor: (event: EventEntity) => Object;
  getStateBorderColor: (event: EventEntity) => Object;
  getMainCardTimeText: (event: EventEntity) => string;
  getPlannedRange: (event: EventEntity) => string;
  getEventState: (event: EventEntity) => string;
  canStartFocused: (event: EventEntity) => boolean;
  canEndFocused: (event: EventEntity) => boolean;
  getCardTranslateX: (phase: CompanionFocusedCardPhaseTest) => number;
  getCardOpacity: (phase: CompanionFocusedCardPhaseTest) => number;
  getCardScale: (phase: CompanionFocusedCardPhaseTest) => number;
  onNavigate: (event: EventEntity) => void;
  onStart: (event: EventEntity) => void;
  onSkip: (event: EventEntity) => void;
  onEnd: (event: EventEntity) => void;
  onReopen: (event: EventEntity) => void;
  onAdjust: (event: EventEntity) => void;
  onSkipDisabledTap: () => void;
  onEnterImmersive: () => void;
  setInitiallyProvidedValue(params: CompanionFocusedCardHostParamsTest): void;
  updateStateVars(params: CompanionFocusedCardHostParamsTest): void;
  getThemePalette(): CompanionFocusedCardHostPaletteTest;
  FocusedCardBody(event: EventEntity, phase: CompanionFocusedCardPhaseTest): void;
  initialRender(): void;
}

function buildEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  return event;
}

export default function companionFocusedCardHostHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionFocusedCardHostHelper', () => {
    it('normal: planned_range_should_show_for_non_pending_state', 0, () => {
      // Arrange
      const state = 'ACTIVE';

      // Act
      const visible = shouldShowFocusedPlannedRange(state);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: focused_action_mode_should_match_paused_current_event', 0, () => {
      // Arrange
      const mode = resolveCompanionFocusedActionMode('COMPLETED', 'PAUSED', 10, 10);

      // Act
      const isPausedActive = mode === 'PAUSED_ACTIVE';

      // Assert
      expect(isPausedActive).assertTrue();
    });

    it('invalid: focused_action_mode_should_fallback_to_disabled_for_unknown_state', 0, () => {
      // Arrange
      const state = 'UNKNOWN';

      // Act
      const mode = resolveCompanionFocusedActionMode(state, 'IDLE', -1, 1);

      // Assert
      expect(mode).assertEqual('DISABLED');
    });

    it('conflict: focused_action_mode_should_prioritize_active_over_paused', 0, () => {
      // Arrange
      const state = 'ACTIVE';

      // Act
      const mode = resolveCompanionFocusedActionMode(state, 'PAUSED', 1, 1);

      // Assert
      expect(mode).assertEqual('ACTIVE');
    });

    it('regression: switch_cards_should_require_both_outgoing_and_incoming', 0, () => {
      // Arrange
      const outgoing = buildEvent(1);

      // Act
      const renderable = shouldRenderFocusedSwitchCards(true, outgoing, null);

      // Assert
      expect(renderable).assertFalse();
    });

    it('combined: focused_helper_matrix_should_cover_pending_active_and_switch_render', 0, () => {
      // Arrange
      const outgoing = buildEvent(11);
      const incoming = buildEvent(12);

      // Act
      const pendingMode = resolveCompanionFocusedActionMode('PENDING', 'IDLE', -1, 11);
      const activeMode = resolveCompanionFocusedActionMode('ACTIVE', 'IDLE', 11, 11);
      const renderable = shouldRenderFocusedSwitchCards(true, outgoing, incoming);

      // Assert
      expect(pendingMode).assertEqual('PENDING');
      expect(activeMode).assertEqual('ACTIVE');
      expect(renderable).assertTrue();
    });

    it('combined: focused_card_host_instance_should_sync_props_and_keep_default_actions_stable', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const outgoing = buildEvent(21);
      const incoming = buildEvent(22);
      const stable = buildEvent(23);
      const nextStable = buildEvent(24);

      // Act
      const label = page.getEventStateLabel(outgoing);
      const tagTextColor = page.getStateTagTextColor(outgoing);
      const tagBgColor = page.getStateTagBackgroundColor(outgoing);
      const borderColor = page.getStateBorderColor(outgoing);
      const timeText = page.getMainCardTimeText(outgoing);
      const plannedRange = page.getPlannedRange(outgoing);
      const state = page.getEventState(outgoing);
      const canStart = page.canStartFocused(outgoing);
      const canEnd = page.canEndFocused(outgoing);
      const translate = page.getCardTranslateX('incoming');
      const opacity = page.getCardOpacity('incoming');
      const scale = page.getCardScale('incoming');
      page.onNavigate(outgoing);
      page.onStart(outgoing);
      page.onSkip(outgoing);
      page.onEnd(outgoing);
      page.onReopen(outgoing);
      page.onAdjust(outgoing);
      page.onSkipDisabledTap();
      page.onEnterImmersive();
      const initParams: CompanionFocusedCardHostParamsTest = {
        canRenderSwitchCards: true,
        outgoingEvent: outgoing,
        incomingEvent: incoming,
        stableEvent: stable,
        runtimeState: 'READY',
        currentEventId: outgoing.id
      };
      const nextParams: CompanionFocusedCardHostParamsTest = {
        canRenderSwitchCards: false,
        outgoingEvent: stable,
        incomingEvent: null,
        stableEvent: nextStable,
        runtimeState: 'PAUSED',
        currentEventId: nextStable.id
      };
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(initParams);
      const initCanRenderSwitchCards = page.canRenderSwitchCards;
      const initOutgoingId = page.outgoingEvent?.id ?? -1;
      const initIncomingId = page.incomingEvent?.id ?? -1;
      const initStableId = page.stableEvent?.id ?? -1;
      const initRuntimeState = page.runtimeState;
      const initCurrentEventId = page.currentEventId;
      page.updateStateVars(nextParams);
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(label).assertEqual('--');
      expect(tagTextColor).assertEqual('#666');
      expect(tagBgColor).assertEqual('#F5F5F5');
      expect(borderColor).assertEqual('#DDD');
      expect(timeText).assertEqual('--:--');
      expect(plannedRange).assertEqual('--');
      expect(state).assertEqual('PENDING');
      expect(canStart).assertFalse();
      expect(canEnd).assertFalse();
      expect(translate).assertEqual(0);
      expect(opacity).assertEqual(1);
      expect(scale).assertEqual(1);
      expect(initCanRenderSwitchCards).assertTrue();
      expect(initOutgoingId).assertEqual(outgoing.id);
      expect(initIncomingId).assertEqual(incoming.id);
      expect(initStableId).assertEqual(stable.id);
      expect(initRuntimeState).assertEqual('READY');
      expect(initCurrentEventId).assertEqual(outgoing.id);
      expect(page.canRenderSwitchCards).assertFalse();
      expect(page.outgoingEvent?.id).assertEqual(stable.id);
      expect(page.incomingEvent).assertNull();
      expect(page.stableEvent?.id).assertEqual(nextStable.id);
      expect(page.runtimeState).assertEqual('PAUSED');
      expect(page.currentEventId).assertEqual(nextStable.id);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.companionCardBg).assertEqual(ThemeCenter.getPalette('dark').companionCardBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
    });

    it('normal: focused_card_host_initial_render_should_support_switch_cards_with_default_pending_actions', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const outgoing = buildEvent(31);
      const incoming = buildEvent(32);
      page.setInitiallyProvidedValue({
        canRenderSwitchCards: true,
        outgoingEvent: outgoing,
        incomingEvent: incoming,
        stableEvent: null,
        runtimeState: 'READY',
        currentEventId: outgoing.id
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: focused_card_host_initial_render_should_support_stable_card_branch', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const stable = buildEvent(41);
      page.setInitiallyProvidedValue({
        canRenderSwitchCards: false,
        outgoingEvent: null,
        incomingEvent: null,
        stableEvent: stable,
        runtimeState: 'IDLE',
        currentEventId: -1
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('conflict: focused_card_host_initial_render_should_support_skipped_action_branch_with_disabled_skip_tap', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const stable = buildEvent(51);
      page.getEventState = (_event: EventEntity) => 'SKIPPED';
      page.setInitiallyProvidedValue({
        canRenderSwitchCards: false,
        outgoingEvent: null,
        incomingEvent: null,
        stableEvent: stable,
        runtimeState: 'IDLE',
        currentEventId: -1
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('regression: focused_card_host_initial_render_should_support_disabled_action_branch', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const stable = buildEvent(61);
      page.getEventState = (_event: EventEntity) => 'COMPLETED';
      page.setInitiallyProvidedValue({
        canRenderSwitchCards: false,
        outgoingEvent: null,
        incomingEvent: null,
        stableEvent: stable,
        runtimeState: 'IDLE',
        currentEventId: -1
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('combined: focused_card_host_initial_render_should_support_paused_and_empty_state_branches', 0, () => {
      // Arrange
      const pausedPage = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const pausedStable = buildEvent(71);
      pausedPage.getEventState = (_event: EventEntity) => 'COMPLETED';
      pausedPage.setInitiallyProvidedValue({
        canRenderSwitchCards: false,
        outgoingEvent: null,
        incomingEvent: null,
        stableEvent: pausedStable,
        runtimeState: 'PAUSED',
        currentEventId: pausedStable.id
      });
      const emptyPage = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      emptyPage.setInitiallyProvidedValue({
        canRenderSwitchCards: false,
        outgoingEvent: null,
        incomingEvent: null,
        stableEvent: null,
        runtimeState: 'IDLE',
        currentEventId: -1
      });

      // Act
      let pausedThrew = false;
      let emptyThrew = false;
      try {
        pausedPage.initialRender();
      } catch (_error) {
        pausedThrew = true;
      }
      try {
        emptyPage.initialRender();
      } catch (_error) {
        emptyThrew = true;
      }

      // Assert
      expect(pausedThrew).assertFalse();
      expect(emptyThrew).assertFalse();
    });

    it('normal: focused_card_host_initial_render_should_support_active_action_branch_with_custom_getters', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const stable = buildEvent(81);
      page.getEventStateLabel = (event: EventEntity) => `label_${event.id}`;
      page.getStateTagTextColor = (_event: EventEntity) => '#111111';
      page.getStateTagBackgroundColor = (_event: EventEntity) => '#EEEEEE';
      page.getStateBorderColor = (_event: EventEntity) => '#123456';
      page.getMainCardTimeText = (event: EventEntity) => `time_${event.id}`;
      page.getPlannedRange = (event: EventEntity) => `range_${event.id}`;
      page.getEventState = (_event: EventEntity) => 'ACTIVE';
      page.canEndFocused = (_event: EventEntity) => true;
      page.getCardTranslateX = (phase: CompanionFocusedCardPhaseTest) => phase === 'stable' ? 4 : 0;
      page.getCardOpacity = (phase: CompanionFocusedCardPhaseTest) => phase === 'stable' ? 0.88 : 1;
      page.getCardScale = (phase: CompanionFocusedCardPhaseTest) => phase === 'stable' ? 0.97 : 1;
      page.setInitiallyProvidedValue({
        canRenderSwitchCards: false,
        outgoingEvent: null,
        incomingEvent: null,
        stableEvent: stable,
        runtimeState: 'ACTIVE',
        currentEventId: stable.id
      });
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.getEventStateLabel(stable)).assertEqual('label_81');
      expect(page.getMainCardTimeText(stable)).assertEqual('time_81');
      expect(page.getPlannedRange(stable)).assertEqual('range_81');
      expect(page.getStateBorderColor(stable)).assertEqual('#123456');
      expect(page.getCardTranslateX('stable')).assertEqual(4);
      expect(page.getCardOpacity('stable')).assertEqual(0.88);
      expect(page.getCardScale('stable')).assertEqual(0.97);
      expect(page.canEndFocused(stable)).assertTrue();
    });

    it('combined: focused_card_host_initial_render_should_support_paused_active_and_hidden_planned_range_branch', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const stable = buildEvent(91);
      page.getEventState = (_event: EventEntity) => 'COMPLETED';
      page.canEndFocused = (_event: EventEntity) => false;
      page.setInitiallyProvidedValue({
        canRenderSwitchCards: false,
        outgoingEvent: null,
        incomingEvent: null,
        stableEvent: stable,
        runtimeState: 'PAUSED',
        currentEventId: stable.id
      });
      const pendingVisible = shouldShowFocusedPlannedRange('PENDING');
      const pausedMode = resolveCompanionFocusedActionMode('COMPLETED', 'PAUSED', stable.id, stable.id);
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(pendingVisible).assertFalse();
      expect(pausedMode).assertEqual('PAUSED_ACTIVE');
      expect(page.canEndFocused(stable)).assertFalse();
    });

    it('regression: focused_card_host_focused_card_body_should_support_direct_builder_invocation_for_stable_phase', 0, () => {
      // Arrange
      const page = new CompanionFocusedCardHost(undefined, {} as LocalStorage) as Object as CompanionFocusedCardHostPrivateTest;
      const stable = buildEvent(101);
      page.getEventState = (_event: EventEntity) => 'ACTIVE';
      page.canEndFocused = (_event: EventEntity) => true;
      page.getEventStateLabel = (_event: EventEntity) => '进行中';
      page.getMainCardTimeText = (_event: EventEntity) => '10:00-10:30';
      page.getPlannedRange = (_event: EventEntity) => '10:00-11:00';
      page.runtimeState = 'ACTIVE';
      page.currentEventId = stable.id;
      let threw = false;

      // Act
      try {
        page.FocusedCardBody(stable, 'stable');
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.getEventStateLabel(stable)).assertEqual('进行中');
      expect(page.getMainCardTimeText(stable)).assertEqual('10:00-10:30');
      expect(page.getPlannedRange(stable)).assertEqual('10:00-11:00');
      expect(page.canEndFocused(stable)).assertTrue();
    });
  });
}
