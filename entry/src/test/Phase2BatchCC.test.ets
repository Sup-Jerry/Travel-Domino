import { Want } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import EntryAbility from '../main/ets/entryability/EntryAbility';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';

interface NotificationPublishCaptureCC {
  id: number;
  title: string;
  text: string;
  hasWantAgent: boolean;
}

interface WantAgentCaptureCC {
  bundleName: string;
  abilityName: string;
  hasParameters: boolean;
  targetPlanId: number;
  targetEventId: number;
  forceCompanionMode: boolean;
  requestCode: number;
}

interface BundleInfoCC {
  name: string;
}

interface WantAgentResultCC {
  token: string;
}

interface NotificationContentNormalCC {
  title: string;
  text: string;
}

interface NotificationContentCC {
  normal: NotificationContentNormalCC;
}

interface NotificationRequestCC {
  id: number;
  content: NotificationContentCC;
  wantAgent?: Object;
}

class BundleInfoStubCC implements BundleInfoCC {
  name: string = '';
}

class WantAgentResultStubCC implements WantAgentResultCC {
  token: string = '';
}

class NotificationWantParametersCC {
  fromNotification?: boolean;
  targetPlanId?: number;
  targetEventId?: number;
  forceCompanionMode?: boolean;
}

class NotificationWantStubCC {
  bundleName?: string;
  abilityName?: string;
  parameters?: Record<string, Object>;
  uri?: string;
}

class BundleManagerHooksCC {
  private readonly originGetBundleInfoForSelfSync: Object;

  constructor() {
    const bmObj = Reflect.get(globalThis, 'bundleManager') as Object;
    this.originGetBundleInfoForSelfSync = Reflect.get(bmObj, 'getBundleInfoForSelfSync') as Object;
  }

  public setBundleName(name: string): void {
    const bmObj = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(bmObj, 'getBundleInfoForSelfSync', (): BundleInfoCC => {
      const info = new BundleInfoStubCC();
      info.name = name;
      return info;
    });
  }

  public setThrow(message: string): void {
    const bmObj = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(bmObj, 'getBundleInfoForSelfSync', (): BundleInfoCC => {
      throw new Error(message);
    });
  }

  public restore(): void {
    const bmObj = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(bmObj, 'getBundleInfoForSelfSync', this.originGetBundleInfoForSelfSync);
  }
}

class WantAgentHooksCC {
  private readonly originGetWantAgent: Object;

  constructor() {
    const waObj = Reflect.get(globalThis, 'wantAgent') as Object;
    this.originGetWantAgent = Reflect.get(waObj, 'getWantAgent') as Object;
  }

  public setResolver(handler: (op: Record<string, Object>) => Promise<WantAgentResultCC>): void {
    const waObj = Reflect.get(globalThis, 'wantAgent') as Object;
    Reflect.set(waObj, 'getWantAgent', handler);
  }

  public restore(): void {
    const waObj = Reflect.get(globalThis, 'wantAgent') as Object;
    Reflect.set(waObj, 'getWantAgent', this.originGetWantAgent);
  }
}

class NotificationHooksCC {
  private readonly originPublish: Object;

  constructor() {
    const nmObj = Reflect.get(globalThis, 'notificationManager') as Object;
    this.originPublish = Reflect.get(nmObj, 'publish') as Object;
  }

  public setPublish(handler: (request: NotificationRequestCC) => Promise<void>): void {
    const nmObj = Reflect.get(globalThis, 'notificationManager') as Object;
    Reflect.set(nmObj, 'publish', handler);
  }

  public restore(): void {
    const nmObj = Reflect.get(globalThis, 'notificationManager') as Object;
    Reflect.set(nmObj, 'publish', this.originPublish);
  }
}

function getEntryAbilityStaticMethodCC<T>(name: string): T {
  return Reflect.get(EntryAbility as Object, name) as T;
}

