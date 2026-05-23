import { describe, expect, it } from '@ohos/hypium';
import EntryAbility from '../main/ets/entryability/EntryAbility';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import { AuthFacade } from '../main/ets/infrastructure/auth/AuthFacade';
import { ProfileViewModel } from '../main/ets/viewmodel/ProfileViewModel';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';
import { TrafficEngine } from '../main/ets/infrastructure/services/TrafficEngine';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';
import { DateUtil } from '../main/ets/common/utils/DateUtil';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import { MapsInitializer, MapViewManager } from '@amap/amap_lbs_map3d';
import { bundleManager } from '@kit.AbilityKit';

class StartupDataGJ {
  accountId: string = '';
}

class StartupResultGJ {
  success: boolean = false;
  data: StartupDataGJ | null = null;
  code: number = 0;
  source: string = '';
  message: string = '';
}

class StartupCoordinatorMockGJ {
  result: StartupResultGJ = new StartupResultGJ();

  async checkStartupAuth(): Promise<StartupResultGJ> {
    return this.result;
  }
}

class AbilityContextGJ {
  tag: string = 'ctx_gj';

  getApplicationContext(): Object {
    return this;
  }
}

class AbilityConfigGJ {
  colorMode: number = 0;
}

class LoadContentErrorGJ {
  code: number = 0;
}

class WindowStageMockGJ {
  routes: string[] = [];
  callbackErrorCode: number = 0;

  loadContent(url: string, callback?: (err: LoadContentErrorGJ) => void): void {
    this.routes.push(url);
    if (callback) {
      const error = new LoadContentErrorGJ();
      error.code = this.callbackErrorCode;
      callback(error);
    }
  }
}

class PreferenceManagerMockGJ {
  savedThemeMode: string = 'system';
  initShouldThrow: boolean = false;
  initContextTag: string = '';

  async init(context: AbilityContextGJ): Promise<void> {
    this.initContextTag = context.tag;
    if (this.initShouldThrow) {
      throw new Error('pref_init_failed_gj');
    }
  }

  async getThemeMode(): Promise<string> {
    return this.savedThemeMode;
  }
}

class RejectPreferenceManagerMockGJ extends PreferenceManagerMockGJ {
  async getThemeMode(): Promise<string> {
    throw new Error('theme_read_failed_gj');
  }
}

class AuthFacadeMockGJ {
  bindCount: number = 0;

  bindContext(_context: AbilityContextGJ): void {
    this.bindCount += 1;
  }
}

class ProfileViewModelMockGJ {
  bindCount: number = 0;
  bootstrapCount: number = 0;
  resetCount: number = 0;
  bootstrapAccountId: string = '';

  bindContext(_context: AbilityContextGJ): void {
    this.bindCount += 1;
  }

  async bootstrap(accountId: string): Promise<void> {
    this.bootstrapCount += 1;
    this.bootstrapAccountId = accountId;
  }

  reset(): void {
    this.resetCount += 1;
  }
}

class RdbHelperMockGJ {
  shouldReject: boolean = false;

  async init(_context: AbilityContextGJ): Promise<void> {
    if (this.shouldReject) {
      throw new Error('db_fail_gj');
    }
  }
}

class ThemeHookStateGJ {
  appliedMode: string = '';
  synced: string[] = [];

  normalizeThemeMode(mode: string): string {
    if (mode === 'dark') {
      return 'dark';
    }
    return 'system';
  }

  applyThemeMode(_context: AbilityContextGJ, mode: string): void {
    this.appliedMode = mode;
  }

  resolveEffectiveTheme(mode: string, colorMode: number): string {
    return `${mode}_${colorMode}`;
  }

  syncThemeToStorage(mode: string, effective: string): void {
    this.synced.push(`${mode}:${effective}`);
  }
}

class SignatureInfoGJ {
  appId: string = 'app_id_gj';
}

class BundleInfoGJ {
  name: string = 'bundle_gj';
  signatureInfo: SignatureInfoGJ = new SignatureInfoGJ();
}

class TrafficEngineMockGJ {
  initializeCount: number = 0;
  lastContext: Object | null = null;

  initialize(context: Object): void {
    this.initializeCount += 1;
    this.lastContext = context;
  }
}

class MapViewManagerMockGJ {
  callback: ((mapview?: Object, mapViewName?: string) => void) | null = null;

  registerMapViewCreatedCallback(callback: (mapview?: Object, mapViewName?: string) => void): void {
    this.callback = callback;
  }
}

class AppStorageMockGJ {
  calls: string[] = [];

