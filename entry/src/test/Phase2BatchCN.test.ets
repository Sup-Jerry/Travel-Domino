import { describe, expect, it } from '@ohos/hypium';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import {
  createPlanSearchPageForTest,
  isPlanSearchCacheFresh,
  normalizePlanSearchKeyword,
  resolvePlanSearchCacheKey,
  resolvePlanSearchResultText,
  resolvePlanSearchStateColor,
  resolvePlanSearchStateLabel,
  shouldPlanSearchLoadMore
} from '../main/ets/pages/PlanSearchPage';

interface PlanSearchPagePrivateCN {
  keyword: string;
  resultList: PlanItem[];
  searching: boolean;
  loadingMore: boolean;
  hasMore: boolean;
  loaded: boolean;
  effectiveTheme: string;
  initialRender(): void;
  SearchHeader(): void;
  getPlanStateLabel(item: PlanItem): string;
  getPlanStateColor(item: PlanItem): string;
  openPlan(item: PlanItem): void;
}

interface PlanSearchRouterOptionsCN {
  url: string;
  params?: Object;
}

class PlanSearchRouterMockCN {
  public urls: string[] = [];
  public shouldFail: boolean = false;

  pushUrl(options: PlanSearchRouterOptionsCN): void {
    this.urls.push(options.url);
    if (this.shouldFail) {
      throw new Error('push_failed_cn');
    }
  }
}

class PlanSearchUiContextMockCN {
  public router: PlanSearchRouterMockCN = new PlanSearchRouterMockCN();

  getRouter(): PlanSearchRouterMockCN {
    return this.router;
  }
}

function createPlanSearchPageCN(uiContext?: PlanSearchUiContextMockCN): PlanSearchPagePrivateCN {
  const page = createPlanSearchPageForTest() as PlanSearchPagePrivateCN;
  if (uiContext) {
    Reflect.set(page as Object, 'getUIContext', (): PlanSearchUiContextMockCN => uiContext);
  }
  return page;
}

function buildPlanSearchItemCN(id: number, title: string, status: number, deleteTime: number = 0): PlanItem {
  return {
    id: id,
    title: title,
    createdAt: 1000 + id,
    startDate: new Date(2026, 3, 22).getTime(),
    status: status,
    deleteTime: deleteTime
  };
}

export default function phase2BatchCNTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCN_plan_search_extra', () => {
    it('normal: plan_search_cache_key_should_trim_and_lowercase_keyword', 0, () => {
      // Arrange
      const rawKeyword = '  Osaka Trip  ';

      // Act
      const normalized = normalizePlanSearchKeyword(rawKeyword);
      const cacheKey = resolvePlanSearchCacheKey(rawKeyword);

      // Assert
      expect(normalized).assertEqual('Osaka Trip');
      expect(cacheKey).assertEqual('osaka trip');
    });

    it('boundary: plan_search_cache_fresh_should_accept_exact_ttl_boundary', 0, () => {
      // Arrange
      const cachedAt = 1000;
      const ttlMs = 3000;

      // Act
      const fresh = isPlanSearchCacheFresh(cachedAt, 4000, ttlMs);
      const expired = isPlanSearchCacheFresh(cachedAt, 4001, ttlMs);

      // Assert
      expect(fresh).assertTrue();
      expect(expired).assertFalse();
    });

    it('invalid: plan_search_cache_fresh_should_reject_invalid_now_and_ttl', 0, () => {
      // Arrange
      const cachedAt = 1000;

      // Act
      const invalidNow = isPlanSearchCacheFresh(cachedAt, Number.NaN, 3000);
      const invalidTtl = isPlanSearchCacheFresh(cachedAt, 2000, Number.NaN);
      const reverseTime = isPlanSearchCacheFresh(5000, 2000, 3000);

      // Assert
      expect(invalidNow).assertFalse();
      expect(invalidTtl).assertFalse();
      expect(reverseTime).assertFalse();
    });

    it('conflict: plan_search_load_more_guard_should_block_when_any_ready_flag_is_false', 0, () => {
      // Arrange
      const cases: boolean[] = [
        shouldPlanSearchLoadMore(false, false, false, true),
        shouldPlanSearchLoadMore(true, true, false, true),
        shouldPlanSearchLoadMore(true, false, true, true),
        shouldPlanSearchLoadMore(true, false, false, false)
      ];

      // Act
      const allBlocked = cases.every((value) => value === false);

      // Assert
      expect(allBlocked).assertTrue();
    });

    it('regression: plan_search_result_text_should_floor_positive_count_and_clamp_negative_to_zero', 0, () => {
      // Arrange
      const decimalCount = 5.9;
      const negativeCount = -2;

      // Act
      const loadingText = resolvePlanSearchResultText(false, true, decimalCount);
      const normalText = resolvePlanSearchResultText(false, false, negativeCount);

      // Assert
      expect(loadingText.indexOf('5') >= 0).assertTrue();
      expect(normalText.indexOf('0') >= 0).assertTrue();
    });

    it('combined: plan_search_state_label_and_color_should_prioritize_trash_over_archive', 0, () => {
      // Arrange
      const archivedStatus = 2;
      const deleteTime = 1000;

      // Act
      const label = resolvePlanSearchStateLabel(archivedStatus, deleteTime);
      const color = resolvePlanSearchStateColor(archivedStatus, deleteTime);

      // Assert
      expect(label).assertEqual('回收站');
      expect(color).assertEqual('#D03D3D');
    });

    it('combined: plan_search_open_plan_should_push_index_route_with_ui_context', 0, () => {
      // Arrange
      const uiContext = new PlanSearchUiContextMockCN();
      const page = createPlanSearchPageCN(uiContext);
      const item = buildPlanSearchItemCN(501, 'Sendai', 1);

      // Act
      page.openPlan(item);

      // Assert
      expect(uiContext.router.urls.length).assertEqual(1);
      expect(uiContext.router.urls[0]).assertEqual('pages/Index');
    });

    it('combined: plan_search_open_plan_should_swallow_router_failures', 0, () => {
      // Arrange
      const uiContext = new PlanSearchUiContextMockCN();
      uiContext.router.shouldFail = true;
      const page = createPlanSearchPageCN(uiContext);
      const item = buildPlanSearchItemCN(502, 'Hakone', 2);
      let threw = false;

      // Act
      try {
        page.openPlan(item);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(uiContext.router.urls.length).assertEqual(1);
    });

    it('combined: plan_search_page_render_should_cover_unloaded_searching_and_loaded_list', 0, () => {
      // Arrange
      const page = createPlanSearchPageCN();
      const item = buildPlanSearchItemCN(503, 'Nikko', 2, 0);

      // Act
      page.effectiveTheme = 'light';
      page.loaded = false;
      page.searching = true;
      page.resultList = [];
      page.SearchHeader();
      page.initialRender();
      page.effectiveTheme = 'dark';
      page.loaded = true;
      page.searching = false;
      page.resultList = [item];
      const label = page.getPlanStateLabel(item);
      const color = page.getPlanStateColor(item);
      page.initialRender();

      // Assert
      expect(label).assertEqual('归档');
      expect(color).assertEqual('#7A8699');
      expect(page.resultList.length).assertEqual(1);
    });
  });
}