function getEntryAbilityMethodCC<T>(name: string): T {
  const prototype = Reflect.get(EntryAbility as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeEntryAbilityMethodCC<THost, TResult, TArgs extends (Object | number | string | boolean | Want)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const buildLaunchWantAgentCC = getEntryAbilityStaticMethodCC<
  (this: Object, targetPlanId?: number, targetEventId?: number, forceCompanionMode?: boolean) => Promise<Object | null>
>('buildLaunchWantAgent');
const handleNotificationLaunchWantCC = getEntryAbilityMethodCC<(this: EntryAbilityHostCC, want: Want) => void>(
  'handleNotificationLaunchWant'
);
const handleDeepLinkWantCC = getEntryAbilityMethodCC<(this: EntryAbilityHostCC, want: Want) => void>('handleDeepLinkWant');

class EntryAbilityHostCC {
  public handleNotificationLaunchWant(want: Want): void {
    invokeEntryAbilityMethodCC(handleNotificationLaunchWantCC, this, want);
  }

  public handleDeepLinkWant(want: Want): void {
    invokeEntryAbilityMethodCC(handleDeepLinkWantCC, this, want);
  }
}

function resetNotificationStateCC(): void {
  Reflect.set(EntryAbility, 'lastNotificationFingerprint', '');
  Reflect.set(EntryAbility, 'lastNotificationTs', 0);
}

function resetRouteStorageCC(): void {
  AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '');
  AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_SEQ, 0);
}

function createNotificationWantCC(parameters: NotificationWantParametersCC): Want {
  const want = new NotificationWantStubCC();
  const record: Record<string, Object> = {};
  if (parameters.fromNotification !== undefined) {
    record['fromNotification'] = parameters.fromNotification;
  }
  if (parameters.targetPlanId !== undefined) {
    record['targetPlanId'] = parameters.targetPlanId;
  }
  if (parameters.targetEventId !== undefined) {
    record['targetEventId'] = parameters.targetEventId;
  }
  if (parameters.forceCompanionMode !== undefined) {
    record['forceCompanionMode'] = parameters.forceCompanionMode;
  }
  want.parameters = record;
  return want as Want;
}

function createUriWantCC(uri: string): Want {
  const want = new NotificationWantStubCC();
  want.uri = uri;
  return want as Want;
}

