import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';
import {
  buildMapPickerCoordinateFallbackAddress,
  createMapPickerPageForTest,
  formatMapPickerDistance,
  isMapPickerAddressResolving,
  isMapPickerCoordinateValid,
  resolveMapPickerCenterHint,
  resolveMapPickerSelectionAddress,
  resolveMapPickerStorageKey
} from '../main/ets/pages/MapPickerPage';

interface MapPickerPagePaletteTest {
  textPrimary: Object;
  cardBg: Object;
  primary: Object;
}

interface MapPickerPoiSearchItemTest {
  name: string;
  address: string;
  lat: number;
  lng: number;
  distance?: number;
}

interface MapPickerPagePrivateTest {
  currentLat: number;
  currentLng: number;
  currentAddress: string;
  isDragging: boolean;
  searchKeyword: string;
  searching: boolean;
  searchResults: Object[];
  searchPanelVisible: boolean;
  centerHint: string;
  storageScopePlanId: number;
  hasPresetCoordinate: boolean;
  mapRuntimeReady: boolean;
  mapRuntimeChecked: boolean;
  mapRuntimeError: string;
  searchToken: number;
  searchDebounceTimer: number;
  addressDebounceTimer: number;
  effectiveTheme: string;
  onMapReady(): void;
  scheduleFetchAddress(lat: number, lng: number): void;
  fetchAddress(lat: number, lng: number): Promise<void>;
  scheduleSearch(value: string): void;
  searchNow(): void;
  runSearch(keyword: string): Promise<void>;
  formatDistance(distance?: number): string;
  focusPoi(item: Object): void;
  confirmSelection(): void;
  getThemePalette(): MapPickerPagePaletteTest;
  initialRender(): void;
}

interface MapPickerCameraTargetTest {
  latitude: number;
  longitude: number;
}

interface MapPickerCameraPositionTest {
  target?: MapPickerCameraTargetTest;
}

interface MapPickerCameraListenerTest {
  onCameraChange?: (position: MapPickerCameraPositionTest) => void;
  onCameraChangeFinish?: (position: MapPickerCameraPositionTest) => void;
}

class MapPickerPoiSearchItemRenderTest {
  name: string = 'poi_name';
  address: string = 'poi_address';
  lat: number = 30.12345;
  lng: number = 120.54321;
  distance: number = 1500;
}

class MapPickerRouteOptionsTest {
  url?: string;
}

class MapPickerHostContextMockTest {
}

class MapPickerRouterMockTest {
  public backCount: number = 0;

  back(): void {
    this.backCount += 1;
  }

  getParams(): MapPickerRouteOptionsTest {
    return new MapPickerRouteOptionsTest();
  }
}

class MapPickerUiContextMockTest {
  public router: MapPickerRouterMockTest = new MapPickerRouterMockTest();

  getRouter(): MapPickerRouterMockTest {
    return this.router;
  }

  getHostContext(): Object {
    return new MapPickerHostContextMockTest();
  }
}

class MapPickerMapMockTest {
  public myLocationEnabled: boolean = false;
  public myLocationStyle: Object | null = null;
  public moveCameraCount: number = 0;
  public listener: MapPickerCameraListenerTest | null = null;

  setMyLocationEnabled(enabled: boolean): void {
    this.myLocationEnabled = enabled;
  }

  setMyLocationStyle(style: Object): void {
    this.myLocationStyle = style;
  }

  moveCamera(_update: Object): void {
    this.moveCameraCount += 1;
  }

  setOnCameraChangeListener(listener: Object): void {
    this.listener = listener as MapPickerCameraListenerTest;
  }
}

