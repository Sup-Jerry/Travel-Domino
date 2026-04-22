import { describe, it, expect } from '@ohos/hypium';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';
import { createMapPickerPageForTest } from '../main/ets/pages/MapPickerPage';
import { MapViewManager, MapsInitializer } from '@amap/amap_lbs_map3d';

interface MapPickerPagePrivateDL {
  currentLat: number;
  currentLng: number;
  currentAddress: string;
  isDragging: boolean;
  searchKeyword: string;
  searching: boolean;
  searchResults: Object[];
  searchPanelVisible: boolean;
  searchToken: number;
  hasPresetCoordinate: boolean;
  centerHint: string;
  storageScopePlanId: number;
  mapRuntimeReady: boolean;
  mapRuntimeChecked: boolean;
  mapRuntimeError: string;
  addressRequestSeq: number;
  latestAppliedAddressSeq: number;
  searchDebounceTimer: number;
  addressDebounceTimer: number;
  aboutToAppear(): void;
  prepareMapRuntime(): Promise<void>;
  isMapNativeRuntimeReady(): Promise<boolean>;
  aboutToDisappear(): void;
  buildCoordinateFallbackAddress(lat: number, lng: number): string;
  isValidCoordinate(lat: number, lng: number): boolean;
  isAddressResolving(address: string): boolean;
  fetchAddress(lat: number, lng: number): Promise<void>;
}

interface RouteParamsDL {
  lat: number;
  lng: number;
  planId: number;
  centerSource: string;
  queryName: string;
}

class RouterMockDL {
  public readonly params: RouteParamsDL;

  constructor(params: RouteParamsDL) {
    this.params = params;
  }

  getParams(): RouteParamsDL {
    return this.params;
  }

  back(): void {
  }
}

class UiContextMockDL {
  public readonly router: RouterMockDL;
  public readonly hostContext: Object = new Object();

  constructor(params: RouteParamsDL) {
    this.router = new RouterMockDL(params);
  }

  getRouter(): RouterMockDL {
    return this.router;
  }

  getHostContext(): Object {
    return this.hostContext;
  }
}

class MapViewMockDL {
  public getMapAsyncCount: number = 0;
  public readonly map: Object = new Object();

  getMapAsync(callback: (map: Object) => void): void {
    this.getMapAsyncCount += 1;
    callback(this.map);
  }
}

class MapViewManagerMockDL {
  public registeredCallback: ((mapView?: Object, mapViewName?: string) => void) | undefined = undefined;
  public registerCount: number = 0;
  public unregisterCount: number = 0;

  registerMapViewCreatedCallback(callback: (mapView?: Object, mapViewName?: string) => void): void {
    this.registerCount += 1;
    this.registeredCallback = callback;
  }

  unregisterMapViewCreatedCallback(callback: (mapView?: Object, mapViewName?: string) => void): void {
    if (this.registeredCallback === callback) {
      this.registeredCallback = undefined;
    }
    this.unregisterCount += 1;
  }
}

class ResolveBoxDL {
  resolve?: (value: string) => void;
}