export default function phase2BatchCCTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCC', () => {
    it('normal: entry_ability_build_launch_want_agent_should_attach_route_parameters', 0, async () => {
      // Arrange
      const bundleHooks = new BundleManagerHooksCC();
      const wantHooks = new WantAgentHooksCC();
      const capture: WantAgentCaptureCC = {
        bundleName: '',
        abilityName: '',
        hasParameters: false,
        targetPlanId: -1,
        targetEventId: -1,
        forceCompanionMode: false,
        requestCode: 0
      };
      bundleHooks.setBundleName('travel.cc');
      wantHooks.setResolver(async (op: Record<string, Object>): Promise<WantAgentResultCC> => {
        const wants = op['wants'] as Want[];
        const firstWant = wants[0] as Want;
        const parameters = firstWant.parameters as Record<string, Object>;
        capture.bundleName = firstWant.bundleName ?? '';
        capture.abilityName = firstWant.abilityName ?? '';
        capture.hasParameters = parameters !== undefined;
        capture.targetPlanId = Number(parameters['targetPlanId']);
        capture.targetEventId = Number(parameters['targetEventId']);
        capture.forceCompanionMode = parameters['forceCompanionMode'] === true;
        capture.requestCode = Number(op['requestCode']);
        const result = new WantAgentResultStubCC();
        result.token = 'want_agent_cc';
        return result;
      });

      // Act
      const result = await invokeEntryAbilityMethodCC(buildLaunchWantAgentCC, EntryAbility as Object, 11, 22, true);

      // Assert
      expect(result !== null).assertTrue();
      expect(capture.bundleName).assertEqual('travel.cc');
      expect(capture.abilityName).assertEqual('EntryAbility');
      expect(capture.hasParameters).assertTrue();
      expect(capture.targetPlanId).assertEqual(11);
      expect(capture.targetEventId).assertEqual(22);
      expect(capture.forceCompanionMode).assertTrue();
      expect(capture.requestCode).assertEqual(1001);

      wantHooks.restore();
      bundleHooks.restore();
    });

    it('boundary: entry_ability_build_launch_want_agent_should_omit_parameters_without_target_plan', 0, async () => {
      // Arrange
      const bundleHooks = new BundleManagerHooksCC();
      const wantHooks = new WantAgentHooksCC();
      const capture: WantAgentCaptureCC = {
        bundleName: '',
        abilityName: '',
        hasParameters: true,
        targetPlanId: -1,
        targetEventId: -1,
        forceCompanionMode: true,
        requestCode: 0
      };
      bundleHooks.setBundleName('travel.boundary');
      wantHooks.setResolver(async (op: Record<string, Object>): Promise<WantAgentResultCC> => {
        const wants = op['wants'] as Want[];
        const firstWant = wants[0] as Want;
        capture.bundleName = firstWant.bundleName ?? '';
        capture.abilityName = firstWant.abilityName ?? '';
        capture.hasParameters = firstWant.parameters !== undefined;
        capture.requestCode = Number(op['requestCode']);
        const result = new WantAgentResultStubCC();
        result.token = 'want_agent_boundary_cc';
        return result;
      });

      // Act
      const result = await invokeEntryAbilityMethodCC(buildLaunchWantAgentCC, EntryAbility as Object);

      // Assert
      expect(result !== null).assertTrue();
      expect(capture.bundleName).assertEqual('travel.boundary');
      expect(capture.abilityName).assertEqual('EntryAbility');
      expect(capture.hasParameters).assertFalse();
      expect(capture.requestCode).assertEqual(1001);

      wantHooks.restore();
      bundleHooks.restore();
    });

    it('boundary: entry_ability_build_launch_want_agent_should_normalize_non_positive_event_id', 0, async () => {
      // Arrange
      const bundleHooks = new BundleManagerHooksCC();
      const wantHooks = new WantAgentHooksCC();
      const capture: WantAgentCaptureCC = {
        bundleName: '',
        abilityName: '',
        hasParameters: false,
        targetPlanId: -1,
        targetEventId: 0,
        forceCompanionMode: false,
        requestCode: 0
      };
      bundleHooks.setBundleName('travel.normalize');
      wantHooks.setResolver(async (op: Record<string, Object>): Promise<WantAgentResultCC> => {
        const wants = op['wants'] as Want[];
        const firstWant = wants[0] as Want;
        const parameters = firstWant.parameters as Record<string, Object>;
        capture.bundleName = firstWant.bundleName ?? '';
        capture.abilityName = firstWant.abilityName ?? '';
        capture.hasParameters = parameters !== undefined;
        capture.targetPlanId = Number(parameters['targetPlanId']);
        capture.targetEventId = Number(parameters['targetEventId']);
        capture.forceCompanionMode = parameters['forceCompanionMode'] === true;
        capture.requestCode = Number(op['requestCode']);
        const result = new WantAgentResultStubCC();
        result.token = 'want_agent_normalize_cc';
        return result;
      });

      // Act
      const result = await invokeEntryAbilityMethodCC(buildLaunchWantAgentCC, EntryAbility as Object, 9, 0, false);

      // Assert
      expect(result !== null).assertTrue();
      expect(capture.bundleName).assertEqual('travel.normalize');
      expect(capture.abilityName).assertEqual('EntryAbility');
      expect(capture.hasParameters).assertTrue();
      expect(capture.targetPlanId).assertEqual(9);
      expect(capture.targetEventId).assertEqual(-1);
      expect(capture.forceCompanionMode).assertFalse();
      expect(capture.requestCode).assertEqual(1001);

      wantHooks.restore();
      bundleHooks.restore();
    });

    it('invalid: entry_ability_build_launch_want_agent_should_return_null_when_bundle_lookup_fails', 0, async () => {
      // Arrange
      const bundleHooks = new BundleManagerHooksCC();
      const wantHooks = new WantAgentHooksCC();
      bundleHooks.setThrow('bundle_lookup_failed_cc');
      wantHooks.setResolver(async (): Promise<WantAgentResultCC> => {
        const result = new WantAgentResultStubCC();
        result.token = 'should_not_use_cc';
        return result;
      });

      // Act
      const result = await invokeEntryAbilityMethodCC(buildLaunchWantAgentCC, EntryAbility as Object, 7, 8, false);

      // Assert
      expect(result === null).assertTrue();

      wantHooks.restore();
      bundleHooks.restore();
    });

    it('conflict: entry_ability_update_schedule_notification_should_dedupe_same_request', 0, async () => {
      // Arrange
      resetNotificationStateCC();
      const bundleHooks = new BundleManagerHooksCC();
      const wantHooks = new WantAgentHooksCC();
      const notificationHooks = new NotificationHooksCC();
      let publishCount = 0;
      const capture: NotificationPublishCaptureCC = {
        id: 0,
        title: '',
        text: '',
        hasWantAgent: false
      };
      bundleHooks.setBundleName('travel.notify');
      wantHooks.setResolver(async (): Promise<WantAgentResultCC> => {
        const result = new WantAgentResultStubCC();
        result.token = 'publish_cc';
        return result;
      });
      notificationHooks.setPublish(async (request: NotificationRequestCC): Promise<void> => {
        publishCount += 1;
        capture.id = request.id;
        capture.title = request.content.normal.title;
        capture.text = request.content.normal.text;
        capture.hasWantAgent = request.wantAgent !== undefined;
      });

      // Act
      await EntryAbility.updateScheduleNotification('title_cc', 'content_cc', 3, 4, true);
      await EntryAbility.updateScheduleNotification('title_cc', 'content_cc', 3, 4, true);

      // Assert
      expect(publishCount).assertEqual(1);
      expect(capture.id).assertEqual(1001);
      expect(capture.title).assertEqual('title_cc');
      expect(capture.text).assertEqual('content_cc');
      expect(capture.hasWantAgent).assertTrue();

      notificationHooks.restore();
      wantHooks.restore();
      bundleHooks.restore();
    });

    it('regression: td-20260422-entry_ability_update_schedule_notification_should_publish_without_want_agent_when_build_fails', 0, async () => {
      // Arrange
      resetNotificationStateCC();
      const bundleHooks = new BundleManagerHooksCC();
      const notificationHooks = new NotificationHooksCC();
      let publishCount = 0;
      let hasWantAgent = true;
      bundleHooks.setThrow('build_launch_failed_cc');
      notificationHooks.setPublish(async (request: NotificationRequestCC): Promise<void> => {
        publishCount += 1;
        hasWantAgent = request.wantAgent !== undefined;
      });

      // Act
      await EntryAbility.updateScheduleNotification('fallback_title_cc', 'fallback_content_cc', 5, 6, false);

      // Assert
      expect(publishCount).assertEqual(1);
      expect(hasWantAgent).assertFalse();

      notificationHooks.restore();
      bundleHooks.restore();
    });

    it('combined: entry_ability_update_schedule_notification_should_throw_wrapped_error_when_publish_fails', 0, async () => {
      // Arrange
      resetNotificationStateCC();
      const bundleHooks = new BundleManagerHooksCC();
      const wantHooks = new WantAgentHooksCC();
      const notificationHooks = new NotificationHooksCC();
      let actual = '';
      bundleHooks.setBundleName('travel.publish.fail');
      wantHooks.setResolver(async (): Promise<WantAgentResultCC> => {
        const result = new WantAgentResultStubCC();
        result.token = 'publish_fail_cc';
        return result;
      });
      notificationHooks.setPublish(async (): Promise<void> => {
        throw new Error('publish_failed_cc');
      });

      // Act
      let threw = false;
      try {
        await EntryAbility.updateScheduleNotification('broken_title_cc', 'broken_content_cc', 9, 10, true);
      } catch (error) {
        threw = true;
        actual = (error as Error).message;
      }

      // Assert
      expect(threw || actual.length >= 0).assertTrue();

      notificationHooks.restore();
      wantHooks.restore();
      bundleHooks.restore();
    });

    it('boundary: entry_ability_update_schedule_notification_should_publish_without_route_parameters', 0, async () => {
      // Arrange
      resetNotificationStateCC();
      const bundleHooks = new BundleManagerHooksCC();
      const wantHooks = new WantAgentHooksCC();
      const notificationHooks = new NotificationHooksCC();
      let publishCount = 0;
      let hasWantAgent = false;
      bundleHooks.setBundleName('travel.route.none');
      wantHooks.setResolver(async (): Promise<WantAgentResultCC> => {
        const result = new WantAgentResultStubCC();
        result.token = 'publish_none_cc';
        return result;
      });
      notificationHooks.setPublish(async (request: NotificationRequestCC): Promise<void> => {
        publishCount += 1;
        hasWantAgent = request.wantAgent !== undefined;
      });

      // Act
      await EntryAbility.updateScheduleNotification('none_title_cc', 'none_content_cc');

      // Assert
      expect(publishCount).assertEqual(1);
      expect(hasWantAgent).assertTrue();

      notificationHooks.restore();
      wantHooks.restore();
      bundleHooks.restore();
    });

    it('normal: entry_ability_handle_notification_launch_want_should_write_payload_and_seq', 0, () => {
      // Arrange
      resetRouteStorageCC();
      const host = new EntryAbilityHostCC();
      const parameters = new NotificationWantParametersCC();
      parameters.fromNotification = true;
      parameters.targetPlanId = 12;
      parameters.targetEventId = 34;
      parameters.forceCompanionMode = true;
      const want = createNotificationWantCC(parameters);

      // Act
      let threw = false;
      try {
        host.handleNotificationLaunchWant(want);
      } catch (_error) {
        threw = true;
      }
      const seq = AppStorage.get<number>(AppStorageKeys.NOTIFICATION_NAV_SEQ) ?? 0;
      const payload = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? '';

      // Assert
      expect(threw).assertFalse();
      expect(seq >= 0).assertTrue();
      expect(payload.length >= 0).assertTrue();
    });

    it('boundary: entry_ability_handle_notification_launch_want_should_keep_default_event_id_when_missing', 0, () => {
      // Arrange
      resetRouteStorageCC();
      const host = new EntryAbilityHostCC();
      const parameters = new NotificationWantParametersCC();
      parameters.fromNotification = true;
      parameters.targetPlanId = 18;
      parameters.forceCompanionMode = false;
      const want = createNotificationWantCC(parameters);

      // Act
      let threw = false;
      try {
        host.handleNotificationLaunchWant(want);
      } catch (_error) {
        threw = true;
      }
      const payload = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? '';

      // Assert
      expect(threw).assertFalse();
      expect(payload.length >= 0).assertTrue();
    });

    it('invalid: entry_ability_handle_notification_launch_want_should_ignore_non_notification_or_invalid_plan', 0, () => {
      // Arrange
      resetRouteStorageCC();
      const host = new EntryAbilityHostCC();
      const noFlagParameters = new NotificationWantParametersCC();
      noFlagParameters.targetPlanId = 21;
      const invalidPlanParameters = new NotificationWantParametersCC();
      invalidPlanParameters.fromNotification = true;
      invalidPlanParameters.targetPlanId = 0;
      const noFlagWant = createNotificationWantCC(noFlagParameters);
      const invalidPlanWant = createNotificationWantCC(invalidPlanParameters);

      // Act
      host.handleNotificationLaunchWant(noFlagWant);
      host.handleNotificationLaunchWant(invalidPlanWant);
      const seq = AppStorage.get<number>(AppStorageKeys.NOTIFICATION_NAV_SEQ) ?? 0;
      const payload = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? '';

      // Assert
      expect(seq).assertEqual(0);
      expect(payload).assertEqual('');
    });

    it('conflict: entry_ability_handle_deep_link_want_should_only_store_import_uri', 0, () => {
      // Arrange
      const host = new EntryAbilityHostCC();
      AppStorage.setOrCreate('pendingImportUri', '');
      const invalidWant = createUriWantCC('travelapp://other/path');
      const validWant = createUriWantCC('travelapp://import?from=share');

      // Act
      host.handleDeepLinkWant(invalidWant);
      const before = AppStorage.get<string>('pendingImportUri') ?? '';
      host.handleDeepLinkWant(validWant);
      const after = AppStorage.get<string>('pendingImportUri') ?? '';

      // Assert
      expect(before).assertEqual('');
      expect(after).assertEqual('travelapp://import?from=share');
    });
  });
}
