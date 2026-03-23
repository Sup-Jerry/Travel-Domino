import { AuthLoginResult, DeviceInfo } from '../domain/auth/AuthModels';
import { AuthGateway } from '../infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../infrastructure/auth/AuthSessionStore';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct AuthGatePage {
  @State private checking: boolean = true;
  private checkingInProgress: boolean = false;

  private makeDeviceInfo(): DeviceInfo {
    return new DeviceInfo('device-local', 'HarmonyDevice', 'HARMONY');
  }

  private async replaceUrl(url: string): Promise<void> {
    await this.getUIContext().getRouter().replaceUrl({ url: url });
  }

  onPageShow(): void {
    if (this.checkingInProgress) {
      return;
    }
    this.checkingInProgress = true;
    this.checking = true;
    void this.checkAndRoute().finally(() => {
      this.checkingInProgress = false;
      this.checking = false;
    });
  }

  private async trySilentGuestLogin(): Promise<boolean> {
    const result = await AuthGateway.createGuest(this.makeDeviceInfo());
    if (result.code !== 0) {
      return false;
    }
    const payload = result.data as AuthLoginResult;
    AuthSessionStore.save(payload.session);
    AuthSessionStore.markGuestChosen();
    return true;
  }

  private async checkAndRoute(): Promise<void> {
    try {
      const session = AuthSessionStore.load();
      if (session && Date.now() < session.expireAt) {
        const me = await AuthGateway.me(session.accessToken);
        if (me.code === 0) {
          await this.replaceUrl('pages/PlanListPage');
          return;
        }
        AuthSessionStore.clear();
      }

      const hostContext = this.getUIContext().getHostContext() as common.Context;
      const hasGuestChosen = await AuthSessionStore.hasGuestChosenPersisted(hostContext);
      if (hasGuestChosen) {
        const autoGuestOk = await this.trySilentGuestLogin();
        if (autoGuestOk) {
          await this.replaceUrl('pages/PlanListPage');
          return;
        }
      }

      await this.replaceUrl('pages/LoginPage');
    } catch (_error) {
      AuthSessionStore.clear();
      await this.replaceUrl('pages/LoginPage');
    }
  }

  build() {
    Column() {
      Blank().layoutWeight(1)
      Text(this.checking ? '正在检查登录状态...' : '正在跳转...')
        .fontSize(16)
      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
