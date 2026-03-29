import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { HuaweiCredential } from '../domain/auth/AuthTypes';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { HuaweiAccountLoginButton } from './components/auth/HuaweiAccountLoginButton';

@Entry
@Component
struct LoginPage {
  @State private agreementAccepted: boolean = false;
  @State private loading: boolean = false;
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private ensureAgreement(): boolean {
    if (!this.agreementAccepted) {
      this.toast('请先勾选用户协议与隐私政策');
      return false;
    }
    return true;
  }

  private async replaceUrl(url: string): Promise<void> {
    await this.getUIContext().getRouter().replaceUrl({ url: url });
  }

  private async loginWithHuaweiButton(credential: HuaweiCredential): Promise<void> {
    if (!this.ensureAgreement()) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.loading = true;
    const result = await this.authFacade.explicitLoginByButton(credential);
    this.loading = false;
    if (!result.success) {
      this.toast(`登录失败：${result.message}`);
      return;
    }
    this.toast('登录成功');
    await this.replaceUrl('pages/PlanListPage');
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Text('Travel Domino')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
        Text('智能行程规划，从登录开始')
          .fontSize(14)
          .fontColor('#6B7280')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 24, bottom: 22 })

      Column({ space: 14 }) {
        Text('账号登录')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .width('100%')
          .textAlign(TextAlign.Start)

        Text('优先使用华为账号登录')
          .fontSize(13)
          .fontColor('#6B7280')
          .width('100%')
          .textAlign(TextAlign.Start)

        Row({ space: 8 }) {
          Checkbox()
            .select(this.agreementAccepted)
            .onChange((value: boolean) => {
              this.agreementAccepted = value;
            })
          Text('我已阅读并同意《用户协议》《隐私政策》')
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .width('100%')
        .margin({ top: 2, bottom: 6 })

        HuaweiAccountLoginButton({
          agreementAccepted: this.agreementAccepted,
          onCredential: (credential: HuaweiCredential) => {
            void this.loginWithHuaweiButton(credential);
          },
          onError: (message: string) => {
            this.toast(`华为账号登录失败：${message}`);
          }
        })

        if (this.loading) {
          Text('处理中，请稍候...')
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 22, bottom: 22 })
      .backgroundColor('#FFFFFF')
      .borderRadius(22)

      Blank().layoutWeight(1)

      Text('华为登录失败时将自动切换游客模式')
        .fontSize(12)
        .fontColor('#9CA3AF')
        .margin({ bottom: 12 })
    }
    .padding({ left: 24, right: 24, top: 8, bottom: 12 })
    .backgroundColor('#F5F7FB')
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
