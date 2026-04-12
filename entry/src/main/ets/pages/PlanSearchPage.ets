import { PlanRepositoryImpl, PlanItem } from '../infrastructure/persistence/PlanRepositoryImpl';
import { router } from '@kit.ArkUI';
import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { DateUtil } from '../common/utils/DateUtil';

const TAG = 'PlanSearchPage';

interface PlanSearchCacheEntry {
  ts: number;
  list: PlanItem[];
  hasMore: boolean;
  offset: number;
}

export function normalizePlanSearchKeyword(rawKeyword: string): string {
  return String(rawKeyword || '').trim();
}

export function resolvePlanSearchCacheKey(rawKeyword: string): string {
  const keywordLower = normalizePlanSearchKeyword(rawKeyword).toLowerCase();
  return keywordLower.length > 0 ? keywordLower : '__empty__';
}

export function isPlanSearchTrashPlan(deleteTime: number): boolean {
  return deleteTime > 0;
}

export function resolvePlanSearchStateLabel(status: number, deleteTime: number): string {
  if (isPlanSearchTrashPlan(deleteTime)) {
    return '回收站';
  }
  return status === 2 ? '归档' : '规划';
}

export function resolvePlanSearchStateColor(status: number, deleteTime: number): string {
  if (isPlanSearchTrashPlan(deleteTime)) {
    return '#D03D3D';
  }
  return status === 2 ? '#7A8699' : '#1F8FFF';
}

export function shouldPlanSearchLoadMore(
  loaded: boolean,
  searching: boolean,
  loadingMore: boolean,
  hasMore: boolean
): boolean {
  return loaded && !searching && !loadingMore && hasMore;
}

@Entry
@Component
struct PlanSearchPage {
  @State keyword: string = '';
  @State resultList: PlanItem[] = [];
  @State searching: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = false;
  @State loaded: boolean = false;
  @State queryToken: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private debounceTimer: number = -1;
  private readonly pageSize: number = 40;
  private currentKeyword: string = '';
  private currentOffset: number = 0;
  private readonly searchCacheTtlMs: number = 3000;
  private readonly searchCache: Map<string, PlanSearchCacheEntry> = new Map();

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear(): void {
    this.runSearch('');
  }

