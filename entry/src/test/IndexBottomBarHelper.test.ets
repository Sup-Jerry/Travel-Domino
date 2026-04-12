import { describe, it, expect } from '@ohos/hypium';
import {
  shouldEnableIndexBottomBarAdd,
  shouldEnableIndexBottomBarAi
} from '../main/ets/pages/index/IndexBottomBar';

export default function indexBottomBarHelperTest() {
  describe('unit_test_case_generator_autofill_IndexBottomBarHelper', () => {
    it('normal: bottom_bar_ai_should_follow_enabled_flag', 0, () => {
      // Arrange
      const enabled = true;

      // Act
      const show = shouldEnableIndexBottomBarAi(enabled);

      // Assert
      expect(show).assertTrue();
    });

    it('boundary: bottom_bar_add_should_support_false_flag', 0, () => {
      // Arrange
      const enabled = false;

      // Act
      const show = shouldEnableIndexBottomBarAdd(enabled);

      // Assert
      expect(show).assertFalse();
    });

    it('invalid: bottom_bar_helpers_should_return_boolean_type', 0, () => {
      // Arrange
      const ai = true;
      const add = false;

      // Act
      const aiResult = shouldEnableIndexBottomBarAi(ai);
      const addResult = shouldEnableIndexBottomBarAdd(add);

      // Assert
      expect(typeof aiResult === 'boolean').assertTrue();
      expect(typeof addResult === 'boolean').assertTrue();
    });

    it('conflict: bottom_bar_helpers_should_keep_flags_independent', 0, () => {
      // Arrange
      const ai = true;
      const add = false;

      // Act
      const aiResult = shouldEnableIndexBottomBarAi(ai);
      const addResult = shouldEnableIndexBottomBarAdd(add);

      // Assert
      expect(aiResult).assertTrue();
      expect(addResult).assertFalse();
    });

    it('regression: td-20260412-bottom_bar_add_true_should_remain_enabled', 0, () => {
      // Arrange
      const enabled = true;

      // Act
      const show = shouldEnableIndexBottomBarAdd(enabled);

      // Assert
      expect(show).assertTrue();
    });

    it('combined: bottom_bar_flag_matrix_should_count_enabled_items', 0, () => {
      // Arrange
      const matrix: boolean[] = [true, false, true, true];

      // Act
      const enabledCount = matrix.filter((v) => shouldEnableIndexBottomBarAi(v)).length;

      // Assert
      expect(enabledCount).assertEqual(3);
    });
  });
}

