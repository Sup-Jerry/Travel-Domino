import { promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';

export type AppNavTab = 'search' | 'trash' | 'home' | 'archive' | 'profile';

interface TabMeta {
  key: AppNavTab;
  label: string;
  normalIcon: ResourceStr;
  activeIcon: ResourceStr;
}

class RouterUrlOptions {
  url: string = '';
}

const NAV_TAG = 'BottomNavBar';

@Component
export struct GlobalBottomNavBar {
  @Prop currentTab: AppNavTab = 'home';
  @Prop showCenterFab: boolean = false;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  @State pressedTab: AppNavTab | '' = '';
  @State transitionTab: AppNavTab | '' = '';
  @State navLocked: boolean = false;
  @State fabPressed: boolean = false;

  onCenterFabTap: () => void = () => {};
  onSearchTap: () => Promise<void> = async () => {
    await this.safeReplaceUrl(this.createRouteOptions('pages/PlanSearchPage'), 'pages/PlanSearchPage');
  };
  private readonly tabSwitchDelayMs: number = 110;
  private readonly navLockMs: number = 320;

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private searchTab: TabMeta = {
    key: 'search',
    label: '搜索',
    normalIcon: $r('app.media.nav_search_n'),
    activeIcon: $r('app.media.nav_search_a')
  };

  private trashTab: TabMeta = {
    key: 'trash',
    label: '回收站',
    normalIcon: $r('app.media.nav_trash_n'),
    activeIcon: $r('app.media.nav_trash_a')
  };

  private homeTab: TabMeta = {
    key: 'home',
    label: '主页',
    normalIcon: $r('app.media.nav_home_n'),
    activeIcon: $r('app.media.nav_home_a')
  };

  private archiveTab: TabMeta = {
    key: 'archive',
    label: '归档箱',
    normalIcon: $r('app.media.nav_archive_n'),
    activeIcon: $r('app.media.nav_archive_a')
  };

  private profileTab: TabMeta = {
    key: 'profile',
    label: '我的',
    normalIcon: $r('app.media.nav_profile_n'),
    activeIcon: $r('app.media.nav_profile_a')
  };

  private createRouteOptions(url: string): RouterUrlOptions {
    const options: RouterUrlOptions = new RouterUrlOptions();
    options.url = url;
    return options;
  }

  private async safeReplaceUrl(options: RouterUrlOptions, routeLabel: string): Promise<void> {
    try {
      await this.getUIContext().getRouter().replaceUrl(options);
    } catch (error) {
      hilog.warn(0x0000, NAV_TAG, `[BOTTOM_NAV][route_failed] to=${routeLabel}, reason=${JSON.stringify(error)}`);
      try {
        promptAction.openToast({ message: '页面跳转失败，请重试' });
      } catch (toastError) {
        hilog.warn(0x0000, NAV_TAG, `[BOTTOM_NAV][toast_failed] reason=${JSON.stringify(toastError)}`);
      }
    }
  }

  private async navigateTo(tab: AppNavTab): Promise<void> {
    hilog.info(0x0000, NAV_TAG, `[BOTTOM_NAV][tap] tab=${tab}, current=${this.currentTab}`);
    if (tab === this.currentTab) {
      return;
    }

    if (tab === 'search') {
      await this.onSearchTap();
      hilog.info(0x0000, NAV_TAG, '[BOTTOM_NAV][route] to=pages/PlanSearchPage');
      return;
    }

    if (tab === 'home') {
      await this.safeReplaceUrl(this.createRouteOptions('pages/PlanListPage'), 'pages/PlanListPage');
      hilog.info(0x0000, NAV_TAG, '[BOTTOM_NAV][route] to=pages/PlanListPage');
      return;
    }

    if (tab === 'archive') {
      await this.safeReplaceUrl(this.createRouteOptions('pages/ArchivePage'), 'pages/ArchivePage');
      hilog.info(0x0000, NAV_TAG, '[BOTTOM_NAV][route] to=pages/ArchivePage');
      return;
    }

    if (tab === 'trash') {
      await this.safeReplaceUrl(this.createRouteOptions('pages/TrashPage'), 'pages/TrashPage');
      hilog.info(0x0000, NAV_TAG, '[BOTTOM_NAV][route] to=pages/TrashPage');
      return;
    }

    await this.safeReplaceUrl(this.createRouteOptions('pages/MyPage'), 'pages/MyPage');
    hilog.info(0x0000, NAV_TAG, '[BOTTOM_NAV][route] to=pages/MyPage');
  }

  private isVisualActive(tab: AppNavTab): boolean {
    const visualTab = this.transitionTab || this.currentTab;
    return visualTab === tab;
  }

  private isTabPressed(tab: AppNavTab): boolean {
    return this.pressedTab === tab;
  }

  private setTabPressed(tab: AppNavTab, pressed: boolean): void {
    const next = pressed ? tab : '';
    if (this.pressedTab === next) {
      return;
    }
    this.getUIContext().animateTo({ duration: pressed ? 70 : 130, curve: pressed ? Curve.Sharp : Curve.Friction }, () => {
      this.pressedTab = next;
    });
  }

  private onTabTouch(tab: AppNavTab, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.setTabPressed(tab, true);
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.setTabPressed(tab, false);
    }
  }

  private handleTabTap(tab: AppNavTab): void {
    if (tab === this.currentTab) {
      this.transitionTab = '';
      this.navLocked = false;
      return;
    }
    if (this.navLocked) {
      return;
    }
    this.navLocked = true;
    this.getUIContext().animateTo({ duration: 160, curve: Curve.Friction }, () => {
      this.transitionTab = tab;
    });
    setTimeout(() => {
      void this.navigateTo(tab);
    }, this.tabSwitchDelayMs);
    setTimeout(() => {
      this.transitionTab = '';
      this.navLocked = false;
    }, this.navLockMs);
  }

  @Builder
  private NormalTabCell(tab: TabMeta) {
    Column({ space: 4 }) {
      Image(this.isVisualActive(tab.key) ? tab.activeIcon : tab.normalIcon)
        .width(22)
        .height(22)
        .opacity(this.isTabPressed(tab.key) ? 0.82 : (this.isVisualActive(tab.key) ? 1 : 0.9));
      Text(tab.label)
        .fontSize(10)
        .fontColor(this.isVisualActive(tab.key) ? this.getPalette().primary : this.getPalette().textSecondary)
        .fontWeight(this.isVisualActive(tab.key) ? FontWeight.Medium : FontWeight.Normal);
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height(62)
    .layoutWeight(1)
    .scale({
      x: this.isTabPressed(tab.key) ? 0.94 : (this.isVisualActive(tab.key) ? 1 : 0.985),
      y: this.isTabPressed(tab.key) ? 0.94 : (this.isVisualActive(tab.key) ? 1 : 0.985)
    })
    .opacity(this.isTabPressed(tab.key) ? 0.9 : 1)
    .onTouch((event: TouchEvent) => {
      this.onTabTouch(tab.key, event);
    })
    .onClick(() => {
      this.handleTabTap(tab.key);
    });
  }

  @Builder
  private HomeTabCell() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 4 }) {
        Image(this.isVisualActive(this.homeTab.key) ? this.homeTab.activeIcon : this.homeTab.normalIcon)
          .width(22)
          .height(22)
          .opacity(this.isTabPressed(this.homeTab.key) ? 0.82 : (this.isVisualActive(this.homeTab.key) ? 1 : 0.9));
        Text(this.homeTab.label)
          .fontSize(10)
          .fontColor(this.isVisualActive(this.homeTab.key) ? this.getPalette().primary : this.getPalette().textSecondary)
          .fontWeight(this.isVisualActive(this.homeTab.key) ? FontWeight.Medium : FontWeight.Normal);
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .height(62)
      .width('100%')
      .scale({
        x: this.isTabPressed(this.homeTab.key) ? 0.94 : (this.isVisualActive(this.homeTab.key) ? 1 : 0.985),
        y: this.isTabPressed(this.homeTab.key) ? 0.94 : (this.isVisualActive(this.homeTab.key) ? 1 : 0.985)
      })
      .opacity(this.isTabPressed(this.homeTab.key) ? 0.9 : 1)
      .onTouch((event: TouchEvent) => {
        this.onTabTouch(this.homeTab.key, event);
      })
      .onClick(() => {
        this.handleTabTap(this.homeTab.key);
      });

      if (this.showCenterFab) {
        Button() {
          Image($r('app.media.nav_add_plan_fab'))
            .width(54)
            .height(54);
        }
        .width(60)
        .height(60)
        .margin({ top: -28 })
        .backgroundColor(Color.Transparent)
        .padding(0)
        .borderRadius(30)
        .scale({ x: this.fabPressed ? 0.92 : 1, y: this.fabPressed ? 0.92 : 1 })
        .opacity(this.fabPressed ? 0.9 : 1)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.getUIContext().animateTo({ duration: 70, curve: Curve.Sharp }, () => {
              this.fabPressed = true;
            });
            return;
          }
          if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.getUIContext().animateTo({ duration: 130, curve: Curve.Friction }, () => {
              this.fabPressed = false;
            });
          }
        })
        .onClick(() => {
          hilog.info(0x0000, NAV_TAG, '[BOTTOM_NAV][fab] tap');
          this.onCenterFabTap();
        });
      }
    }
    .layoutWeight(1)
    .height(62);
  }

  build() {
    Row() {
      this.NormalTabCell(this.searchTab);
      this.NormalTabCell(this.trashTab);
      this.HomeTabCell();
      this.NormalTabCell(this.archiveTab);
      this.NormalTabCell(this.profileTab);
    }
    .width('100%')
    .height(80)
    .padding({ left: 6, right: 6, top: 4, bottom: 2 })
    .backgroundColor(this.getPalette().cardBg)
    .border({ width: { top: 1 }, color: this.getPalette().divider });
  }
}

