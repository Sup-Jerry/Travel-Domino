import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { SettingsSubPageHeader, SettingSwitchItem } from './components/views/SettingsItems';

@Entry
@Component
struct SettingsPrivacyPage {
  @State enableAmapRouteApi: boolean = false;
  @State loading: boolean = true;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear(): void {
    void this.reload();
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  private async reload(): Promise<void> {
    this.loading = true;
    try {
      const pref = PreferenceManager.getInstance();
      this.enableAmapRouteApi = await pref.isAmapRouteApiEnabled();
    } finally {
      this.loading = false;
    }
  }

  private async onAmapRouteApiChanged(value: boolean): Promise<void> {
    const oldValue = this.enableAmapRouteApi;
    this.enableAmapRouteApi = value;
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setAmapRouteApiEnabled(value);
      this.enableAmapRouteApi = await pref.isAmapRouteApiEnabled();
      this.safeShowToast(this.enableAmapRouteApi ? '已开启高德路线 API' : '已关闭高德路线 API');
    } catch (_error) {
      this.enableAmapRouteApi = oldValue;
      this.safeShowToast('高德路线 API 设置失败');
    }
  }

  build() {
    Column({ space: 10 }) {
      SettingsSubPageHeader({ title: '隐私与权限' });

      SettingSwitchItem({
        title: '允许调用高德路线 API',
        desc: '关闭后不再请求路线规划，可降低外部服务调用。',
        loading: this.loading,
        checked: this.enableAmapRouteApi,
        textPrimary: this.getThemePalette().textPrimary,
        textSecondary: this.getThemePalette().textSecondary,
        cardBg: this.getThemePalette().cardBg,
        onToggle: async (value: boolean) => {
          await this.onAmapRouteApiChanged(value);
        }
      });

      Blank().layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, bottom: 20 })
    .backgroundColor(this.getThemePalette().pageBg);
  }
}