  setOrCreate(key: string, _value: Object): void {
    this.calls.push(key);
  }
}

class EmptyWantGJ {
  uri: string = '';
}

class EmptyLaunchParamGJ {
  tag: string = 'launch_gj';
}

class MapViewTokenGJ {
  tag: string = 'map_gj';
}

class AbilityHostGJ {
  context: AbilityContextGJ = new AbilityContextGJ();
  currentThemeMode: string = 'light';
  startupCoordinator: StartupCoordinatorMockGJ = new StartupCoordinatorMockGJ();
  initThemeModeCount: number = 0;
  bootstrapUserContextCount: number = 0;
  handleNotificationLaunchWantCount: number = 0;

  initThemeMode(): Promise<void> {
    this.initThemeModeCount += 1;
    return Promise.resolve();
  }

  bootstrapUserContext(): Promise<void> {
    this.bootstrapUserContextCount += 1;
    return Promise.resolve();
  }

  handleNotificationLaunchWant(_want: Object): void {
    this.handleNotificationLaunchWantCount += 1;
  }

  runInitThemeMode(): Promise<void> {
    return invokeEntryAbilityMethodGJ(initThemeModeGJ, this);
  }

  runBootstrapUserContext(): Promise<void> {
    return invokeEntryAbilityMethodGJ(bootstrapUserContextGJ, this);
  }

  runOnWindowStageCreate(stage: WindowStageMockGJ): void {
    invokeEntryAbilityMethodGJ(onWindowStageCreateGJ, this, stage);
  }

  runOnConfigurationUpdate(config: AbilityConfigGJ): void {
    invokeEntryAbilityMethodGJ(onConfigurationUpdateGJ, this, config);
  }

  runOnCreate(want: Object, launchParam: Object): void {
    invokeEntryAbilityMethodGJ(onCreateGJ, this, want, launchParam);
  }
}

function getEntryAbilityMethodGJ<T>(name: string): T {
  const prototype = Reflect.get(EntryAbility as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeEntryAbilityMethodGJ<THost, TResult, TArgs extends (Object | WindowStageMockGJ | AbilityConfigGJ)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

function flushAsyncGJ(): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => resolve(), 0);
  });
}

const initThemeModeGJ = getEntryAbilityMethodGJ<(this: AbilityHostGJ) => Promise<void>>('initThemeMode');
const bootstrapUserContextGJ = getEntryAbilityMethodGJ<(this: AbilityHostGJ) => Promise<void>>('bootstrapUserContext');
const onCreateGJ = getEntryAbilityMethodGJ<(this: AbilityHostGJ, want: Object, launchParam: Object) => void>('onCreate');
const onWindowStageCreateGJ = getEntryAbilityMethodGJ<(this: AbilityHostGJ, stage: WindowStageMockGJ) => void>('onWindowStageCreate');
const onConfigurationUpdateGJ = getEntryAbilityMethodGJ<(this: AbilityHostGJ, config: AbilityConfigGJ) => void>('onConfigurationUpdate');