export default function mapPickerPageHelperTest() {
  describe('unit_test_case_generator_autofill_MapPickerPageHelper', () => {
    it('normal: map_picker_coordinate_valid_should_accept_common_city_coordinate', 0, () => {
      // Arrange
      const lat = 39.9;
      const lng = 116.4;
      // Act
      const valid = isMapPickerCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertTrue();
    });

    it('boundary: map_picker_distance_should_switch_to_km_at_1000m', 0, () => {
      // Arrange
      const distance = 1000;
      // Act
      const text = formatMapPickerDistance(distance);
      // Assert
      expect(text).assertEqual('1.0km');
    });

    it('invalid: map_picker_coordinate_valid_should_reject_out_of_range_latitude', 0, () => {
      // Arrange
      const lat = 91;
      const lng = 100;
      // Act
      const valid = isMapPickerCoordinateValid(lat, lng);
      // Assert
      expect(valid).assertFalse();
    });

    it('conflict: map_picker_address_resolving_should_treat_pending_text_as_resolving', 0, () => {
      // Arrange
      const address = '正在解析附近地名...';
      // Act
      const resolving = isMapPickerAddressResolving(address);
      // Assert
      expect(resolving).assertTrue();
    });

    it('regression: td-20260412-map_picker_fallback_should_keep_fixed_5_decimal_format', 0, () => {
      // Arrange
      const lat = 31.2304;
      const lng = 121.4737;
      // Act
      const text = buildMapPickerCoordinateFallbackAddress(lat, lng);
      // Assert
      expect(text).assertEqual('已选位置(31.23040, 121.47370)');
    });

    it('combined: map_picker_resolving_and_distance_should_handle_empty_and_undefined_input', 0, () => {
      // Arrange
      const address = '';
      const distance = undefined;
      // Act
      const resolving = isMapPickerAddressResolving(address);
      const distanceText = formatMapPickerDistance(distance);
      // Assert
      expect(resolving).assertTrue();
      expect(distanceText).assertEqual('');
    });

    it('boundary: map_picker_coordinate_valid_should_accept_signed_world_edges_except_origin', 0, () => {
      // Arrange
      const northEastLat = 90;
      const northEastLng = 180;
      const southWestLat = -90;
      const southWestLng = -180;

      // Act
      const northEastValid = isMapPickerCoordinateValid(northEastLat, northEastLng);
      const southWestValid = isMapPickerCoordinateValid(southWestLat, southWestLng);
      const originValid = isMapPickerCoordinateValid(0, 0);

      // Assert
      expect(northEastValid).assertTrue();
      expect(southWestValid).assertTrue();
      expect(originValid).assertFalse();
    });

    it('invalid: map_picker_coordinate_valid_should_reject_nan_and_out_of_range_longitude', 0, () => {
      // Arrange
      const nanLat = Number.NaN;
      const outOfRangeLng = 181;

      // Act
      const nanValid = isMapPickerCoordinateValid(nanLat, 120);
      const lngValid = isMapPickerCoordinateValid(30, outOfRangeLng);

      // Assert
      expect(nanValid).assertFalse();
      expect(lngValid).assertFalse();
    });

    it('boundary: map_picker_distance_should_floor_meter_decimal_and_keep_negative_linear', 0, () => {
      // Arrange
      const decimalMeters = 999.9;
      const negativeMeters = -2.4;

      // Act
      const decimalText = formatMapPickerDistance(decimalMeters);
      const negativeText = formatMapPickerDistance(negativeMeters);

      // Assert
      expect(decimalText).assertEqual('999m');
      expect(negativeText).assertEqual('-3m');
    });
  });

  describe('unit_test_case_generator_autofill_MapPickerPageHelperBranches', () => {
    it('normal: map_picker_center_hint_should_include_query_name_for_geocode_source', 0, () => {
      // Arrange
      const centerSource = 'geocode';
      const queryName = 'West Lake';
      // Act
      const hint = resolveMapPickerCenterHint(centerSource, queryName);
      // Assert
      expect(hint.indexOf(queryName) >= 0).assertTrue();
    });

    it('boundary: map_picker_center_hint_should_fallback_when_geocode_query_name_blank', 0, () => {
      // Arrange
      const centerSource = 'geocode';
      const queryName = '  ';
      // Act
      const hint = resolveMapPickerCenterHint(centerSource, queryName);
      // Assert
      expect(hint).assertEqual('已按地点名定位到附近，可拖动微调');
    });

    it('boundary: map_picker_storage_key_should_floor_positive_plan_id', 0, () => {
      // Arrange
      const planId = 7.9;
      // Act
      const key = resolveMapPickerStorageKey(planId);
      // Assert
      expect(key).assertEqual('pickedLocationStr_7');
    });

    it('invalid: map_picker_selection_address_should_fallback_for_unknown_coordinate_tag', 0, () => {
      // Arrange
      const currentAddress = '未知坐标点';
      const lat = 30.12345;
      const lng = 120.54321;
      // Act
      const resolved = resolveMapPickerSelectionAddress(currentAddress, lat, lng);
      // Assert
      expect(resolved).assertEqual(buildMapPickerCoordinateFallbackAddress(lat, lng));
    });

    it('conflict: map_picker_center_hint_should_prefer_existing_source_over_default', 0, () => {
      // Arrange
      const existingHint = resolveMapPickerCenterHint('existing', '');
      const defaultHint = resolveMapPickerCenterHint('current', '');
      // Act
      const areSame = existingHint === defaultHint;
      // Assert
      expect(areSame).assertFalse();
    });

    it('regression: td-20260418-map_picker_storage_key_should_use_base_key_for_non_positive_plan_id', 0, () => {
      // Arrange
      const planId = 0;
      // Act
      const key = resolveMapPickerStorageKey(planId);
      // Assert
      expect(key).assertEqual('pickedLocationStr');
    });

    it('combined: map_picker_hint_and_selection_should_handle_blank_inputs_together', 0, () => {
      // Arrange
      const centerSource = '';
      const queryName = '';
      const currentAddress = ' ';
      const lat = 31.2;
      const lng = 121.5;
      // Act
      const hint = resolveMapPickerCenterHint(centerSource, queryName);
      const resolved = resolveMapPickerSelectionAddress(currentAddress, lat, lng);
      // Assert
      expect(hint.length > 0).assertTrue();
      expect(resolved).assertEqual(buildMapPickerCoordinateFallbackAddress(lat, lng));
    });

    it('boundary: map_picker_selection_address_should_trim_saved_address_and_keep_non_unknown_text', 0, () => {
      // Arrange
      const currentAddress = '  saved place  ';

      // Act
      const resolved = resolveMapPickerSelectionAddress(currentAddress, 31.2, 121.5);

      // Assert
      expect(resolved).assertEqual('saved place');
    });

    it('combined: map_picker_storage_key_should_handle_negative_decimal_and_large_fraction', 0, () => {
      // Arrange
      const negativePlanId = -2.5;
      const largeFractionPlanId = 1024.99;

      // Act
      const negativeKey = resolveMapPickerStorageKey(negativePlanId);
      const largeKey = resolveMapPickerStorageKey(largeFractionPlanId);

      // Assert
      expect(negativeKey).assertEqual('pickedLocationStr');
      expect(largeKey).assertEqual('pickedLocationStr_1024');
    });

    it('normal: map_picker_instance_should_render_fallback_runtime_with_results', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const poi = new MapPickerPoiSearchItemRenderTest();
      page.mapRuntimeReady = false;
      page.mapRuntimeChecked = true;
      page.mapRuntimeError = 'runtime unavailable';
      page.searchKeyword = 'station';
      page.searching = false;
      page.searchResults = [poi];
      page.currentAddress = 'selected';
      page.centerHint = 'hint';
      page.effectiveTheme = 'dark';
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const palette = page.getThemePalette();
      const distanceText = page.formatDistance(poi.distance);

      // Assert
      expect(threw).assertFalse();
      expect(distanceText).assertEqual('1.5km');
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
    });

    it('boundary: map_picker_instance_should_render_initializing_empty_results_branch', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      page.mapRuntimeReady = false;
      page.mapRuntimeChecked = false;
      page.mapRuntimeError = '';
      page.searchKeyword = '';
      page.searching = true;
      page.searchResults = [];
      page.currentAddress = '';
      page.effectiveTheme = 'light';
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      page.scheduleSearch('');
      page.searchNow();

      // Assert
      expect(threw).assertFalse();
      expect(page.searchPanelVisible).assertFalse();
      expect(page.searchResults.length).assertEqual(0);
    });

    it('combined: map_picker_instance_should_focus_poi_without_map_and_sync_selection_state', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const poi = new MapPickerPoiSearchItemRenderTest();
      poi.address = '';
      poi.name = 'fallback_name';
      page.searchPanelVisible = true;
      page.searchResults = [poi];

      // Act
      page.focusPoi(poi);

      // Assert
      expect(page.currentLat).assertEqual(poi.lat);
      expect(page.currentLng).assertEqual(poi.lng);
      expect(page.currentAddress).assertEqual('fallback_name');
      expect(page.searchPanelVisible).assertFalse();
      expect(page.searchResults.length).assertEqual(0);
    });

    it('regression: map_picker_instance_should_render_ready_branch_with_search_panel_and_results', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const poi = new MapPickerPoiSearchItemRenderTest();
      page.mapRuntimeReady = true;
      page.mapRuntimeChecked = true;
      page.currentAddress = 'ready address';
      page.searchKeyword = 'tower';
      page.searching = false;
      page.searchPanelVisible = true;
      page.searchResults = [poi];
      page.centerHint = 'hint text';
      page.effectiveTheme = 'dark';
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.mapRuntimeReady).assertTrue();
      expect(page.searchResults.length).assertEqual(1);
    });

    it('normal: map_picker_instance_run_search_should_apply_latest_results', 0, async () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const poi = new MapPickerPoiSearchItemRenderTest();
      const originalSearchPoi = Reflect.get(AmapService as Object, 'searchPoi') as (
        context: Object,
        keyword: string,
        lat: number,
        lng: number,
        limit: number
      ) => Promise<Object[]>;
      Reflect.set(page as Object, 'uiContext', new MapPickerHostContextMockTest());
      Reflect.set(AmapService as Object, 'searchPoi', async (
        _context: Object,
        keyword: string,
        _lat: number,
        _lng: number,
        limit: number
      ): Promise<Object[]> => {
        poi.name = keyword;
        poi.distance = limit * 100;
        return [poi];
      });

      // Act
      await page.runSearch('museum');

      // Assert
      expect(page.searching).assertFalse();
      expect(page.searchPanelVisible).assertTrue();
      expect(page.searchResults.length).assertEqual(1);
      Reflect.set(AmapService as Object, 'searchPoi', originalSearchPoi);
    });

    it('invalid: map_picker_instance_run_search_should_clear_results_when_service_throws', 0, async () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const originalSearchPoi = Reflect.get(AmapService as Object, 'searchPoi') as (
        context: Object,
        keyword: string,
        lat: number,
        lng: number,
        limit: number
      ) => Promise<Object[]>;
      page.searchResults = [new MapPickerPoiSearchItemRenderTest()];
      Reflect.set(page as Object, 'uiContext', new MapPickerHostContextMockTest());
      Reflect.set(AmapService as Object, 'searchPoi', async (): Promise<Object[]> => {
        throw new Error('search failed');
      });

      // Act
      await page.runSearch('bad');

      // Assert
      expect(page.searching).assertFalse();
      expect(page.searchPanelVisible).assertTrue();
      expect(page.searchResults.length).assertEqual(0);
      Reflect.set(AmapService as Object, 'searchPoi', originalSearchPoi);
    });

    it('boundary: map_picker_instance_confirm_selection_should_block_zero_coordinate', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const uiContext = new MapPickerUiContextMockTest();
      page.currentLat = 0;
      page.currentLng = 116.4;
      page.currentAddress = 'valid address';
      Reflect.set(page as Object, 'getUIContext', (): MapPickerUiContextMockTest => uiContext);

      // Act
      page.confirmSelection();

      // Assert
      expect(uiContext.router.backCount).assertEqual(0);
    });

    it('regression: map_picker_instance_confirm_selection_should_use_scoped_storage_key_and_back', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const uiContext = new MapPickerUiContextMockTest();
      const key = 'pickedLocationStr_88';
      page.currentLat = 30.12345;
      page.currentLng = 120.54321;
      page.currentAddress = 'saved address';
      page.storageScopePlanId = 88;
      AppStorage.setOrCreate(key, '');
      Reflect.set(page as Object, 'getUIContext', (): MapPickerUiContextMockTest => uiContext);

      // Act
      page.confirmSelection();
      const raw = AppStorage.get<string>(key) ?? '';

      // Assert
      expect(uiContext.router.backCount).assertEqual(1);
      expect(raw.indexOf('saved address') >= 0).assertTrue();
    });

    it('boundary: map_picker_on_map_ready_should_return_when_map_missing', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      page.currentAddress = 'before_ready';

      // Act
      page.onMapReady();

      // Assert
      expect(page.currentAddress).assertEqual('before_ready');
    });

    it('combined: map_picker_on_map_ready_should_handle_camera_change_callbacks', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      const map = new MapPickerMapMockTest();
      let scheduledLat = 0;
      let scheduledLng = 0;
      Reflect.set(page as Object, 'map', map);
      Reflect.set(page as Object, 'scheduleFetchAddress', (lat: number, lng: number): void => {
        scheduledLat = lat;
        scheduledLng = lng;
      });
      page.hasPresetCoordinate = false;

      // Act
      page.onMapReady();
      const listener = map.listener as MapPickerCameraListenerTest;
      listener.onCameraChange?.({ target: { latitude: 31.23, longitude: 121.47 } });
      listener.onCameraChangeFinish?.({ target: { latitude: 31.23, longitude: 121.47 } });

      // Assert
      expect(map.myLocationEnabled).assertTrue();
      expect(map.myLocationStyle !== null).assertTrue();
      expect(listener !== null).assertTrue();
      expect(page.isDragging).assertFalse();
      expect(page.currentLat).assertEqual(31.23);
      expect(page.currentLng).assertEqual(121.47);
      expect(scheduledLat).assertEqual(31.23);
      expect(scheduledLng).assertEqual(121.47);
    });

    it('regression: map_picker_schedule_fetch_address_should_replace_pending_timer_without_fetching_immediately', 0, () => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      let fetchCount = 0;
      Reflect.set(page as Object, 'fetchAddress', async (_lat: number, _lng: number): Promise<void> => {
        fetchCount += 1;
      });

      // Act
      page.scheduleFetchAddress(30.1, 120.2);
      const firstTimer = page.addressDebounceTimer;
      page.scheduleFetchAddress(30.2, 120.3);
      const secondTimer = page.addressDebounceTimer;
      clearTimeout(secondTimer);
      page.addressDebounceTimer = -1;

      // Assert
      expect(firstTimer > 0).assertTrue();
      expect(secondTimer > 0).assertTrue();
      expect(fetchCount).assertEqual(0);
    });

    it('regression: td-20260426-map_picker_schedule_search_should_fire_debounce_callback', 0, async (done: () => void) => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      let receivedKeyword = '';
      Reflect.set(page as Object, 'runSearch', async (keyword: string): Promise<void> => {
        receivedKeyword = keyword;
      });

      // Act
      page.scheduleSearch('  museum  ');
      setTimeout(() => {
        // Assert
        expect(receivedKeyword).assertEqual('museum');
        expect(page.searchDebounceTimer > 0).assertTrue();
        done();
      }, 360);
    });

    it('regression: td-20260426-map_picker_schedule_fetch_address_should_fire_debounce_callback', 0, async (done: () => void) => {
      // Arrange
      const page = createMapPickerPageForTest() as MapPickerPagePrivateTest;
      let callCount = 0;
      let recordedLat = 0;
      let recordedLng = 0;
      Reflect.set(page as Object, 'fetchAddress', async (lat: number, lng: number): Promise<void> => {
        callCount += 1;
        recordedLat = lat;
        recordedLng = lng;
      });

      // Act
      page.scheduleFetchAddress(30.1, 120.2);
      setTimeout(() => {
        // Assert
        expect(callCount).assertEqual(1);
        expect(recordedLat).assertEqual(30.1);
        expect(recordedLng).assertEqual(120.2);
        expect(page.addressDebounceTimer).assertEqual(-1);
        done();
      }, 380);
    });
  });
}