class StaticPatchDL {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

function createPageDL(): MapPickerPagePrivateDL {
  const page = createMapPickerPageForTest() as MapPickerPagePrivateDL;
  Reflect.set(page as Object, 'safeShowToast', (_message: string): void => {});
  return page;
}

function buildParamsDL(lat: number, lng: number, planId: number, source: string, queryName: string): RouteParamsDL {
  return {
    lat: lat,
    lng: lng,
    planId: planId,
    centerSource: source,
    queryName: queryName
  };
}

function patchMapVersionDL(version: string): StaticPatchDL {
  return new StaticPatchDL(MapsInitializer as Object, 'getVersion', (): string => version);
}

function patchMapManagerDL(manager: MapViewManagerMockDL): StaticPatchDL {
  return new StaticPatchDL(MapViewManager as Object, 'getInstance', (): MapViewManagerMockDL => manager);
}

async function flushMicrotasksDL(): Promise<void> {
  for (let i = 0; i < 20; i += 1) {
    await Promise.resolve();
  }
}

export default function phase2BatchDLTest() {
  describe('phase2BatchDLTest', () => {
    it('normal: map_picker_about_to_appear_should_apply_valid_route_params_without_real_runtime', 0, async () => {
      // Arrange
      const page = createPageDL();
      const params = buildParamsDL(31.2304, 121.4737, 88, 'geocode', 'Shanghai');
      const uiContext = new UiContextMockDL(params);
      let prepareCalled = false;
      Reflect.set(page as Object, 'getUIContext', (): UiContextMockDL => uiContext);
      Reflect.set(page as Object, 'prepareMapRuntime', async (): Promise<void> => {
        prepareCalled = true;
      });

      // Act
      page.aboutToAppear();
      await flushMicrotasksDL();

      // Assert
      expect(prepareCalled).assertTrue();
      expect(page.currentLat).assertEqual(31.2304);
      expect(page.currentLng).assertEqual(121.4737);
      expect(page.storageScopePlanId).assertEqual(88);
      expect(page.hasPresetCoordinate).assertTrue();
      expect(page.centerHint.indexOf('Shanghai') >= 0).assertTrue();
    });

    it('boundary: map_picker_about_to_appear_should_keep_default_coordinate_for_invalid_route_coordinate', 0, async () => {
      // Arrange
      const page = createPageDL();
      const params = buildParamsDL(0, 0, 0, 'existing', '');
      Reflect.set(page as Object, 'getUIContext', (): UiContextMockDL => new UiContextMockDL(params));
      Reflect.set(page as Object, 'prepareMapRuntime', async (): Promise<void> => {});

      // Act
      page.aboutToAppear();
      await flushMicrotasksDL();

      // Assert
      expect(page.hasPresetCoordinate).assertFalse();
      expect(page.currentLat).assertEqual(39.916344);
      expect(page.currentLng).assertEqual(116.397155);
      expect(page.centerHint.length > 0).assertTrue();
    });

    it('invalid: map_picker_runtime_probe_should_fail_when_sdk_version_empty', 0, async () => {
      // Arrange
      const page = createPageDL();
      const versionPatch = patchMapVersionDL('   ');

      // Act
      const ready = await page.isMapNativeRuntimeReady();
      versionPatch.restore();

      // Assert
      expect(ready).assertFalse();
    });

    it('conflict: map_picker_prepare_runtime_should_register_only_map_picker_callback_when_ready', 0, async () => {
      // Arrange
      const page = createPageDL();
      const manager = new MapViewManagerMockDL();
      const versionPatch = patchMapVersionDL('1.0.0');
      const managerPatch = patchMapManagerDL(manager);
      let onReadyCount = 0;
      Reflect.set(page as Object, 'onMapReady', (): void => {
        onReadyCount += 1;
      });

      // Act
      await page.prepareMapRuntime();
      const callback = manager.registeredCallback;
      const wrongMapView = new MapViewMockDL();
      const mapView = new MapViewMockDL();
      if (callback) {
        callback(undefined, 'MapPicker');
        callback(wrongMapView as Object, 'OtherMap');
        callback(mapView as Object, 'MapPicker');
      }
      managerPatch.restore();
      versionPatch.restore();

      // Assert
      expect(page.mapRuntimeReady).assertTrue();
      expect(page.mapRuntimeChecked).assertTrue();
      expect(manager.registerCount).assertEqual(1);
      expect(wrongMapView.getMapAsyncCount).assertEqual(0);
      expect(mapView.getMapAsyncCount).assertEqual(1);
      expect(onReadyCount).assertEqual(1);
    });

    it('regression: map_picker_prepare_runtime_should_mark_error_and_skip_manager_when_not_ready', 0, async () => {
      // Arrange
      const page = createPageDL();
      const manager = new MapViewManagerMockDL();
      const versionPatch = patchMapVersionDL('');
      const managerPatch = patchMapManagerDL(manager);

      // Act
      await page.prepareMapRuntime();
      managerPatch.restore();
      versionPatch.restore();

      // Assert
      expect(page.mapRuntimeReady).assertFalse();
      expect(page.mapRuntimeChecked).assertTrue();
      expect(page.mapRuntimeError.length > 0).assertTrue();
      expect(manager.registerCount).assertEqual(0);
    });

    it('combined: map_picker_about_to_disappear_should_clear_timers_tokens_and_unregister_callback', 0, () => {
      // Arrange
      const page = createPageDL();
      const manager = new MapViewManagerMockDL();
      const managerPatch = patchMapManagerDL(manager);
      const callback = (_mapView?: Object, _mapViewName?: string): void => {};
      manager.registeredCallback = callback;
      Reflect.set(page as Object, 'mapViewCreateCallback', callback);
      Reflect.set(page as Object, 'map', new Object());
      Reflect.set(page as Object, 'mapView', new Object());
      page.searchDebounceTimer = setTimeout((): void => {}, 1000) as number;
      page.addressDebounceTimer = setTimeout((): void => {}, 1000) as number;
      const searchTokenBefore = page.searchToken;
      const addressSeqBefore = page.addressRequestSeq;

      // Act
      page.aboutToDisappear();
      managerPatch.restore();

      // Assert
      expect(page.searchDebounceTimer).assertEqual(-1);
      expect(page.addressDebounceTimer).assertEqual(-1);
      expect(page.searchToken).assertEqual(searchTokenBefore + 1);
      expect(page.addressRequestSeq).assertEqual(addressSeqBefore + 1);
      expect(manager.unregisterCount).assertEqual(1);
    });

    it('normal: map_picker_fetch_address_should_apply_service_address', 0, async () => {
      // Arrange
      const page = createPageDL();
      const patch = new StaticPatchDL(
        AmapService as Object,
        'getRegeoWithSdkFallback',
        async (_lat: number, _lng: number, _context: Object | null): Promise<string> => 'West Lake'
      );

      // Act
      await page.fetchAddress(30.25, 120.15);
      patch.restore();

      // Assert
      expect(page.currentAddress).assertEqual('West Lake');
      expect(page.latestAppliedAddressSeq).assertEqual(page.addressRequestSeq);
    });

    it('invalid: map_picker_fetch_address_should_fallback_when_service_returns_blank', 0, async () => {
      // Arrange
      const page = createPageDL();
      const patch = new StaticPatchDL(
        AmapService as Object,
        'getRegeoWithSdkFallback',
        async (_lat: number, _lng: number, _context: Object | null): Promise<string> => '   '
      );

      // Act
      await page.fetchAddress(30.25, 120.15);
      patch.restore();

      // Assert
      expect(page.currentAddress).assertEqual(page.buildCoordinateFallbackAddress(30.25, 120.15));
      expect(page.isAddressResolving(page.currentAddress)).assertFalse();
    });

    it('combined: map_picker_fetch_address_should_ignore_stale_response_and_keep_latest_address', 0, async () => {
      // Arrange
      const page = createPageDL();
      const resolverBox: ResolveBoxDL = new ResolveBoxDL();
      const patch = new StaticPatchDL(
        AmapService as Object,
        'getRegeoWithSdkFallback',
        (lat: number, _lng: number, _context: Object | null): Promise<string> => {
          if (lat === 1) {
            return new Promise<string>((resolve) => {
              resolverBox.resolve = resolve;
            });
          }
          return Promise.resolve('latest address');
        }
      );
      const firstPromise = page.fetchAddress(1, 1);

      // Act
      await page.fetchAddress(2, 2);
      if (resolverBox.resolve !== undefined) {
        resolverBox.resolve('stale address');
      }
      await firstPromise;
      patch.restore();

      // Assert
      expect(page.currentAddress).assertEqual('latest address');
      expect(page.latestAppliedAddressSeq).assertEqual(2);
    });
  });
}



