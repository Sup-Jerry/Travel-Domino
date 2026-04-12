import { describe, it, expect } from '@ohos/hypium';
import { shouldIncludeIndexBacklogEvent } from '../main/ets/pages/index/IndexBacklogView';

export default function indexBacklogViewHelperTest() {
  describe('unit_test_case_generator_autofill_IndexBacklogViewHelper', () => {
    it('normal: backlog_event_should_include_non_completed_status', 0, () => {
      // Arrange
      const status = 0;

      // Act
      const include = shouldIncludeIndexBacklogEvent(status);

      // Assert
      expect(include).assertTrue();
    });

    it('boundary: backlog_event_should_exclude_completed_status_one', 0, () => {
      // Arrange
      const status = 1;

      // Act
      const include = shouldIncludeIndexBacklogEvent(status);

      // Assert
      expect(include).assertFalse();
    });

    it('invalid: backlog_event_should_keep_boolean_return_type', 0, () => {
      // Arrange
      const status = -999;

      // Act
      const include = shouldIncludeIndexBacklogEvent(status);

      // Assert
      expect(typeof include === 'boolean').assertTrue();
    });

    it('conflict: backlog_event_filter_should_distinguish_status_zero_and_one', 0, () => {
      // Arrange
      const pending = 0;
      const completed = 1;

      // Act
      const includePending = shouldIncludeIndexBacklogEvent(pending);
      const includeCompleted = shouldIncludeIndexBacklogEvent(completed);

      // Assert
      expect(includePending).assertTrue();
      expect(includeCompleted).assertFalse();
    });

    it('regression: td-20260412-backlog_event_status_two_should_stay_included', 0, () => {
      // Arrange
      const status = 2;

      // Act
      const include = shouldIncludeIndexBacklogEvent(status);

      // Assert
      expect(include).assertTrue();
    });

    it('combined: backlog_event_filter_matrix_should_exclude_only_status_one', 0, () => {
      // Arrange
      const statuses: number[] = [0, 1, 2, 3];

      // Act
      const includedCount = statuses.filter((status) => shouldIncludeIndexBacklogEvent(status)).length;

      // Assert
      expect(includedCount).assertEqual(3);
    });
  });
}

