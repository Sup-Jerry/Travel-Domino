import { common } from '@kit.AbilityKit';
import { LoginStatus } from '../domain/auth/AuthTypes';
import { AppStartupCoordinator } from '../infrastructure/auth/AppStartupCoordinator';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';

@Entry
@Component
struct AuthGatePage {
  @State private checking: boolean = true;
  private checkingInProgress: boolean = false;
  private readonly startupCoordinator: AppStartupCoordinator = AppStartupCoordinator.getInstance();
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private async replaceUrl(url: string): Promise<void> {
    await this.getUIContext().getRouter().replaceUrl({ url: url });
  }

  onPageShow(): void {
    if (this.checkingInProgress) {
      return;
    }
    this.checkingInProgress = true;
    this.checking = true;
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    void this.checkAndRoute().finally(() => {
      this.checkingInProgress = false;
      this.checking = false;
    });
  }

  private async checkAndRoute(): Promise<void> {
    try {
      const startup = await this.startupCoordinator.checkStartupAuth();
      if (startup.success && startup.status === LoginStatus.AUTHENTICATED) {
        await this.replaceUrl('pages/PlanListPage');
        return;
      }
      await this.replaceUrl('pages/LoginPage');
    } catch (_error) {
      await this.authFacade.logout();
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
