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
  mapRuntimeReady: boolean;
  mapRuntimeChecked: boolean;
  mapRuntimeError: string;
  searchToken: number;
  effectiveTheme: string;
  scheduleSearch(value: string): void;
  searchNow(): void;
  runSearch(keyword: string): Promise<void>;
  formatDistance(distance?: number): string;
  focusPoi(item: Object): void;
  confirmSelection(): void;
  getThemePalette(): MapPickerPagePaletteTest;
  initialRender(): void;
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
  });
}
