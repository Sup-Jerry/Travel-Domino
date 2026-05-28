import { describe, it, expect } from '@ohos/hypium';
import {
  PlanRepositoryImpl,
  PlanItem
} from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import {
  createPlanSearchPageForTest,
  shouldPlanSearchTriggerLoadMoreOnScroll
} from '../main/ets/pages/PlanSearchPage';

interface PlanSearchCacheEntryDJ {
  ts: number;
  list: PlanItem[];
  hasMore: boolean;
  offset: number;
}

interface PlanSearchPagePrivateDJ {
  keyword: string;
  resultList: PlanItem[];
  searching: boolean;
  loadingMore: boolean;
  hasMore: boolean;
  loaded: boolean;
  queryToken: number;
  debounceTimer: number;
  pageSize: number;
  currentKeyword: string;
  currentOffset: number;
  searchCache: Map<string, PlanSearchCacheEntryDJ>;
  aboutToAppear(): void;
  aboutToDisappear(): void;
  scheduleSearch(value: string): void;
  runSearch(rawKeyword: string): Promise<void>;
  loadMoreIfNeeded(): Promise<void>;
}

class SearchRepositoryMockDJ {
  public calls: string[] = [];
  public fail: boolean = false;
  public pages: Map<string, PlanItem[]> = new Map<string, PlanItem[]>();

  async searchAllPlansPaged(keyword: string, offset: number, limit: number): Promise<PlanItem[]> {
    this.calls.push(`${keyword}:${offset}:${limit}`);
    if (this.fail) {
      throw new Error('search_failed_dj');
    }
    const key = `${keyword}:${offset}`;
    return this.pages.has(key) ? (this.pages.get(key) as PlanItem[]) : [];
  }
}

class DeferredSearchResultDJ {
  public promise: Promise<PlanItem[]>;
  private resolver: ((value: PlanItem[]) => void) | null = null;

  constructor() {
    this.promise = new Promise<PlanItem[]>((resolve: (value: PlanItem[]) => void) => {
      this.resolver = resolve;
    });
  }

  resolve(value: PlanItem[]): void {
    if (this.resolver) {
      this.resolver(value);
      this.resolver = null;
    }
  }
}

