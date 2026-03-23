import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AuthLoginResult, AuthSessionPayload, DeviceInfo } from '../domain/auth/AuthModels';
import { AuthGateway } from '../infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../infrastructure/auth/AuthSessionStore';

@Entry
@Component
struct LoginPage {
  @State private agreementAccepted: boolean = false;
  @State private loading: boolean = false;

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

  private makeDeviceInfo(): DeviceInfo {
    return new DeviceInfo('device-local', 'HarmonyDevice', 'HARMONY');
  }

  private async replaceUrl(url: string): Promise<void> {
    await this.getUIContext().getRouter().replaceUrl({ url: url });
  }

  private saveSession(session: AuthSessionPayload): void {
    const normalized = new AuthSessionPayload();
    normalized.accessToken = session.accessToken;
    normalized.refreshToken = session.refreshToken;
    normalized.expireAt = Number(session.expireAt);
    normalized.sessionId = session.sessionId;
    AuthSessionStore.save(normalized);
  }

  private async loginAsGuest(): Promise<void> {
    if (!this.ensureAgreement()) {
      return;
    }
    this.loading = true;
    const result = await AuthGateway.createGuest(this.makeDeviceInfo());
    this.loading = false;
    if (result.code !== 0) {
      this.toast(`游客登录失败：${result.message}`);
      return;
    }

    const payload = result.data as AuthLoginResult;
    this.saveSession(payload.session);
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    await AuthSessionStore.markGuestChosenPersisted(hostContext);
    this.toast('已进入游客模式');
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

        Text('当前仅支持游客模式')
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

        Button('进入游客模式')
          .width('100%')
          .height(48)
          .enabled(!this.loading)
          .backgroundColor('#2563EB')
          .fontColor('#FFFFFF')
          .fontSize(16)
          .borderRadius(14)
          .onClick(() => {
            void this.loginAsGuest();
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

      Text('游客模式可直接开始规划行程')
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
