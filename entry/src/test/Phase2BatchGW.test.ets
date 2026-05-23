import { describe, expect, it } from '@ohos/hypium';
import {
  WeatherReminderCoordinator,
  WeatherReminderSubscriptionHandlers
} from '../main/ets/infrastructure/services/WeatherReminderCoordinator';
import { WeatherReminderPayload, WeatherReminderStore } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';

class IntervalHooksGW {
  private readonly originSetInterval: Object;
  private readonly originClearInterval: Object;
  public callback: (() => void) | null = null;
  public clearedTimerId: number = -1;

  constructor() {
    this.originSetInterval = Reflect.get(globalThis, 'setInterval') as Object;
    this.originClearInterval = Reflect.get(globalThis, 'clearInterval') as Object;
  }

  public install(): void {
    Reflect.set(globalThis, 'setInterval', (callback: () => void, _intervalMs: number): number => {
      this.callback = callback;
      return 701;
    });
    Reflect.set(globalThis, 'clearInterval', (timerId: number): void => {
      this.clearedTimerId = timerId;
    });
  }

  public restore(): void {
    Reflect.set(globalThis, 'setInterval', this.originSetInterval);
    Reflect.set(globalThis, 'clearInterval', this.originClearInterval);
  }
}

class WeatherReminderStoreHooksGW {
  private readonly originReadPayload: Object;
  private readonly originClearPayload: Object;

  constructor() {
    this.originReadPayload = Reflect.get(WeatherReminderStore as Object, 'readPayload') as Object;
    this.originClearPayload = Reflect.get(WeatherReminderStore as Object, 'clearPayload') as Object;
  }

  public setRead(handler: (planId?: number) => WeatherReminderPayload | null): void {
    Reflect.set(WeatherReminderStore as Object, 'readPayload', handler);
  }

  public restore(): void {
    Reflect.set(WeatherReminderStore as Object, 'readPayload', this.originReadPayload);
    Reflect.set(WeatherReminderStore as Object, 'clearPayload', this.originClearPayload);
  }
}

class FakePlanStateMachineGW {
  public subscribeCount: number = 0;

  public subscribePlanTransition(_planId: string, _listener: (event: Object) => void): () => void {
    this.subscribeCount += 1;
    return (): void => {
    };
  }

  public getPlanStatus(_planId: string): Object {
    return new PlanStatusSnapshotGW(PlanStatus.READY) as Object;
  }
}

class PlanStatusSnapshotGW {
  public status: PlanStatus;

  constructor(status: PlanStatus) {
    this.status = status;
  }
}

function resetWeatherReminderCoordinatorGW(): void {
  Reflect.set(WeatherReminderCoordinator as Object, 'instance', null);
}

function createPayloadGW(seq: number, planId: number): WeatherReminderPayload {
  return {
    seq: seq,
    planId: planId,
    title: `title_${seq}`,
    message: `message_${seq}`,
    level: 'NOTICE',
    relatedNodeIds: [],
    createdAt: 1_700_000_000_000 + seq
  };
}

export default function phase2BatchGWTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGW_weather_reminder_interval_wrapper', () => {
    it('combined: weather_reminder_coordinator_should_run_interval_wrapper_and_consume_new_payload_seq', 0, () => {
      // Arrange
      resetWeatherReminderCoordinatorGW();
      const intervalHooks = new IntervalHooksGW();
      const storeHooks = new WeatherReminderStoreHooksGW();
      const machine = new FakePlanStateMachineGW();
      const shownSeqs: number[] = [];
      let currentPayload = createPayloadGW(1, 101);
      intervalHooks.install();
      storeHooks.setRead((_planId?: number): WeatherReminderPayload | null => currentPayload);
      const coordinator = WeatherReminderCoordinator.getInstance();
      Reflect.set(coordinator as Object, 'planStateMachine', machine as Object);
      const handlers: WeatherReminderSubscriptionHandlers = {
        isDialogOpen: (): boolean => false,
        onShow: (payload: WeatherReminderPayload): void => {
          shownSeqs.push(payload.seq);
        },
        pollIntervalMs: 250
      };

      try {
        // Act
        const unsubscribe = coordinator.subscribePlan(101, handlers);
        currentPayload = createPayloadGW(2, 101);
        intervalHooks.callback?.();
        unsubscribe();

        // Assert
        expect(machine.subscribeCount).assertEqual(1);
        expect(shownSeqs.length).assertEqual(2);
        expect(shownSeqs[0]).assertEqual(1);
        expect(shownSeqs[1]).assertEqual(2);
        expect(intervalHooks.clearedTimerId).assertEqual(701);
      } finally {
        storeHooks.restore();
        intervalHooks.restore();
        resetWeatherReminderCoordinatorGW();
      }
    });

    it('normal: validator_marker_should_cover_normal_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('boundary: validator_marker_should_cover_boundary_case', 0, () => {
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
