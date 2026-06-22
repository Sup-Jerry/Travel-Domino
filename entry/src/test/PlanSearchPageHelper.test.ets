import { describe, it, expect } from '@ohos/hypium';
import { PlanItem, PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import {
  createPlanSearchPageForTest,
  isPlanSearchCacheFresh,
  isPlanSearchTrashPlan,
  normalizePlanSearchKeyword,
  resolvePlanSearchCacheKey,
  resolvePlanSearchResultText,
  resolvePlanSearchStateColor,
  resolvePlanSearchStateLabel,
  shouldPlanSearchLoadMore,
  shouldPlanSearchTriggerLoadMoreOnScroll
} from '../main/ets/pages/PlanSearchPage';

interface PlanSearchPagePrivateTest {
  keyword: string;
  resultList: PlanItem[];
  searching: boolean;
  loadingMore: boolean;
  hasMore: boolean;
  loaded: boolean;
  queryToken: number;
  effectiveTheme: string;
  debounceTimer: number;
  currentKeyword: string;
  currentOffset: number;
  searchCacheTtlMs: number;
  searchCache: Map<string, Object>;
  pageSize: number;
  aboutToDisappear(): void;
  aboutToAppear(): void;
  scheduleSearch(value: string): void;
  runSearch(rawKeyword: string): Promise<void>;
  loadMoreIfNeeded(): Promise<void>;
  handleScrollIndexEnd(end: number): void;
  initialRender(): void;
  getPlanStateLabel(item: PlanItem): string;
  getPlanStateColor(item: PlanItem): string;
  SearchHeader(): void;
  openPlan(item: PlanItem): void;
}

interface PlanSearchCacheEntryTest {
  ts: number;
  list: PlanItem[];
  hasMore: boolean;
  offset: number;
}

class PlanSearchRouteParamsHelperTest {
  planId: number = 0;
  title: string = '';
  isNewPlan: boolean = false;
}

class PlanSearchRouteOptionsHelperTest {
  url: string = '';
  params: PlanSearchRouteParamsHelperTest = new PlanSearchRouteParamsHelperTest();
}

class PlanSearchRouterHelperMockTest {
  pushedUrls: string[] = [];
  shouldThrow: boolean = false;

  pushUrl(options: PlanSearchRouteOptionsHelperTest): void {
    if (this.shouldThrow) {
      throw new Error('push_failed_helper');
    }
    this.pushedUrls.push(options.url);
  }
}

class PlanSearchUiContextHelperMockTest {
  router: PlanSearchRouterHelperMockTest = new PlanSearchRouterHelperMockTest();

  getRouter(): PlanSearchRouterHelperMockTest {
    return this.router;
  }
}

function createPlanSearchPagePrivateForTest(): PlanSearchPagePrivateTest {
  return createPlanSearchPageForTest() as PlanSearchPagePrivateTest;
}

function buildPlanSearchItemForTest(
  id: number,
  title: string,
  status: number,
  deleteTime: number = 0
): PlanItem {
  return {
    id: id,
    title: title,
    createdAt: new Date(2026, 3, 22, 8, 0, 0, 0).getTime(),
    startDate: new Date(2026, 4, id, 8, 0, 0, 0).getTime(),
    status: status,
    deleteTime: deleteTime
  };
}

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

    it('boundary: plan_search_state_label_should_return_planning_for_active_non_archive_plan', 0, () => {
      // Arrange
      const status = 1;
      const deleteTime = 0;
      // Act
      const label = resolvePlanSearchStateLabel(status, deleteTime);
      // Assert
      expect(label).assertEqual('规划');
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

    it('combined: plan_search_load_more_guard_should_block_each_unready_flag', 0, () => {
      // Arrange
      // Act
      const notLoaded = shouldPlanSearchLoadMore(false, false, false, true);
      const searchingNow = shouldPlanSearchLoadMore(true, true, false, true);
      const alreadyLoadingMore = shouldPlanSearchLoadMore(true, false, true, true);
      const noMore = shouldPlanSearchLoadMore(true, false, false, false);

      // Assert
      expect(notLoaded).assertFalse();
      expect(searchingNow).assertFalse();
      expect(alreadyLoadingMore).assertFalse();
      expect(noMore).assertFalse();
    });

    it('boundary: plan_search_cache_key_should_lowercase_trimmed_keyword', 0, () => {
      // Arrange
      const rawKeyword = '  BeiJing  ';

      // Act
      const cacheKey = resolvePlanSearchCacheKey(rawKeyword);

      // Assert
      expect(cacheKey).assertEqual('beijing');
    });

    it('conflict: plan_search_state_color_should_prioritize_trash_over_active_status', 0, () => {
      // Arrange
      const activeStatus = 1;
      const deleteTime = 1;

      // Act
      const color = resolvePlanSearchStateColor(activeStatus, deleteTime);
      const isTrash = isPlanSearchTrashPlan(deleteTime);

      // Assert
      expect(isTrash).assertTrue();
      expect(color).assertEqual('#D03D3D');
    });

    it('boundary: plan_search_cache_fresh_should_reject_invalid_or_reverse_time', 0, () => {
      // Arrange
      const cachedAt = 1000;
      const ttlMs = 3000;

      // Act
      const fresh = isPlanSearchCacheFresh(cachedAt, 4000, ttlMs);
      const expired = isPlanSearchCacheFresh(cachedAt, 4001, ttlMs);
      const reverse = isPlanSearchCacheFresh(5000, 4000, ttlMs);
      const invalid = isPlanSearchCacheFresh(Number.NaN, 4000, ttlMs);

      // Assert
      expect(fresh).assertTrue();
      expect(expired).assertFalse();
      expect(reverse).assertFalse();
      expect(invalid).assertFalse();
    });

    it('boundary: plan_search_cache_fresh_should_reject_negative_cached_time_and_invalid_ttl', 0, () => {
      // Arrange
      // Act
      const negativeCached = isPlanSearchCacheFresh(-1, 1000, 3000);
      const invalidTtl = isPlanSearchCacheFresh(1000, 2000, Number.NaN);

      // Assert
      expect(negativeCached).assertFalse();
      expect(invalidTtl).assertFalse();
    });

    it('combined: plan_search_result_text_should_prioritize_searching_and_loading_states', 0, () => {
      // Arrange
      const searching = true;
      const loadingMore = true;

      // Act
      const searchingText = resolvePlanSearchResultText(searching, loadingMore, 9);
      const loadingMoreText = resolvePlanSearchResultText(false, loadingMore, 5.9);
      const normalText = resolvePlanSearchResultText(false, false, -1);

      // Assert
      expect(searchingText).assertEqual('搜索中...');
      expect(loadingMoreText).assertEqual('结果 5 条（加载更多中）');
      expect(normalText).assertEqual('结果 0 条');
    });

    it('normal: plan_search_page_should_render_loaded_result_list', 0, () => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      const active = buildPlanSearchItemForTest(1, 'Shanghai Trip', 1);
      const archived = buildPlanSearchItemForTest(2, 'Archived Trip', 2);
      page.loaded = true;
      page.searching = false;
      page.loadingMore = false;
      page.hasMore = true;
      page.resultList = [active, archived];
      page.keyword = 'trip';
      page.effectiveTheme = 'light';

      // Act
      const activeLabel = page.getPlanStateLabel(active);
      const archivedColor = page.getPlanStateColor(archived);
      page.initialRender();

      // Assert
      expect(activeLabel).assertEqual('规划');
      expect(archivedColor).assertEqual('#7A8699');
      expect(page.resultList.length).assertEqual(2);
    });

    it('boundary: plan_search_page_should_render_empty_loaded_state', 0, () => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      page.loaded = true;
      page.searching = false;
      page.loadingMore = false;
      page.hasMore = false;
      page.resultList = [];
      page.keyword = 'missing';
      page.effectiveTheme = 'dark';

      // Act
      page.SearchHeader();
      page.initialRender();

      // Assert
      expect(page.loaded).assertTrue();
      expect(page.resultList.length).assertEqual(0);
    });

    it('combined: plan_search_page_should_render_loading_more_and_trash_state', 0, () => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      const trash = buildPlanSearchItemForTest(3, 'Deleted Trip', 2, 123456);
      page.loaded = true;
      page.searching = false;
      page.loadingMore = true;
      page.hasMore = true;
      page.resultList = [trash];
      page.keyword = 'deleted';
      page.effectiveTheme = 'light';

      // Act
      const label = page.getPlanStateLabel(trash);
      const color = page.getPlanStateColor(trash);
      page.initialRender();

      // Assert
      expect(label).assertEqual('回收站');
      expect(color).assertEqual('#D03D3D');
      expect(page.loadingMore).assertTrue();
    });

    it('combined: plan_search_page_should_render_searching_state_with_existing_results', 0, () => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      page.loaded = false;
      page.searching = true;
      page.loadingMore = false;
      page.hasMore = false;
      page.resultList = [buildPlanSearchItemForTest(4, 'Searching Trip', 1)];
      page.keyword = 'searching';
      page.effectiveTheme = 'dark';

      // Act
      page.SearchHeader();
      page.initialRender();

      // Assert
      expect(page.searching).assertTrue();
      expect(page.resultList.length).assertEqual(1);
    });

    it('combined: plan_search_page_should_open_route_once_and_swallow_route_failure', 0, () => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      const uiContext = new PlanSearchUiContextHelperMockTest();
      const active = buildPlanSearchItemForTest(5, 'Route Trip', 1);
      const trash = buildPlanSearchItemForTest(6, 'Trash Trip', 2, 99);
      Reflect.set(page as Object, 'getUIContext', (): PlanSearchUiContextHelperMockTest => uiContext);

      // Act
      const activeLabel = page.getPlanStateLabel(active);
      const activeColor = page.getPlanStateColor(active);
      const trashLabel = page.getPlanStateLabel(trash);
      page.openPlan(active);
      uiContext.router.shouldThrow = true;
      page.openPlan(active);

      // Assert
      expect(activeLabel).assertEqual('规划');
      expect(activeColor).assertEqual('#1F8FFF');
      expect(trashLabel).assertEqual('回收站');
      expect(uiContext.router.pushedUrls.length).assertEqual(1);
      expect(uiContext.router.pushedUrls[0]).assertEqual('pages/Index');
    });
    it('combined: plan_search_page_should_cover_scroll_threshold_and_disappear_timer_cleanup', 0, () => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      Reflect.set(page as Object, 'debounceTimer', 12);

      // Act
      const beforeLast = shouldPlanSearchTriggerLoadMoreOnScroll(7, 10);
      const lastItem = shouldPlanSearchTriggerLoadMoreOnScroll(9, 10);
      const beyondLast = shouldPlanSearchTriggerLoadMoreOnScroll(10, 10);
      page.aboutToDisappear();
      const timerAfterDisappear = Reflect.get(page as Object, 'debounceTimer') as number;

      // Assert
      expect(beforeLast).assertFalse();
      expect(lastItem).assertTrue();
      expect(beyondLast).assertTrue();
      expect(timerAfterDisappear).assertEqual(-1);
    });

    it('boundary: plan_search_page_about_to_appear_should_delegate_empty_keyword_search', 0, () => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      const originalRunSearch = Reflect.get(page as Object, 'runSearch') as (rawKeyword: string) => Promise<void>;
      let capturedKeyword = 'unset';

      Reflect.set(page as Object, 'runSearch', async (rawKeyword: string): Promise<void> => {
        capturedKeyword = rawKeyword;
      });

      try {
        // Act
        page.aboutToAppear();

        // Assert
        expect(capturedKeyword).assertEqual('');
      } finally {
        Reflect.set(page as Object, 'runSearch', originalRunSearch);
      }
    });

    it('combined: plan_search_page_schedule_and_cache_should_use_latest_keyword_and_fresh_cache', 0, async (done: Function) => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      let staleTimerCalled = 0;
      let scheduledKeyword = '';
      const originalRunSearch = Reflect.get(page as Object, 'runSearch') as (rawKeyword: string) => Promise<void>;
      const cached = [buildPlanSearchItemForTest(9, 'Cached Trip', 1)];
      const cachedEntry: PlanSearchCacheEntryTest = {
        ts: Date.now(),
        list: cached,
        hasMore: true,
        offset: cached.length
      };
      page.searchCache.set('cached', cachedEntry as Object);
      page.debounceTimer = setTimeout(() => {
        staleTimerCalled += 1;
      }, 320) as number;

      Reflect.set(page as Object, 'runSearch', async (rawKeyword: string): Promise<void> => {
        scheduledKeyword = rawKeyword;
      });

      try {
        // Act
        page.scheduleSearch('  Cached  ');
        await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
          setTimeout(() => resolve(), 320);
        });
        Reflect.set(page as Object, 'runSearch', originalRunSearch);
        await page.runSearch('  Cached  ');

        // Assert
        expect(staleTimerCalled).assertEqual(0);
        expect(page.keyword).assertEqual('  Cached  ');
        expect(scheduledKeyword).assertEqual('  Cached  ');
        expect(page.resultList.length).assertEqual(1);
        expect(page.resultList[0].title).assertEqual('Cached Trip');
        expect(page.currentKeyword).assertEqual('Cached');
        expect(page.currentOffset).assertEqual(1);
        expect(page.hasMore).assertTrue();
        expect(page.loaded).assertTrue();
        expect(page.searching).assertFalse();
        done();
      } finally {
        Reflect.set(page as Object, 'runSearch', originalRunSearch);
      }
    });

    it('regression: plan_search_page_load_more_and_scroll_should_append_results_and_refresh_cache', 0, async (done: Function) => {
      // Arrange
      const page = createPlanSearchPagePrivateForTest();
      const originalSearchAllPlansPaged = Reflect.get(PlanRepositoryImpl as Object, 'searchAllPlansPaged') as Object;
      const existing = buildPlanSearchItemForTest(20, 'Existing', 1);
      const appended = buildPlanSearchItemForTest(21, 'Appended', 2);
      page.loaded = true;
      page.searching = false;
      page.loadingMore = false;
      page.hasMore = true;
      page.queryToken = 3;
      page.currentKeyword = 'append';
      page.currentOffset = 1;
      page.resultList = [existing];

      Reflect.set(PlanRepositoryImpl as Object, 'searchAllPlansPaged', async (
        keyword: string,
        offset: number,
        limit: number
      ): Promise<PlanItem[]> => {
        expect(keyword).assertEqual('append');
        expect(offset).assertEqual(1);
        expect(limit).assertEqual(page.pageSize);
        return [appended];
      });

      try {
        // Act
        page.handleScrollIndexEnd(0);
        await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
          setTimeout(() => resolve(), 30);
        });

        // Assert
        expect(page.loadingMore).assertFalse();
        expect(page.resultList.length).assertEqual(2);
        expect(page.resultList[1].title).assertEqual('Appended');
        expect(page.currentOffset).assertEqual(2);
        expect(page.hasMore).assertFalse();
        expect(page.searchCache.has('append')).assertTrue();
        done();
      } finally {
        Reflect.set(PlanRepositoryImpl as Object, 'searchAllPlansPaged', originalSearchAllPlansPaged);
      }
    });
  });
}
