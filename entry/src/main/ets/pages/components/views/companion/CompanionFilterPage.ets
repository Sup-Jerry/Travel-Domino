import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

export type CompanionFilterState = 'ALL' | 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'SKIPPED';

@Component
export struct CompanionFilterPage {
  @Prop showFilterPage: boolean = false;
  @Prop companionFilterState: CompanionFilterState = 'ALL';
  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onClose: () => void = () => {};
  onFilterSelect: (item: CompanionFilterState) => void = (_item: CompanionFilterState) => {};
  getFilterOptions: () => CompanionFilterState[] = () => ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];
  getFilterLabel: (state: CompanionFilterState) => string = (_state: CompanionFilterState) => '--';

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    if (this.showFilterPage) {
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
                .fontWeight(item === this.companionFilterState ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(item === this.companionFilterState
                  ? this.getThemePalette().textPrimary
                  : this.getThemePalette().textSecondary);
              Blank();
              if (item === this.companionFilterState) {
                Text('已选')
                  .fontSize(12)
                  .fontColor(this.getThemePalette().primary);
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 12, right: 12 })
            .backgroundColor(item === this.companionFilterState
              ? this.getThemePalette().cardBgSoft
              : this.getThemePalette().companionCardBg)
            .border({
              width: item === this.companionFilterState ? 1 : 0,
              color: item === 'PENDING'
                ? this.getThemePalette().statusPending
                : (item === 'SKIPPED'
                  ? this.getThemePalette().statusSkipped
                  : (item === 'COMPLETED'
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