class StaticPatchDJ {
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

function createPageDJ(): PlanSearchPagePrivateDJ {
  return createPlanSearchPageForTest() as PlanSearchPagePrivateDJ;
}

function patchSearchRepoDJ(mock: SearchRepositoryMockDJ): StaticPatchDJ {
  return new StaticPatchDJ(
    PlanRepositoryImpl as Object,
    'searchAllPlansPaged',
    async (keyword: string, offset: number, limit: number): Promise<PlanItem[]> => {
      return mock.searchAllPlansPaged(keyword, offset, limit);
    }
  );
}

function buildPlanDJ(id: number, title: string): PlanItem {
  return {
    id: id,
    title: title,
    createdAt: 1000 + id,
    startDate: new Date(2026, 3, 22).getTime(),
    status: 1,
    deleteTime: 0
  };
}

function buildPlansDJ(count: number, startId: number): PlanItem[] {
  const list: PlanItem[] = [];
  for (let i = 0; i < count; i += 1) {
    list.push(buildPlanDJ(startId + i, `plan-${startId + i}`));
  }
  return list;
}

async function flushMicrotasksDJ(): Promise<void> {
  for (let i = 0; i < 20; i += 1) {
    await Promise.resolve();
  }
}

export default function phase2BatchDJTest() {
  describe('phase2BatchDJTest', () => {
    it('normal: plan_search_run_search_should_store_results_and_cache_first_page', 0, async () => {
      // Arrange
      const repo = new SearchRepositoryMockDJ();
      repo.pages.set('tokyo:0', [buildPlanDJ(1, 'Tokyo'), buildPlanDJ(2, 'Tokyo Food')]);
      const patch = patchSearchRepoDJ(repo);
      const page = createPageDJ();

      // Act
      await page.runSearch('  tokyo  ');
      patch.restore();

      // Assert
      expect(page.loaded).assertTrue();
      expect(page.searching).assertFalse();
      expect(page.currentKeyword).assertEqual('tokyo');
      expect(page.currentOffset).assertEqual(2);
      expect(page.resultList.length).assertEqual(2);
      expect(page.searchCache.has('tokyo')).assertTrue();
    });

    it('boundary: plan_search_run_search_should_use_fresh_cache_without_repository_call', 0, async () => {
      // Arrange
      const repo = new SearchRepositoryMockDJ();
      repo.pages.set('kyoto:0', [buildPlanDJ(3, 'Kyoto')]);
      const patch = patchSearchRepoDJ(repo);
      const page = createPageDJ();

      // Act
      await page.runSearch('kyoto');
      repo.fail = true;
      await page.runSearch('kyoto');
      patch.restore();

      // Assert
      expect(repo.calls.length).assertEqual(1);
      expect(page.loaded).assertTrue();
      expect(page.resultList.length).assertEqual(1);
      expect(page.currentKeyword).assertEqual('kyoto');
    });

    it('invalid: plan_search_run_search_should_clear_results_when_repository_fails', 0, async () => {
      // Arrange
      const repo = new SearchRepositoryMockDJ();
      repo.fail = true;
      const patch = patchSearchRepoDJ(repo);
      const page = createPageDJ();
      page.resultList = [buildPlanDJ(4, 'old')];

      // Act
      await page.runSearch('bad');
      patch.restore();

      // Assert
      expect(page.loaded).assertTrue();
      expect(page.searching).assertFalse();
      expect(page.resultList.length).assertEqual(0);
    });

    it('conflict: plan_search_load_more_should_append_next_page_and_update_cache', 0, async () => {
      // Arrange
      const repo = new SearchRepositoryMockDJ();
      repo.pages.set('osaka:0', buildPlansDJ(40, 10));
      repo.pages.set('osaka:40', [buildPlanDJ(100, 'extra-a'), buildPlanDJ(101, 'extra-b')]);
      const patch = patchSearchRepoDJ(repo);
      const page = createPageDJ();

      // Act
      await page.runSearch('osaka');
      await page.loadMoreIfNeeded();
      patch.restore();

      // Assert
      expect(page.loadingMore).assertFalse();
      expect(page.resultList.length).assertEqual(42);
      expect(page.currentOffset).assertEqual(42);
      expect(page.hasMore).assertFalse();
      expect(page.searchCache.get('osaka')?.offset).assertEqual(42);
    });

    it('regression: plan_search_load_more_should_noop_when_guard_blocks_or_result_empty', 0, async () => {
      // Arrange
      const repo = new SearchRepositoryMockDJ();
      repo.pages.set('nara:0', buildPlansDJ(40, 200));
      repo.pages.set('nara:40', []);
      const patch = patchSearchRepoDJ(repo);
      const page = createPageDJ();
      page.loaded = false;

      // Act
      await page.loadMoreIfNeeded();
      await page.runSearch('nara');
      await page.loadMoreIfNeeded();
      patch.restore();

      // Assert
      expect(repo.calls.length).assertEqual(2);
      expect(page.loadingMore).assertFalse();
      expect(page.resultList.length).assertEqual(40);
      expect(page.hasMore).assertFalse();
    });

    it('combined: plan_search_lifecycle_should_run_initial_search_and_clear_debounce_timer', 0, async () => {
      // Arrange
      const repo = new SearchRepositoryMockDJ();
      repo.pages.set(':0', [buildPlanDJ(300, 'Initial')]);
      const patch = patchSearchRepoDJ(repo);
      const page = createPageDJ();

      // Act
      page.aboutToAppear();
      await flushMicrotasksDJ();
      page.scheduleSearch('later');
      const hasTimer = page.debounceTimer > 0;
      page.aboutToDisappear();
      patch.restore();

      // Assert
      expect(hasTimer).assertTrue();
      expect(page.debounceTimer).assertEqual(-1);
      expect(page.loaded).assertTrue();
      expect(page.resultList.length).assertEqual(1);
    });

    it('conflict: plan_search_run_search_should_ignore_stale_slow_result_when_newer_query_finishes_first', 0, async () => {
      // Arrange
      const deferred = new DeferredSearchResultDJ();
      const page = createPageDJ();
      const patch = new StaticPatchDJ(
        PlanRepositoryImpl as Object,
        'searchAllPlansPaged',
        async (keyword: string, _offset: number, _limit: number): Promise<PlanItem[]> => {
          if (keyword === 'slow') {
            return deferred.promise;
          }
          return [buildPlanDJ(901, 'fast-result')];
        }
      );

      // Act
      const slowPromise = page.runSearch('slow');
      await page.runSearch('fast');
      deferred.resolve([buildPlanDJ(900, 'slow-result')]);
      await slowPromise;
      patch.restore();

      // Assert
      expect(page.currentKeyword).assertEqual('fast');
      expect(page.resultList.length).assertEqual(1);
      expect(page.resultList[0].title).assertEqual('fast-result');
      expect(page.searchCache.has('fast')).assertTrue();
    });

    it('combined: plan_search_load_more_should_ignore_stale_more_page_after_keyword_switch', 0, async () => {
      // Arrange
      const deferred = new DeferredSearchResultDJ();
      const page = createPageDJ();
      const patch = new StaticPatchDJ(
        PlanRepositoryImpl as Object,
        'searchAllPlansPaged',
        async (keyword: string, offset: number, _limit: number): Promise<PlanItem[]> => {
          if (keyword === 'osaka' && offset === 0) {
            return buildPlansDJ(40, 1000);
          }
          if (keyword === 'osaka' && offset === 40) {
            return deferred.promise;
          }
          if (keyword === 'kyoto' && offset === 0) {
            return [buildPlanDJ(2000, 'kyoto-only')];
          }
          return [];
        }
      );

      // Act
      await page.runSearch('osaka');
      const loadingMorePromise = page.loadMoreIfNeeded();
      await page.runSearch('kyoto');
      deferred.resolve([buildPlanDJ(1001, 'stale-osaka-more')]);
      await loadingMorePromise;
      patch.restore();

      // Assert
      expect(page.currentKeyword).assertEqual('kyoto');
      expect(page.resultList.length).assertEqual(1);
      expect(page.resultList[0].title).assertEqual('kyoto-only');
      expect(page.searchCache.has('kyoto')).assertTrue();
    });

    it('boundary: plan_search_about_to_disappear_should_noop_when_no_timer_and_schedule_search_should_replace_existing_timer', 0, async () => {
      // Arrange
      const page = createPageDJ();
      page.debounceTimer = 7;

      // Act
      page.scheduleSearch('reload');
      const replacedTimer = page.debounceTimer;
      page.aboutToDisappear();
      const clearedTimer = page.debounceTimer;
      page.aboutToDisappear();

      // Assert
      expect(page.keyword).assertEqual('reload');
      expect(replacedTimer > 0).assertTrue();
      expect(clearedTimer).assertEqual(-1);
      expect(page.debounceTimer).assertEqual(-1);
    });

    it('combined: plan_search_scroll_helper_should_distinguish_tail_and_non_tail_ranges', 0, () => {
      // Arrange
      // Act
      const shouldLoadAtTail = shouldPlanSearchTriggerLoadMoreOnScroll(4, 5);
      const shouldSkipBeforeTail = shouldPlanSearchTriggerLoadMoreOnScroll(2, 5);

      // Assert
      expect(shouldLoadAtTail).assertTrue();
      expect(shouldSkipBeforeTail).assertFalse();
    });
  });
}
