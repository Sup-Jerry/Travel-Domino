import { describe, expect, it } from '@ohos/hypium';
import { AvatarService } from '../main/ets/infrastructure/avatar/AvatarService';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { WeatherReminderCoordinator } from '../main/ets/infrastructure/services/WeatherReminderCoordinator';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { StateEventBus } from '../main/ets/domain/statemachine/StateEventBus';
import { QRCodeService } from '../main/ets/domain/services/QRCodeService';

interface AvatarServicePrivateBF {
  errorMessage: (error: Object) => string;
}

interface AmapWeatherPrivateBF {
  readAsText: (value?: string) => string;
  readAsNumber: (value?: string) => number;
  snapshotToInfo: (snapshot: Object) => WeatherInfo;
}

interface WeatherReminderCoordinatorPrivateBF {
  isTerminalStatus: (status: PlanStatus) => boolean;
}

interface UserProfileRepoPrivateBF {
  toTimestamp: (rawValue: Object | number | undefined) => number;
}

interface StateEventBusPrivateBF {
  normalizePlanId: (planId: string) => string;
}

class WeatherSnapshotInputBF {
  temperatureCelsius: number = 0;
  conditionText: string = '';
  conditionCode: string = '';
  humidity: number = 0;
  windSpeed: number = 0;
  cityCode: string = '';
}

class NumericStringValueBF {
  private readonly raw: string;

  constructor(raw: string) {
    this.raw = raw;
  }

  toString(): string {
    return this.raw;
  }
}

export default function phase2BatchBFTest() {
  describe('phase2BatchBF_private_guards', () => {
    it('normal: avatar_error_message_should_return_original_error_message', 0, () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateBF;
      const error = new Error('avatar_fail_bf');
      // Act
      const message = privateApi.errorMessage(error as Object);
      // Assert
      expect(message).assertEqual('avatar_fail_bf');
    });

    it('boundary: amap_read_helpers_should_trim_text_and_keep_nan_for_invalid_number', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;
      // Act
      const trimmed = privateApi.readAsText('  CLOUDY  ');
      const invalidNumber = privateApi.readAsNumber('bad_number');
      // Assert
      expect(trimmed).assertEqual('CLOUDY');
      expect(Number.isNaN(invalidNumber)).assertTrue();
    });

    it('invalid: qrcode_generate_should_reject_empty_payload', 0, async () => {
      // Arrange
      let message = '';
      // Act
      try {
        await QRCodeService.generateQRCode('   ', 200);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('qr_content_empty');
    });

    it('conflict: weather_reminder_terminal_status_should_distinguish_terminal_and_active_states', 0, () => {
      // Arrange
      const coordinator = WeatherReminderCoordinator.getInstance() as Object as WeatherReminderCoordinatorPrivateBF;
      // Act
      const completed = coordinator.isTerminalStatus(PlanStatus.COMPLETED);
      const cancelled = coordinator.isTerminalStatus(PlanStatus.CANCELLED);
      const ready = coordinator.isTerminalStatus(PlanStatus.READY);
      // Assert
      expect(completed).assertTrue();
      expect(cancelled).assertTrue();
      expect(ready).assertFalse();
    });

    it('regression: amap_snapshot_to_info_should_fallback_to_condition_code_when_text_empty', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherPrivateBF;
      const snapshot = new WeatherSnapshotInputBF();
      snapshot.temperatureCelsius = 18;
      snapshot.conditionCode = 'FOG';
      snapshot.humidity = 55;
      snapshot.windSpeed = 2;
      snapshot.cityCode = '440000';
      // Act
      const info = privateApi.snapshotToInfo(snapshot as Object);
      // Assert
      expect(info.condition).assertEqual('FOG');
      expect(info.temperature).assertEqual(18);
      expect(info.cityCode ?? '').assertEqual('440000');
    });

    it('combined: repo_and_bus_private_helpers_should_keep_timestamp_and_plan_id_normalized', 0, () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepoPrivateBF;
      const bus = new StateEventBus() as Object as StateEventBusPrivateBF;
      const numericValue = new NumericStringValueBF('13579');
      // Act
      const timestamp = repo.toTimestamp(numericValue as Object);
      const normalizedPlanId = bus.normalizePlanId('  plan_bf  ');
      // Assert
      expect(timestamp).assertEqual(13579);
      expect(normalizedPlanId).assertEqual('plan_bf');
    });
  });
}
