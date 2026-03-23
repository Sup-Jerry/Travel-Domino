import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { SettingsSubPageHeader, SettingSwitchItem } from './components/views/SettingsItems';

@Entry
@Component
struct SettingsNotificationPage {
  @State showArchiveTip: boolean = true;
  @State showDeleteTip: boolean = true;
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
      const hideArchiveTip = await pref.getValue(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, false);
      const hideDeleteTip = await pref.getValue(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, false);
      this.showArchiveTip = hideArchiveTip !== true;
      this.showDeleteTip = hideDeleteTip !== true;
    } finally {
      this.loading = false;
    }
  }

  private async onShowArchiveTipChanged(value: boolean): Promise<void> {
    const old = this.showArchiveTip;
    this.showArchiveTip = value;
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setValue(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, !value);
      await this.reload();
      this.safeShowToast(this.showArchiveTip ? '已开启归档提示弹窗' : '已关闭归档提示弹窗');
    } catch (_error) {
      this.showArchiveTip = old;
      this.safeShowToast('归档提示弹窗设置失败');
    }
  }

  private async onShowDeleteTipChanged(value: boolean): Promise<void> {
    const old = this.showDeleteTip;
    this.showDeleteTip = value;
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setValue(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, !value);
      await this.reload();
      this.safeShowToast(this.showDeleteTip ? '已开启删除提示弹窗' : '已关闭删除提示弹窗');
    } catch (_error) {
      this.showDeleteTip = old;
      this.safeShowToast('删除提示弹窗设置失败');
    }
  }

  private async resetAllTips(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setValue(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, false);
      await pref.setValue(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, false);
      await this.reload();
      this.safeShowToast('已恢复所有提示弹窗');
    } catch (_error) {
      this.safeShowToast('恢复提示弹窗失败');
    }
  }

  build() {
    Column({ space: 10 }) {
      SettingsSubPageHeader({ title: '通知与提醒' });

      SettingSwitchItem({
        title: '显示归档提示弹窗',
        desc: '关闭后，归档计划时不再显示说明弹窗。',
        loading: this.loading,
        checked: this.showArchiveTip,
        textPrimary: this.getThemePalette().textPrimary,
        textSecondary: this.getThemePalette().textSecondary,
        cardBg: this.getThemePalette().cardBg,
        onToggle: async (value: boolean) => {
          await this.onShowArchiveTipChanged(value);
        }
      });

      SettingSwitchItem({
        title: '显示删除提示弹窗',
        desc: '关闭后，删除计划时不再显示说明弹窗。',
        loading: this.loading,
        checked: this.showDeleteTip,
        textPrimary: this.getThemePalette().textPrimary,
        textSecondary: this.getThemePalette().textSecondary,
        cardBg: this.getThemePalette().cardBg,
        onToggle: async (value: boolean) => {
          await this.onShowDeleteTipChanged(value);
        }
      });

      Button('恢复所有提示弹窗')
        .width('100%')
        .height(48)
        .borderRadius(12)
        .backgroundColor(this.getThemePalette().cardBg)
        .fontColor(this.getThemePalette().textPrimary)
        .onClick(async () => {
          await this.resetAllTips();
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
