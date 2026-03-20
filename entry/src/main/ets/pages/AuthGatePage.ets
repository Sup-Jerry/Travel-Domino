import { router } from '@kit.ArkUI';
import { AuthGateway } from '../infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../infrastructure/auth/AuthSessionStore';

@Entry
@Component
struct AuthGatePage {
  @State private checking: boolean = true;
  private routed: boolean = false;

  onPageShow(): void {
    if (this.routed) {
      return;
    }
    this.routed = true;
    void this.checkAndRoute();
  }

  private async checkAndRoute(): Promise<void> {
    const session = AuthSessionStore.load();
    if (!session || Date.now() >= session.expireAt) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }

    const me = await AuthGateway.me(session.accessToken);
    if (me.code === 0) {
      router.pushUrl({ url: 'pages/PlanListPage' });
      return;
    }

    AuthSessionStore.clear();
    router.pushUrl({ url: 'pages/LoginPage' });
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
