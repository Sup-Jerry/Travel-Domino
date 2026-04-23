import { hilog } from '@kit.PerformanceAnalysisKit';
import { LoginStatus } from '../domain/auth/AuthTypes';
import { AppStartupCoordinator } from '../infrastructure/auth/AppStartupCoordinator';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';

export function shouldAuthGateRouteToPlanList(success: boolean, status: LoginStatus): boolean {
  return success && status === LoginStatus.AUTHENTICATED;
}

export function resolveAuthGateTargetUrl(success: boolean, status: LoginStatus): string {
  return shouldAuthGateRouteToPlanList(success, status) ? 'pages/PlanListPage' : 'pages/LoginPage';
}

export function resolveAuthGateCheckingText(checking: boolean): string {
  return checking ? '正在检查登录状态...' : '正在跳转...';
}

@Entry
@Component
struct AuthGatePage {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'AuthGatePage';
  @State private checking: boolean = true;
  private checkingInProgress: boolean = false;
  private readonly startupCoordinator: AppStartupCoordinator = AppStartupCoordinator.getInstance();
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private async replaceUrl(url: string): Promise<void> {
    try {
      await this.getUIContext().getRouter().replaceUrl({ url: url });
    } catch (error) {
      hilog.error(AuthGatePage.LOG_DOMAIN, AuthGatePage.LOG_TAG, `replaceUrl failed: ${JSON.stringify(error)}`);
    }
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

  private async checkAndRoute(): Promise<void> {
    try {
      hilog.info(AuthGatePage.LOG_DOMAIN, AuthGatePage.LOG_TAG, '[LOGIN_TRACE][gate] checkAndRoute start');
      const startup = await this.startupCoordinator.checkStartupAuth();
      const target = resolveAuthGateTargetUrl(startup.success, startup.status);
      if (shouldAuthGateRouteToPlanList(startup.success, startup.status)) {
        const accountId = String(startup.data?.accountId || '').trim();
        hilog.info(
          AuthGatePage.LOG_DOMAIN,
          AuthGatePage.LOG_TAG,
          `[LOGIN_TRACE][gate] authenticated route accountId=${accountId}, source=${startup.source}, message=${startup.message}, target=${target}`
        );
        await this.replaceUrl(target);
        return;
      }
      hilog.info(
        AuthGatePage.LOG_DOMAIN,
        AuthGatePage.LOG_TAG,
        `[LOGIN_TRACE][gate] unauthenticated route code=${startup.code}, source=${startup.source}, message=${startup.message}, target=${target}`
      );
      await this.replaceUrl(target);
    } catch (_error) {
      hilog.error(AuthGatePage.LOG_DOMAIN, AuthGatePage.LOG_TAG, '[LOGIN_TRACE][gate] checkAndRoute exception fallback_to_login');
      await this.authFacade.logout();
      await this.replaceUrl('pages/LoginPage');
    }
  }

  build() {
    Column() {
      Blank().layoutWeight(1)
      Text(resolveAuthGateCheckingText(this.checking))
        .fontSize(16)
      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

export function createAuthGatePageForTest(): Object {
  return new AuthGatePage(undefined, {} as LocalStorage);
}
