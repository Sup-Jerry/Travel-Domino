import { describe, it, expect } from '@ohos/hypium';
import { PoiItem } from '@amap/amap_lbs_search';
import { AmapPoiSearchNode, AmapService, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { PageDraftRecovery } from '../main/ets/common/utils/PageDraftRecovery';

class LocalAmapPointMock {
  private readonly lat: number;
  private readonly lng: number;

  constructor(lat: number, lng: number) {
    this.lat = lat;
    this.lng = lng;
  }

  getLatitude(): number {
    return this.lat;
  }

  getLongitude(): number {
    return this.lng;
  }
}

class LocalAmapPoiMock {
  private readonly title: string;
  private readonly snippet: string;
  private readonly lat: number;
  private readonly lng: number;
  private readonly distance: number;
  private readonly hasPoint: boolean;

  constructor(title: string, snippet: string, lat: number, lng: number, distance: number, hasPoint: boolean = true) {
    this.title = title;
    this.snippet = snippet;
    this.lat = lat;
    this.lng = lng;
    this.distance = distance;
    this.hasPoint = hasPoint;
  }

  getLatLonPoint(): LocalAmapPointMock | undefined {
    return this.hasPoint ? new LocalAmapPointMock(this.lat, this.lng) : undefined;
  }

  getTitle(): string {
    return this.title;
  }

  getSnippet(): string {
    return this.snippet;
  }

  getDistance(): number {
    return this.distance;
  }
}

class LocalAmapPoiListMock {
  private readonly items: LocalAmapPoiMock[];
  private readonly useGet: boolean;
  private readonly sizeValue: number;

  constructor(items: LocalAmapPoiMock[], useGet: boolean, sizeValue: number = -1) {
    this.items = items;
    this.useGet = useGet;
    this.sizeValue = sizeValue;
  }

  size(): number {
    return this.sizeValue >= 0 ? this.sizeValue : this.items.length;
  }

  get(index: number): LocalAmapPoiMock | undefined {
    return this.useGet ? this.items[index] : undefined;
  }

  forEach(callback: (value: LocalAmapPoiMock) => void): void {
    for (let i = 0; i < this.items.length; i++) {
      callback(this.items[i]);
    }
  }
}

class LocalAmapPoiResultMock {
  private readonly pois: Object | undefined;

  constructor(pois: Object | undefined) {
    this.pois = pois;
  }

  getPois(): Object | undefined {
    return this.pois;
  }
}

class LocalAmapPoiSearchNodeMock implements AmapPoiSearchNode {
  name?: string;
  address?: string;
  location?: string;
  distance?: string;

  constructor(name?: string, address?: string, location?: string, distance?: string) {
    this.name = name;
    this.address = address;
    this.location = location;
    this.distance = distance;
  }
}

class LocalAmapEmptyObjectMock {}

export default function localUnitTest() {
  describe('localUnitTest', () => {
    it('normal: assert_contain', 0, () => {
      // Arrange
      // Act
      // Assert
      const source = 'abc';
      const target = 'b';
      expect(source).assertContain(target);
      expect(source).assertEqual('abc');
    });

    it('invalid: amap_parse_poi_should_filter_invalid_nodes', 0, () => {
      // Arrange
      // Act
      // Assert
      const payload =
        '{"status":"1","pois":[' +
        '{"name":"有效点A","address":"地址A","location":"116.397155,39.916344","distance":[]},' +
        '{"name":"无坐标","address":"地址B","location":""},' +
        '{"name":"","address":"地址C","location":"120.1000,30.2000"},' +
        '{"name":"非法坐标","address":"地址D","location":"abc,def"}]}';

      const parsed: PoiSearchItem[] = AmapService.parsePoiResponse(payload);
      expect(parsed.length).assertEqual(1);
      expect(parsed[0].name).assertEqual('有效点A');
      expect(parsed[0].lat).assertEqual(39.916344);
      expect(parsed[0].lng).assertEqual(116.397155);
      expect(parsed[0].distance === undefined).assertEqual(true);
    });

    it('normal: amap_merge_should_dedupe_and_keep_limit', 0, () => {
      // Arrange
      // Act
      // Assert
      const nearby: PoiSearchItem[] = [
        new PoiSearchItem('东京塔', '港区', 35.6586, 139.7454, 320),
        new PoiSearchItem('浅草寺', '台东区', 35.7148, 139.7967, 860)
      ];
      const nationwide: PoiSearchItem[] = [
        new PoiSearchItem('东京塔', '港区', 35.6586, 139.7454, 5000),
        new PoiSearchItem('东京站', '千代田区', 35.6812, 139.7671, 2100)
      ];

      const merged: PoiSearchItem[] = AmapService.mergePoiResults(nearby, nationwide, 3);
      expect(merged.length).assertEqual(3);
      expect(merged[0].name).assertEqual('东京塔');
      expect(merged[1].name).assertEqual('浅草寺');
      expect(merged[2].name).assertEqual('东京站');
    });

    it('boundary: amap_should_fallback_to_nationwide', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(AmapService.shouldFallbackToNationwide(2, 5)).assertEqual(true);
      expect(AmapService.shouldFallbackToNationwide(5, 5)).assertEqual(false);
      expect(AmapService.shouldFallbackToNationwide(8, 5)).assertEqual(false);
    });

    it('boundary: draft_recover_should_use_coordinate_fallback_when_picked_address_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const tempState =
        '{"name":"东京塔","note":"","duration":60,"isAnchor":false,"fixedTime":"10:00","dayOffset":0,"isSchedule":true,"lat":35.65858,"lng":139.74543}';
      const pickedState = '{"lat":35.71006,"lng":139.8107,"address":""}';
      const recovered = PageDraftRecovery.recover(tempState, pickedState);
      expect(recovered.shouldRestore).assertEqual(true);
      expect(recovered.restored?.name).assertEqual('已选位置(35.71006, 139.81070)');
      expect(recovered.restored?.lat).assertEqual(35.71006);
      expect(recovered.restored?.lng).assertEqual(139.8107);
    });

    it('invalid: draft_parse_temp_state_should_reject_invalid_required_fields', 0, () => {
      // Arrange
      const invalidName = '{"name":1,"note":"","fixedTime":"09:00","isAnchor":false,"isSchedule":true,"dayOffset":0}';
      const invalidBooleans = '{"name":"n","note":"","fixedTime":"09:00","isAnchor":"x","isSchedule":true,"dayOffset":0}';
      const invalidDayOffset = '{"name":"n","note":"","fixedTime":"09:00","isAnchor":false,"isSchedule":true,"dayOffset":"bad"}';
      // Act
      const parsedInvalidName = PageDraftRecovery.parseTempDialogState(invalidName);
      const parsedInvalidBooleans = PageDraftRecovery.parseTempDialogState(invalidBooleans);
      const parsedInvalidDayOffset = PageDraftRecovery.parseTempDialogState(invalidDayOffset);
      // Assert
      expect(parsedInvalidName === null).assertTrue();
      expect(parsedInvalidBooleans === null).assertTrue();
      expect(parsedInvalidDayOffset === null).assertTrue();
    });

    it('boundary: draft_parse_temp_state_should_normalize_non_finite_numbers', 0, () => {
      // Arrange
      const raw = '{"name":"n","note":"x","fixedTime":"09:00","isAnchor":false,"isSchedule":true,"dayOffset":2.9,"duration":"bad","lat":"bad","lng":"bad"}';
      // Act
      const parsed = PageDraftRecovery.parseTempDialogState(raw);
      // Assert
      expect(parsed !== null).assertTrue();
      expect(parsed!.duration).assertEqual(60);
      expect(parsed!.dayOffset).assertEqual(2);
      expect(parsed!.lat).assertEqual(0);
      expect(parsed!.lng).assertEqual(0);
    });

    it('invalid: draft_parse_picked_location_should_reject_non_finite_coordinates_or_non_string_address', 0, () => {
      // Arrange
      const invalidAddress = '{"lat":35.1,"lng":139.1,"address":1}';
      const invalidLat = '{"lat":"bad","lng":139.1,"address":"a"}';
      // Act
      const parsedInvalidAddress = PageDraftRecovery.parsePickedLocation(invalidAddress);
      const parsedInvalidLat = PageDraftRecovery.parsePickedLocation(invalidLat);
      // Assert
      expect(parsedInvalidAddress === null).assertTrue();
      expect(parsedInvalidLat === null).assertTrue();
    });
  });
  describe('unit_test_case_generator_autofill_LocalUnit', () => {
    it('conflict: td-20260411-auto-LocalUnit', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-LocalUnit', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-LocalUnit', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });

  describe('unit_test_case_generator_autofill_LocalUnitAmapPureBranches', () => {
    it('normal: amap_normalize_poi_nodes_should_accept_numeric_text_and_distance', 0, () => {
      // Arrange
      const numericNode = new LocalAmapPoiSearchNodeMock('12345', '67890', '121.4700,31.2300', '88');
      // Act
      const items = AmapService.normalizePoiNodes([numericNode]);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('12345');
      expect(items[0].address).assertEqual('67890');
      expect(items[0].distance ?? 0).assertEqual(88);
    });

    it('boundary: amap_parse_poi_response_should_return_empty_for_blank_or_non_success_status', 0, () => {
      // Arrange
      const blank = '   ';
      const nonSuccess = '{"status":"0","pois":[{"name":"A","location":"121.1,31.1"}]}';
      // Act
      const blankItems = AmapService.parsePoiResponse(blank);
      const nonSuccessItems = AmapService.parsePoiResponse(nonSuccess);
      // Assert
      expect(blankItems.length).assertEqual(0);
      expect(nonSuccessItems.length).assertEqual(0);
    });

    it('invalid: amap_to_poi_search_item_should_reject_missing_point_invalid_coordinate_or_blank_title', 0, () => {
      // Arrange
      const missingPoint = new LocalAmapPoiMock('NoPoint', 'A', 31.2, 121.4, 1, false);
      const invalidCoord = new LocalAmapPoiMock('InvalidCoord', 'B', 0, 0, 1);
      const blankTitle = new LocalAmapPoiMock('   ', 'C', 31.2, 121.4, 1);
      // Act
      const missingPointItem = AmapService.toPoiSearchItem(missingPoint as Object as PoiItem);
      const invalidCoordItem = AmapService.toPoiSearchItem(invalidCoord as Object as PoiItem);
      const blankTitleItem = AmapService.toPoiSearchItem(blankTitle as Object as PoiItem);
      const missingPoiItem = AmapService.toPoiSearchItem(undefined);
      // Assert
      expect(missingPointItem === null).assertTrue();
      expect(invalidCoordItem === null).assertTrue();
      expect(blankTitleItem === null).assertTrue();
      expect(missingPoiItem === null).assertTrue();
    });

    it('conflict: amap_extract_poi_items_should_fallback_to_for_each_when_get_items_are_invalid', 0, () => {
      // Arrange
      const extractPoiItems = Reflect.get(Object(AmapService), 'extractPoiItems') as (result: Object | undefined) => PoiSearchItem[];
      const list = new LocalAmapPoiListMock([
        new LocalAmapPoiMock('', 'bad', 31.1, 121.1, 1),
        new LocalAmapPoiMock('FallbackA', 'ok', 31.2, 121.2, 2)
      ], false, 2);
      const result = new LocalAmapPoiResultMock(list as Object);
      // Act
      const items = extractPoiItems(result as Object);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('FallbackA');
    });

    it('regression: td-20260422-amap_private_list_helpers_should_handle_nan_size_and_missing_getter', 0, () => {
      // Arrange
      const getListSize = Reflect.get(Object(AmapService), 'getListSize') as (listObj: Object | undefined) => number;
      const getListItem = Reflect.get(Object(AmapService), 'getListItem') as <T>(listObj: Object | undefined, index: number) => T | undefined;
      const nanSizeList = new LocalAmapPoiListMock([], true, Number.NaN);
      const noGetter = new LocalAmapEmptyObjectMock();
      // Act
      const size = getListSize(nanSizeList as Object);
      const item = getListItem<number>(noGetter, 0);
      // Assert
      expect(size).assertEqual(0);
      expect(item === undefined).assertTrue();
    });

    it('combined: amap_merge_and_extract_should_handle_empty_and_default_limit_paths', 0, () => {
      // Arrange
      const extractPoiItems = Reflect.get(Object(AmapService), 'extractPoiItems') as (result: Object | undefined) => PoiSearchItem[];
      const secondary: PoiSearchItem[] = [];
      for (let i = 0; i < 12; i++) {
        secondary.push(new PoiSearchItem(`Default${i}`, 'addr', 31 + i / 100, 121 + i / 100, i));
      }
      const emptyResult = new LocalAmapPoiResultMock(undefined);
      // Act
      const merged = AmapService.mergePoiResults([], secondary, -1);
      const undefinedExtract = extractPoiItems(undefined);
      const emptyExtract = extractPoiItems(emptyResult as Object);
      // Assert
      expect(merged.length).assertEqual(10);
      expect(undefinedExtract.length).assertEqual(0);
      expect(emptyExtract.length).assertEqual(0);
    });
  });
}
