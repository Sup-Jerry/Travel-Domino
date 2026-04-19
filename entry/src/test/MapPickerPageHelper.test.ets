import { describe, it, expect } from '@ohos/hypium';
import {
  buildMapPickerCoordinateFallbackAddress,
  formatMapPickerDistance,
  isMapPickerAddressResolving,
  isMapPickerCoordinateValid,
  resolveMapPickerCenterHint,
  resolveMapPickerSelectionAddress,
  resolveMapPickerStorageKey
} from '../main/ets/pages/MapPickerPage';

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
  });
}
