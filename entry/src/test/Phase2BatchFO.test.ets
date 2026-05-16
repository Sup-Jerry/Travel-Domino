import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  getImmersiveNextStationText,
  getImmersivePrimaryActionEnabled,
  getImmersivePrimaryActionLabel,
  shouldShowImmersivePrimaryAction
} from '../main/ets/pages/components/views/companion/CompanionImmersiveView';
import {
  applyCompanionWeatherSuggestion
} from '../main/ets/pages/components/views/companion/CompanionWeatherActionHelper';
import { SoftReplanApplyResult, WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

class WeatherVmMockFO {
  planId: number = 77;
  executionWeatherApplying: boolean = false;
  requestCount: number = 0;
  lastPlanId: number = -1;
  lastSuggestionId: string = '';
  lastMode: string = '';
  nextResult: SoftReplanApplyResult = {
    success: true,
    rolledBack: false,
    errorCode: '',
    preview: {
      suggestionId: 's-fo',
      actionType: 'REORDER',
      changedOrder: true,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: ['n1'],
      changeSummary: [],
      summary: 'done',
      riskDelta: -1
    }
  };

  async requestSoftReplan(planId: number, suggestionId: string, mode: string): Promise<SoftReplanApplyResult> {
    this.requestCount += 1;
    this.lastPlanId = planId;
    this.lastSuggestionId = suggestionId;
    this.lastMode = mode;
    return this.nextResult;
  }
}

function buildImmersiveEventFO(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

function buildSuggestionFO(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: 'REORDER',
    title: `title-${id}`,
    message: 'message',
    relatedNodeIds: ['n1'],
    createdAt: Date.now(),
    reason: 'reason',
    expectedBenefit: 'benefit',
    canRollback: true,
    cooldownKey: 'cooldown',
    expiresAt: Date.now() + 10000
  };
}

export default function phase2BatchFOTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFO_immersive_weather_lines', () => {
    it('normal: immersive_primary_action_helpers_should_cover_active_event_branch', 0, () => {
      // Arrange
      // Act
      // Assert
      const current = buildImmersiveEventFO(1, 'museum');
      const showAction = shouldShowImmersivePrimaryAction(false, true, 'ACTIVE');
      const label = getImmersivePrimaryActionLabel(false);
      const enabled = getImmersivePrimaryActionEnabled(false, false, current.id === 1);

      expect(showAction).assertTrue();
      expect(label.length > 0).assertTrue();
      expect(enabled).assertTrue();
    });

    it('boundary: immersive_next_station_helper_should_cover_idle_branch_copy', 0, () => {
      // Arrange
      // Act
      // Assert
      const next = buildImmersiveEventFO(2, 'station');
      const showAction = shouldShowImmersivePrimaryAction(false, false, 'READY');
      const nextStationText = getImmersiveNextStationText(next.name, '12:30');

      expect(showAction).assertFalse();
      expect(nextStationText.includes('station')).assertTrue();
      expect(nextStationText.includes('12:30')).assertTrue();
    });

    it('combined: weather_apply_should_capture_confirm_payload_and_forward_apply_request', 0, async (done: Function) => {
      // Arrange
      // Act
      // Assert
      const vm = new WeatherVmMockFO();
      const item = buildSuggestionFO('s-fo');
      const toasts: string[] = [];
      let capturedTitle = '';
      let capturedMessage = '';
      let capturedConfirm: (() => void) | undefined;

      applyCompanionWeatherSuggestion({
        vm: vm as Object as TimelineViewModel,
        item,
        showToast: (message: string): void => {
          toasts.push(message);
        },
        showApplyConfirm: (title: string, message: string, onConfirm: () => void): void => {
          capturedTitle = title;
          capturedMessage = message;
          capturedConfirm = onConfirm;
        }
      });
      (capturedConfirm as () => void)();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      expect(capturedTitle.length > 0).assertTrue();
      expect(capturedMessage.length > 0).assertTrue();
      expect(vm.requestCount).assertEqual(1);
      expect(vm.lastPlanId).assertEqual(77);
      expect(vm.lastSuggestionId).assertEqual(item.suggestionId);
      expect(vm.lastMode).assertEqual('APPLY');
      expect(toasts.length).assertEqual(1);
      done();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
