import { describe, it, expect } from '@ohos/hypium';
import { resolveIndexBacklogSectionMaxHeight } from '../main/ets/pages/index/IndexBacklogSection';

export default function indexBacklogSectionHelperTest() {
  describe('unit_test_case_generator_autofill_IndexBacklogSectionHelper', () => {
    it('normal: backlog_section_max_height_should_use_30_percent', 0, () => {
      // Arrange
      // Act
      const height = resolveIndexBacklogSectionMaxHeight();
      // Assert
      expect(height).assertEqual('30%');
    });

    it('boundary: backlog_section_max_height_should_not_be_empty', 0, () => {
      // Arrange
      // Act
      const height = resolveIndexBacklogSectionMaxHeight();
      // Assert
      expect(height.length > 0).assertTrue();
    });

    it('invalid: backlog_section_max_height_should_contain_percent_unit', 0, () => {
      // Arrange
      // Act
      const height = resolveIndexBacklogSectionMaxHeight();
      // Assert
      expect(height.includes('%')).assertTrue();
    });

    it('conflict: backlog_section_max_height_should_keep_stable_value_across_calls', 0, () => {
      // Arrange
      // Act
      const first = resolveIndexBacklogSectionMaxHeight();
      const second = resolveIndexBacklogSectionMaxHeight();
      // Assert
      expect(first).assertEqual(second);
    });

    it('regression: td-20260412-backlog_section_height_should_stay_30_percent', 0, () => {
      // Arrange
      // Act
      const height = resolveIndexBacklogSectionMaxHeight();
      // Assert
      expect(height).assertEqual('30%');
    });

    it('combined: backlog_section_max_height_should_match_expected_format', 0, () => {
      // Arrange
      // Act
      const height = resolveIndexBacklogSectionMaxHeight();
      const endsWithPercent = height.endsWith('%');
      const startsWithNumber = height.startsWith('3');
      // Assert
      expect(endsWithPercent).assertTrue();
      expect(startsWithNumber).assertTrue();
    });
  });
}

