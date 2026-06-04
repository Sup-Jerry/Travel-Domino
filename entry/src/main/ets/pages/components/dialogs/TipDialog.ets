// 文件路径: ets/pages/components/TipDialog.ets
import { PreferenceManager } from '../../../common/utils/PreferenceManager'; // 修改点：引入管理器

type TipDialogVoidAction = () => void;

export function toggleTipDialogChecked(current: boolean): boolean {
  return !current;
}

export function shouldPersistTipDialogChoice(isChecked: boolean): boolean {
  return isChecked;
}

export async function confirmTipDialog(
  isChecked: boolean,
  storageKey: string,
  onConfirm: () => void,
  close: () => void,
  persistChoice: (key: string, value: boolean) => Promise<void>
): Promise<boolean> {
  if (shouldPersistTipDialogChoice(isChecked)) {
    await persistChoice(storageKey, true);
  }
  onConfirm();
  close();
  return true;
}

@CustomDialog
export struct TipDialog {
  controller: CustomDialogController;
  title: string = '';
  message: string = '';
  storageKey: string = ''; // 对应的持久化 Key
  onConfirm: TipDialogVoidAction = () => {};

  @State isChecked: boolean = false;

  build() {
    Column() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 12 })
      Text(this.message).fontSize(16).fontColor($r('app.color.text_secondary')).margin({ bottom: 20 }).lineHeight(24)

      Row() {
        Checkbox({ name: 'hide', group: 'tip' })
          .select(this.isChecked)
          .onChange((val) => this.isChecked = val)
          .width(20).height(20)
        Text('从此以后不再提示').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ left: 8 })
          .onClick(() => this.isChecked = toggleTipDialogChecked(this.isChecked))
      }
      .width('100%').margin({ bottom: 20 })

      Row() {
        Button('取消')
          .backgroundColor($r('app.color.card_bg')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
          .onClick(() => this.controller.close())

        Button('确定')
          .backgroundColor($r('app.color.accent_primary')).fontColor(Color.White).layoutWeight(1).margin({ left: 12 })
          .onClick(async () => { // 修改点：异步回调
            await confirmTipDialog(
              this.isChecked,
              this.storageKey,
              this.onConfirm,
              (): void => this.controller.close(),
              async (key: string, value: boolean): Promise<void> => {
                await PreferenceManager.getInstance().setValue(key, value);
              }
            );
          })
      }.width('100%')
    }
    .padding(24).backgroundColor($r('app.color.card_bg')).borderRadius(16).width('90%')
  }
}