  aboutToDisappear(): void {
    if (this.debounceTimer > 0) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = -1;
    }
  }

  private getPlanStateLabel(item: PlanItem): string {
    return resolvePlanSearchStateLabel(Number(item.status || 0), Number(item.deleteTime || 0));
  }

  private getPlanStateColor(item: PlanItem): ResourceColor {
    return resolvePlanSearchStateColor(Number(item.status || 0), Number(item.deleteTime || 0));
  }

  private scheduleSearch(value: string): void {
    this.keyword = value;
    if (this.debounceTimer > 0) {
      clearTimeout(this.debounceTimer);
    }

    this.debounceTimer = setTimeout(() => {
      this.runSearch(this.keyword);
    }, 250) as number;
  }

  private async runSearch(rawKeyword: string): Promise<void> {
    const keyword = normalizePlanSearchKeyword(rawKeyword);
    const cacheKey = resolvePlanSearchCacheKey(keyword);
    const cached = this.searchCache.get(cacheKey);
    if (cached && Date.now() - cached.ts <= this.searchCacheTtlMs) {
      this.resultList = [...cached.list];
      this.currentKeyword = keyword;
      this.currentOffset = cached.offset;
      this.hasMore = cached.hasMore;
      this.loaded = true;
      this.searching = false;
      return;
    }

    const token = ++this.queryToken;
    this.searching = true;
    this.loadingMore = false;
    this.currentKeyword = keyword;
    this.currentOffset = 0;
    this.hasMore = false;

    try {
      const list = await PlanRepositoryImpl.searchAllPlansPaged(keyword, 0, this.pageSize);

      if (token !== this.queryToken) {
        return;
      }

      this.resultList = list;
      this.currentOffset = list.length;
      this.hasMore = list.length >= this.pageSize;
      const cacheEntry: PlanSearchCacheEntry = {
        ts: Date.now(),
        list: [...list],
        hasMore: this.hasMore,
        offset: this.currentOffset
      };
      this.searchCache.set(cacheKey, cacheEntry);
      this.loaded = true;
      hilog.info(0x0000, TAG, `[PLAN_SEARCH][result] keyword=${keyword}, count=${this.resultList.length}`);
    } catch (error) {
      hilog.warn(0x0000, TAG, `[PLAN_SEARCH][error] keyword=${keyword}, reason=${JSON.stringify(error)}`);
      this.resultList = [];
      this.loaded = true;
    } finally {
      if (token === this.queryToken) {
        this.searching = false;
      }
    }
  }

  private async loadMoreIfNeeded(): Promise<void> {
    if (!shouldPlanSearchLoadMore(this.loaded, this.searching, this.loadingMore, this.hasMore)) {
      return;
    }
    const token = this.queryToken;
    const keyword = this.currentKeyword;
    this.loadingMore = true;
    try {
      const more = await PlanRepositoryImpl.searchAllPlansPaged(keyword, this.currentOffset, this.pageSize);
      if (token !== this.queryToken) {
        return;
      }
      if (more.length === 0) {
        this.hasMore = false;
        return;
      }
      this.resultList = [...this.resultList, ...more];
      this.currentOffset += more.length;
      this.hasMore = more.length >= this.pageSize;
      const cacheKey = resolvePlanSearchCacheKey(keyword);
      this.searchCache.set(cacheKey, {
        ts: Date.now(),
        list: [...this.resultList],
        hasMore: this.hasMore,
        offset: this.currentOffset
      });
    } catch (error) {
      hilog.warn(0x0000, TAG, `[PLAN_SEARCH][load_more_error] keyword=${keyword}, reason=${JSON.stringify(error)}`);
    } finally {
      if (token === this.queryToken) {
        this.loadingMore = false;
      }
    }
  }

  private openPlan(item: PlanItem): void {
    hilog.info(0x0000, TAG, `[PLAN_SEARCH][select] planId=${item.id}, title=${item.title}`);
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/Index',
        params: {
          planId: item.id,
          title: item.title,
          isNewPlan: false
        }
      });
    } catch (error) {
      hilog.warn(0x0000, TAG, `[PLAN_SEARCH][open_failed] planId=${item.id}, reason=${JSON.stringify(error)}`);
    }
  }

  @Builder
  private SearchHeader() {
    Column({ space: 10 }) {
      Row() {
        Text('搜索计划')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary);
      }
      .width('100%')
      .justifyContent(FlexAlign.Start);

      TextInput({ text: this.keyword, placeholder: '输入关键词（计划名）' })
        .width('100%')
        .height(42)
        .backgroundColor(this.getThemePalette().cardBg)
        .borderRadius(10)
        .fontSize(15)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.scheduleSearch(value);
        });

      if (this.searching) {
        Text('搜索中...')
          .fontSize(12)
          .fontColor(this.getThemePalette().textSecondary);
      } else if (this.loadingMore) {
        Text(`结果 ${this.resultList.length} 条（加载更多中）`)
          .fontSize(12)
          .fontColor(this.getThemePalette().textSecondary);
      } else {
        Text(`结果 ${this.resultList.length} 条`) 
          .fontSize(12)
          .fontColor(this.getThemePalette().textSecondary);
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 8 })
    .backgroundColor(this.getThemePalette().pageBg);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.SearchHeader();

        if (this.loaded && this.resultList.length === 0 && !this.searching) {
          Column({ space: 8 }) {
            Text('没有匹配的计划')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemePalette().textPrimary);
            Text('可尝试更短关键词，或返回主页创建新计划')
              .fontSize(12)
              .fontColor(this.getThemePalette().textSecondary);
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center);
        } else {
          List({ space: 10 }) {
            ForEach(this.resultList, (item: PlanItem) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Row() {
                      Text(item.title)
                        .fontSize(17)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.getThemePalette().textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1);

                      Text(this.getPlanStateLabel(item))
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .backgroundColor(this.getPlanStateColor(item))
                        .borderRadius(6)
                        .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                        .margin({ left: 8 });
                    }
                    .width('100%');

                    Text(`出发日期: ${DateUtil.formatPlanDate(item.startDate)}`)
                      .fontSize(12)
                      .fontColor(this.getThemePalette().primary);
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start);

                  Text('进入 >')
                    .fontSize(13)
                    .fontColor(this.getThemePalette().textTertiary);
                }
                .width('100%')
                .padding(14)
                .backgroundColor(this.getThemePalette().cardBg)
                .borderRadius(12)
                .onClick(() => {
                  this.openPlan(item);
                });
              };
            }, (item: PlanItem) => item.id.toString());
            if (this.loadingMore) {
              ListItem() {
                Text('加载更多中...')
                  .fontSize(12)
                  .fontColor(this.getThemePalette().textSecondary)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 8, bottom: 8 });
              };
            }
            ListItem().height(10);
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 8, bottom: 90 })
          .onScrollIndex((start: number, end: number, _center: number) => {
            if (end >= this.resultList.length - 1) {
              void this.loadMoreIfNeeded();
            }
          });
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getThemePalette().pageBg);

      GlobalBottomNavBar({
        currentTab: 'search',
        showCenterFab: false
      })
        .zIndex(9);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}






