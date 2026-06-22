import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

export type CompanionFilterState = 'ALL' | 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'SKIPPED';

function noopCompanionFilterVoid(): void {}

function noopCompanionFilterSelect(_item: CompanionFilterState): void {}

function defaultCompanionFilterOptions(): CompanionFilterState[] {
  return ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];
}

function defaultCompanionFilterLabel(_state: CompanionFilterState): string {
  return '--';
}

export function shouldShowCompanionFilterPage(showFilterPage: boolean): boolean {
  return showFilterPage;
}

export function isCompanionFilterSelected(item: CompanionFilterState, current: CompanionFilterState): boolean {
  return item === current;
}

export function getCompanionFilterBorderWidth(item: CompanionFilterState, current: CompanionFilterState): number {
  return isCompanionFilterSelected(item, current) ? 1 : 0;
}

export function getCompanionFilterBorderType(item: CompanionFilterState): 'pending' | 'skipped' | 'completed' | 'default' {
  if (item === 'PENDING') {
    return 'pending';
  }
  if (item === 'SKIPPED') {
    return 'skipped';
  }
  if (item === 'COMPLETED') {
    return 'completed';
  }
  return 'default';
}

@Component
export struct CompanionFilterPage {
  @Prop showFilterPage: boolean = false;
  @Prop companionFilterState: CompanionFilterState = 'ALL';
  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onClose = noopCompanionFilterVoid;
  onFilterSelect = noopCompanionFilterSelect;
  getFilterOptions = defaultCompanionFilterOptions;
  getFilterLabel = defaultCompanionFilterLabel;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    if (shouldShowCompanionFilterPage(this.showFilterPage)) {
      Column({ space: 10 }) {
        Row() {
          Text('选择筛选')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
          Blank();
          Text('关闭')
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .onClick(() => {
              this.onClose();
            });
        }
        .width('100%')
        .padding({ top: this.safeTopInset + 8, bottom: 8 });

        Column({ space: 8 }) {
          ForEach(this.getFilterOptions(), (item: CompanionFilterState) => {
            Row() {
              Text(this.getFilterLabel(item))
                .fontSize(15)
                .fontWeight(isCompanionFilterSelected(item, this.companionFilterState) ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(isCompanionFilterSelected(item, this.companionFilterState)
                  ? this.getThemePalette().textPrimary
                  : this.getThemePalette().textSecondary);
              Blank();
              if (isCompanionFilterSelected(item, this.companionFilterState)) {
                Text('已选')
                  .fontSize(12)
                  .fontColor(this.getThemePalette().primary);
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 12, right: 12 })
            .backgroundColor(isCompanionFilterSelected(item, this.companionFilterState)
              ? this.getThemePalette().cardBgSoft
              : this.getThemePalette().companionCardBg)
            .border({
              width: getCompanionFilterBorderWidth(item, this.companionFilterState),
              color: getCompanionFilterBorderType(item) === 'pending'
                ? this.getThemePalette().statusPending
                : (getCompanionFilterBorderType(item) === 'skipped'
                  ? this.getThemePalette().statusSkipped
                  : (getCompanionFilterBorderType(item) === 'completed'
                    ? this.getThemePalette().statusCompleted
                    : this.getThemePalette().border)),
              radius: 10
            })
            .borderRadius(10)
            .onClick(() => {
              this.onFilterSelect(item);
            });
          }, (item: CompanionFilterState) => item);
        }
        .width('100%');
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: this.safeBottomInset + 14 })
      .backgroundColor(this.getThemePalette().companionBg)
      .zIndex(10)
      .transition({
        type: TransitionType.All,
        opacity: 0,
        translate: { y: 18 },
        scale: { x: 0.985, y: 0.985 }
      });
    }
  }
}
