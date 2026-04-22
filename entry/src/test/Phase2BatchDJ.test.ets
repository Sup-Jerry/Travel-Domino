import { describe, it, expect } from '@ohos/hypium';
import {
  PlanRepositoryImpl,
  PlanItem
} from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { createPlanSearchPageForTest } from '../main/ets/pages/PlanSearchPage';

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
  });
}
