import { describe, it, expect } from '@ohos/hypium';
import {
  isPlanSearchTrashPlan,
  normalizePlanSearchKeyword,
  resolvePlanSearchCacheKey,
  resolvePlanSearchStateColor,
  resolvePlanSearchStateLabel,
  shouldPlanSearchLoadMore
} from '../main/ets/pages/PlanSearchPage';

export default function planSearchPageHelperTest() {
  describe('unit_test_case_generator_autofill_PlanSearchPageHelper', () => {
    it('normal: plan_search_keyword_should_trim_spaces', 0, () => {
      // Arrange
      const rawKeyword = '  Hangzhou  ';
      // Act
      const keyword = normalizePlanSearchKeyword(rawKeyword);
      // Assert
      expect(keyword).assertEqual('Hangzhou');
    });

    it('boundary: plan_search_cache_key_should_use_empty_token_when_keyword_blank', 0, () => {
      // Arrange
      const rawKeyword = '   ';
      // Act
      const cacheKey = resolvePlanSearchCacheKey(rawKeyword);
      // Assert
      expect(cacheKey).assertEqual('__empty__');
    });

    it('invalid: plan_search_trash_plan_should_return_false_when_delete_time_is_zero', 0, () => {
      // Arrange
      const deleteTime = 0;
      // Act
      const isTrash = isPlanSearchTrashPlan(deleteTime);
      // Assert
      expect(isTrash).assertFalse();
    });

    it('conflict: plan_search_state_label_should_prioritize_trash_over_archive_status', 0, () => {
      // Arrange
      const archivedStatus = 2;
      const deleteTime = 123456;
      // Act
      const label = resolvePlanSearchStateLabel(archivedStatus, deleteTime);
      // Assert
      expect(label).assertEqual('回收站');
    });

    it('regression: td-20260412-plan_search_active_state_color_should_keep_blue', 0, () => {
      // Arrange
      const activeStatus = 1;
      // Act
      const color = resolvePlanSearchStateColor(activeStatus, 0);
      // Assert
      expect(color).assertEqual('#1F8FFF');
    });

    it('combined: plan_search_load_more_guard_should_require_all_ready_flags', 0, () => {
      // Arrange
      const loaded = true;
      const searching = false;
      const loadingMore = false;
      const hasMore = true;
      // Act
      const allowLoadMore = shouldPlanSearchLoadMore(loaded, searching, loadingMore, hasMore);
      // Assert
      expect(allowLoadMore).assertTrue();
    });
  });
}