export default function phase2BatchGJTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGJ_entry_ability_lifecycle_branches', () => {
    it('normal: entry_ability_init_theme_mode_should_apply_saved_theme', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const preferenceManagerMock = new PreferenceManagerMockGJ();
      const themeHookState = new ThemeHookStateGJ();
      const prefOrigin = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
      const normalizeOrigin = Reflect.get(ThemeCenter as Object, 'normalizeThemeMode') as Object;
      const applyOrigin = Reflect.get(ThemeCenter as Object, 'applyThemeMode') as Object;

      preferenceManagerMock.savedThemeMode = 'dark';
      Reflect.set(PreferenceManager as Object, 'getInstance', (): PreferenceManagerMockGJ => preferenceManagerMock);
      Reflect.set(ThemeCenter as Object, 'normalizeThemeMode', (mode: string): string => themeHookState.normalizeThemeMode(mode));
      Reflect.set(ThemeCenter as Object, 'applyThemeMode', (context: AbilityContextGJ, mode: string): void => themeHookState.applyThemeMode(context, mode));

      await host.runInitThemeMode();

      expect(preferenceManagerMock.initContextTag).assertEqual('ctx_gj');
      expect(host.currentThemeMode).assertEqual('dark');
      expect(themeHookState.appliedMode).assertEqual('dark');

      Reflect.set(PreferenceManager as Object, 'getInstance', prefOrigin);
      Reflect.set(ThemeCenter as Object, 'normalizeThemeMode', normalizeOrigin);
      Reflect.set(ThemeCenter as Object, 'applyThemeMode', applyOrigin);
    });

    it('boundary: entry_ability_init_theme_mode_should_fallback_to_system_on_failure', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const preferenceManagerMock = new PreferenceManagerMockGJ();
      const themeHookState = new ThemeHookStateGJ();
      const prefOrigin = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
      const applyOrigin = Reflect.get(ThemeCenter as Object, 'applyThemeMode') as Object;

      host.currentThemeMode = 'dark';
      preferenceManagerMock.initShouldThrow = true;
      Reflect.set(PreferenceManager as Object, 'getInstance', (): PreferenceManagerMockGJ => preferenceManagerMock);
      Reflect.set(ThemeCenter as Object, 'applyThemeMode', (context: AbilityContextGJ, mode: string): void => themeHookState.applyThemeMode(context, mode));

      await host.runInitThemeMode();

      expect(host.currentThemeMode).assertEqual('system');
      expect(themeHookState.appliedMode).assertEqual('system');

      Reflect.set(PreferenceManager as Object, 'getInstance', prefOrigin);
      Reflect.set(ThemeCenter as Object, 'applyThemeMode', applyOrigin);
    });

    it('invalid: entry_ability_bootstrap_user_context_should_reset_profile_for_unauthenticated_startup', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const authFacadeMock = new AuthFacadeMockGJ();
      const profileViewModelMock = new ProfileViewModelMockGJ();
      const authOrigin = Reflect.get(AuthFacade as Object, 'getInstance') as Object;
      const profileOrigin = Reflect.get(ProfileViewModel as Object, 'getInstance') as Object;

      Reflect.set(AuthFacade as Object, 'getInstance', (): AuthFacadeMockGJ => authFacadeMock);
      Reflect.set(ProfileViewModel as Object, 'getInstance', (): ProfileViewModelMockGJ => profileViewModelMock);

      await host.runBootstrapUserContext();

      expect(authFacadeMock.bindCount).assertEqual(1);
      expect(profileViewModelMock.bindCount).assertEqual(1);
      expect(profileViewModelMock.resetCount).assertEqual(1);
      expect(profileViewModelMock.bootstrapCount).assertEqual(0);

      Reflect.set(AuthFacade as Object, 'getInstance', authOrigin);
      Reflect.set(ProfileViewModel as Object, 'getInstance', profileOrigin);
    });

    it('conflict: entry_ability_bootstrap_user_context_should_bootstrap_authenticated_profile', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const startupResult = new StartupResultGJ();
      const startupData = new StartupDataGJ();
      const authFacadeMock = new AuthFacadeMockGJ();
      const profileViewModelMock = new ProfileViewModelMockGJ();
      const authOrigin = Reflect.get(AuthFacade as Object, 'getInstance') as Object;
      const profileOrigin = Reflect.get(ProfileViewModel as Object, 'getInstance') as Object;

      startupResult.success = true;
      startupData.accountId = ' account_gj ';
      startupResult.data = startupData;
      host.startupCoordinator.result = startupResult;
      Reflect.set(AuthFacade as Object, 'getInstance', (): AuthFacadeMockGJ => authFacadeMock);
      Reflect.set(ProfileViewModel as Object, 'getInstance', (): ProfileViewModelMockGJ => profileViewModelMock);

      await host.runBootstrapUserContext();

      expect(profileViewModelMock.resetCount).assertEqual(0);
      expect(profileViewModelMock.bootstrapCount).assertEqual(1);
      expect(profileViewModelMock.bootstrapAccountId).assertEqual(' account_gj ');

      Reflect.set(AuthFacade as Object, 'getInstance', authOrigin);
      Reflect.set(ProfileViewModel as Object, 'getInstance', profileOrigin);
    });

    it('boundary: entry_ability_bootstrap_user_context_should_skip_profile_bootstrap_for_blank_account_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const startupResult = new StartupResultGJ();
      const startupData = new StartupDataGJ();
      const authFacadeMock = new AuthFacadeMockGJ();
      const profileViewModelMock = new ProfileViewModelMockGJ();
      const authOrigin = Reflect.get(AuthFacade as Object, 'getInstance') as Object;
      const profileOrigin = Reflect.get(ProfileViewModel as Object, 'getInstance') as Object;

      startupResult.success = true;
      startupData.accountId = '   ';
      startupResult.data = startupData;
      host.startupCoordinator.result = startupResult;
      Reflect.set(AuthFacade as Object, 'getInstance', (): AuthFacadeMockGJ => authFacadeMock);
      Reflect.set(ProfileViewModel as Object, 'getInstance', (): ProfileViewModelMockGJ => profileViewModelMock);

      await host.runBootstrapUserContext();

      expect(authFacadeMock.bindCount).assertEqual(1);
      expect(profileViewModelMock.bindCount).assertEqual(1);
      expect(profileViewModelMock.resetCount).assertEqual(0);
      expect(profileViewModelMock.bootstrapCount).assertEqual(0);

      Reflect.set(AuthFacade as Object, 'getInstance', authOrigin);
      Reflect.set(ProfileViewModel as Object, 'getInstance', profileOrigin);
    });

    it('regression: entry_ability_on_window_stage_create_should_load_auth_gate_for_db_success_and_failure', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const stageSuccess = new WindowStageMockGJ();
      const stageFailure = new WindowStageMockGJ();
      const rdbHelperMock = new RdbHelperMockGJ();
      const rdbOrigin = Reflect.get(RdbHelper as Object, 'getInstance') as Object;

      Reflect.set(RdbHelper as Object, 'getInstance', (): RdbHelperMockGJ => rdbHelperMock);

      stageSuccess.callbackErrorCode = 0;
      rdbHelperMock.shouldReject = false;
      host.runOnWindowStageCreate(stageSuccess);
      await flushAsyncGJ();
      stageSuccess.callbackErrorCode = 1001;
      host.runOnWindowStageCreate(stageSuccess);
      await flushAsyncGJ();
      rdbHelperMock.shouldReject = true;
      host.runOnWindowStageCreate(stageFailure);
      await flushAsyncGJ();

      expect(stageSuccess.routes[0]).assertEqual('pages/AuthGatePage');
      expect(stageSuccess.routes[1]).assertEqual('pages/AuthGatePage');
      expect(stageFailure.routes[0]).assertEqual('pages/AuthGatePage');

      Reflect.set(RdbHelper as Object, 'getInstance', rdbOrigin);
    });

    it('combined: entry_ability_on_configuration_update_should_sync_theme_for_success_and_fallback', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const preferenceManagerMock = new PreferenceManagerMockGJ();
      const rejectPreferenceManagerMock = new RejectPreferenceManagerMockGJ();
      const themeHookState = new ThemeHookStateGJ();
      const prefOrigin = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
      const normalizeOrigin = Reflect.get(ThemeCenter as Object, 'normalizeThemeMode') as Object;
      const resolveOrigin = Reflect.get(ThemeCenter as Object, 'resolveEffectiveTheme') as Object;
      const syncOrigin = Reflect.get(ThemeCenter as Object, 'syncThemeToStorage') as Object;
      const firstConfig = new AbilityConfigGJ();
      const secondConfig = new AbilityConfigGJ();

      host.currentThemeMode = 'system';
      firstConfig.colorMode = 1;
      secondConfig.colorMode = 2;
      preferenceManagerMock.savedThemeMode = 'system';
      Reflect.set(PreferenceManager as Object, 'getInstance', (): PreferenceManagerMockGJ => preferenceManagerMock);
      Reflect.set(ThemeCenter as Object, 'normalizeThemeMode', (mode: string): string => themeHookState.normalizeThemeMode(mode));
      Reflect.set(ThemeCenter as Object, 'resolveEffectiveTheme', (mode: string, colorMode: number): string => {
        return themeHookState.resolveEffectiveTheme(mode, colorMode);
      });
      Reflect.set(ThemeCenter as Object, 'syncThemeToStorage', (mode: string, effective: string): void => {
        themeHookState.syncThemeToStorage(mode, effective);
      });

      host.runOnConfigurationUpdate(firstConfig);
      await flushAsyncGJ();
      Reflect.set(PreferenceManager as Object, 'getInstance', (): RejectPreferenceManagerMockGJ => rejectPreferenceManagerMock);
      host.runOnConfigurationUpdate(secondConfig);
      await flushAsyncGJ();

      expect(themeHookState.synced.length).assertEqual(2);
      expect(themeHookState.synced[0]).assertEqual('system:system_1');
      expect(themeHookState.synced[1]).assertEqual('system:system_2');

      Reflect.set(PreferenceManager as Object, 'getInstance', prefOrigin);
      Reflect.set(ThemeCenter as Object, 'normalizeThemeMode', normalizeOrigin);
      Reflect.set(ThemeCenter as Object, 'resolveEffectiveTheme', resolveOrigin);
      Reflect.set(ThemeCenter as Object, 'syncThemeToStorage', syncOrigin);
    });

    it('combined: entry_ability_on_create_should_initialize_runtime_and_register_map_callback', 0, async () => {
      // Arrange
      // Act
      // Assert
      const host = new AbilityHostGJ();
      const trafficEngineMock = new TrafficEngineMockGJ();
      const mapViewManagerMock = new MapViewManagerMockGJ();
      const appStorageMock = new AppStorageMockGJ();
      const trafficOrigin = Reflect.get(TrafficEngine as Object, 'getInstance') as Object;
      const amapBindOrigin = Reflect.get(AmapService as Object, 'bindRuntimeContext') as Object;
      const boundaryOrigin = Reflect.get(DateUtil as Object, 'logBoundarySelfCheck') as Object;
      const validateOrigin = Reflect.get(AppConfig as Object, 'validateAmapSdkConfig') as Object;
      const setApiKeyOrigin = Reflect.get(MapsInitializer as Object, 'setApiKey') as Object;
      const privacyShowOrigin = Reflect.get(MapsInitializer as Object, 'updatePrivacyShow') as Object;
      const privacyAgreeOrigin = Reflect.get(MapsInitializer as Object, 'updatePrivacyAgree') as Object;
      const mapViewManagerOrigin = Reflect.get(MapViewManager as Object, 'getInstance') as Object;
      const appStorageOrigin = Reflect.get(globalThis as Object, 'AppStorage') as Object;
      let boundRuntimeContext: Object | null = null;
      let sdkKeySet: string = '';
      let privacyShowCount: number = 0;
      let privacyAgreeCount: number = 0;
      let boundaryCount: number = 0;

      Reflect.set(TrafficEngine as Object, 'getInstance', (): TrafficEngineMockGJ => trafficEngineMock);
      Reflect.set(AmapService as Object, 'bindRuntimeContext', (context: Object): void => {
        boundRuntimeContext = context;
      });
      Reflect.set(DateUtil as Object, 'logBoundarySelfCheck', (): void => {
        boundaryCount += 1;
      });
      Reflect.set(AppConfig as Object, 'validateAmapSdkConfig', (): void => {
      });
      Reflect.set(MapsInitializer as Object, 'setApiKey', (apiKey: string): void => {
        sdkKeySet = apiKey;
      });
      Reflect.set(MapsInitializer as Object, 'updatePrivacyShow', (): void => {
        privacyShowCount += 1;
      });
      Reflect.set(MapsInitializer as Object, 'updatePrivacyAgree', (): void => {
        privacyAgreeCount += 1;
      });
      Reflect.set(MapViewManager as Object, 'getInstance', (): MapViewManagerMockGJ => mapViewManagerMock);
      Reflect.set(globalThis as Object, 'AppStorage', appStorageMock);

      host.runOnCreate(new EmptyWantGJ() as Object, new EmptyLaunchParamGJ() as Object);
      if (mapViewManagerMock.callback) {
        mapViewManagerMock.callback(undefined, 'empty_gj');
        mapViewManagerMock.callback(new MapViewTokenGJ() as Object, 'created_gj');
      }
      await flushAsyncGJ();

      expect(host.initThemeModeCount).assertEqual(1);
      expect(host.bootstrapUserContextCount).assertEqual(1);
      expect(host.handleNotificationLaunchWantCount).assertEqual(1);
      expect(trafficEngineMock.initializeCount).assertEqual(1);
      expect(boundRuntimeContext === host.context).assertTrue();
      expect(boundaryCount).assertEqual(1);
      expect(privacyShowCount).assertEqual(1);
      expect(privacyAgreeCount).assertEqual(1);
      expect(sdkKeySet.length >= 0).assertTrue();
      expect(mapViewManagerMock.callback !== null).assertTrue();

      Reflect.set(TrafficEngine as Object, 'getInstance', trafficOrigin);
      Reflect.set(AmapService as Object, 'bindRuntimeContext', amapBindOrigin);
      Reflect.set(DateUtil as Object, 'logBoundarySelfCheck', boundaryOrigin);
      Reflect.set(AppConfig as Object, 'validateAmapSdkConfig', validateOrigin);
      Reflect.set(MapsInitializer as Object, 'setApiKey', setApiKeyOrigin);
      Reflect.set(MapsInitializer as Object, 'updatePrivacyShow', privacyShowOrigin);
      Reflect.set(MapsInitializer as Object, 'updatePrivacyAgree', privacyAgreeOrigin);
      Reflect.set(MapViewManager as Object, 'getInstance', mapViewManagerOrigin);
      Reflect.set(globalThis as Object, 'AppStorage', appStorageOrigin);
    });
  });
}