@Component
export struct PlanBottomActionBar {
  onFilter: () => void = () => {};
  onAi: () => void = () => {};
  onAdd: () => void = () => {};
  @Prop aiEnabled: boolean = true;
  @Prop addEnabled: boolean = true;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  @Builder
  private ActionCell(label: string, icon: ResourceStr, enabled: boolean, onTap: () => void) {
    Column({ space: 4 }) {
      Image(icon)
        .width(20)
        .height(20)
        .opacity(enabled ? 1 : 0.45);
      Text(label)
        .fontSize(11)
        .fontColor(enabled ? this.getPalette().textPrimary : this.getPalette().textTertiary);
    }
    .layoutWeight(1)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (enabled) {
        onTap();
      }
    });
  }

  build() {
    Row() {
      this.ActionCell('筛选', $r('app.media.tool_filter'), true, () => this.onFilter());
      this.ActionCell('新增', $r('app.media.tool_add'), this.addEnabled, () => this.onAdd());
      this.ActionCell('AI', $r('app.media.tool_ai'), this.aiEnabled, () => this.onAi());
    }
    .width('100%')
    .height(74)
    .padding({ left: 12, right: 12, top: 4, bottom: 8 })
    .backgroundColor(this.getPalette().cardBg)
    .border({ width: { top: 1 }, color: this.getPalette().divider });
  }
}

@Component
export struct CompanionBottomActionBar {
  onHistory: () => void = () => {};
  onImmersive: () => void = () => {};
  onSearch: () => void = () => {};
  onFilter: () => void = () => {};
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  @Builder
  private ActionCell(label: string, icon: ResourceStr, onTap: () => void) {
    Column({ space: 4 }) {
      Image(icon)
        .width(20)
        .height(20);
      Text(label)
        .fontSize(11)
        .fontColor(this.getPalette().textSecondary);
    }
    .layoutWeight(1)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      onTap();
    });
  }

  build() {
    Row() {
      this.ActionCell('历史', $r('app.media.tool_history'), () => this.onHistory());
      this.ActionCell('沉浸模式', $r('app.media.tool_immersive'), () => this.onImmersive());
      this.ActionCell('搜索', $r('app.media.tool_search'), () => this.onSearch());
      this.ActionCell('筛选', $r('app.media.tool_filter'), () => this.onFilter());
    }
    .width('100%')
    .height(76)
    .padding({ left: 12, right: 12, top: 6, bottom: 10 })
    .backgroundColor(this.getPalette().companionBg)
    .border({ width: { top: 1 }, color: this.getPalette().border });
  }
}










