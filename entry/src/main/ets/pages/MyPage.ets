import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HuaweiCredential } from '../domain/auth/AuthTypes';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { HuaweiAccountLoginButton } from './components/auth/HuaweiAccountLoginButton';
import { AvatarService } from '../infrastructure/avatar/AvatarService';

const DEFAULT_USER_NAME = '游客用户';

@Entry
@Component
struct MyPage {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'MyPage';
  @State userName: string = DEFAULT_USER_NAME;
  @State loadingProfile: boolean = false;
  @State actionLoading: boolean = false;
  @State isGuestUser: boolean = true;
  @State agreementAccepted: boolean = false;
  @State avatarDisplayUri: string = '';
  @State avatarBusy: boolean = false;
  @State currentUserId: string = 'guest_local';
  @State currentRemoteAvatarUrl: string = '';
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();
  private avatarService: AvatarService | null = null;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private ensureAgreement(): boolean {
    if (!this.agreementAccepted) {
      this.toast('请先勾选《用户协议》和《隐私政策》');
      return false;
    }
    return true;
  }

  aboutToAppear(): void {
    void this.refreshUserState();
  }

  private async refreshUserState(): Promise<void> {
    if (this.loadingProfile) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    if (!this.avatarService) {
      this.avatarService = AvatarService.createDefault(hostContext);
    }
    this.loadingProfile = true;
    try {
      const profile = await this.authFacade.getCurrentUserProfile(DEFAULT_USER_NAME);
      this.isGuestUser = profile.isGuest;
      this.userName = profile.nickname;
      this.currentUserId = profile.userId;
      this.currentRemoteAvatarUrl = profile.avatarUrl;
      if (this.avatarService) {
        const avatarProfile = await this.avatarService.loadAvatarProfile(profile.userId, profile.avatarUrl);
        this.avatarDisplayUri = this.avatarService.resolveDisplayUri(avatarProfile);
      }
    } catch (_error) {
      this.isGuestUser = true;
      this.userName = DEFAULT_USER_NAME;
      this.currentUserId = 'guest_local';
      this.currentRemoteAvatarUrl = '';
      this.avatarDisplayUri = '';
    } finally {
      this.loadingProfile = false;
    }
  }

  private async pickAvatarFromGallery(): Promise<void> {
    if (this.avatarBusy || this.loadingProfile || this.actionLoading) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    if (!this.avatarService) {
      this.avatarService = AvatarService.createDefault(hostContext);
    }
    if (!this.avatarService) {
      return;
    }

    this.avatarBusy = true;
    try {
      const profile = await this.avatarService.pickAndSaveAvatar(hostContext, this.currentUserId, this.currentRemoteAvatarUrl);
      if (!profile) {
        this.toast('已取消选择头像');
        return;
      }
      this.avatarDisplayUri = this.avatarService.resolveDisplayUri(profile);
      this.currentRemoteAvatarUrl = profile.cloudUrl;
      this.toast('头像已更新（本地）');
    } catch (_error) {
      this.toast('头像选择失败，请稍后重试');
    } finally {
      this.avatarBusy = false;
    }
  }

  private async doLogoutFromMyPage(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.actionLoading = true;
    try {
      await this.authFacade.logout();
      this.avatarDisplayUri = '';
      this.currentRemoteAvatarUrl = '';
      this.toast('已退出登录');
      await this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
    } finally {
      this.actionLoading = false;
    }
  }

  private async loginWithHuaweiFromMyPage(credential: HuaweiCredential): Promise<void> {
    if (!this.ensureAgreement()) {
      hilog.warn(MyPage.LOG_DOMAIN, MyPage.LOG_TAG, '[LOGIN_TRACE][my] blocked by agreement');
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.actionLoading = true;
    const result = await this.authFacade.explicitLoginByButton(credential, false);
    this.actionLoading = false;
    if (!result.success) {
      this.toast(`华为登录失败：${result.message}`);
      return;
    }
    this.toast('华为登录成功');
    this.agreementAccepted = true;
    await this.refreshUserState();
  }

  private async loginWithHuaweiApiFallback(): Promise<void> {
    if (!this.ensureAgreement()) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.actionLoading = true;
    const result = await this.authFacade.explicitLoginByButton(undefined, false);
    this.actionLoading = false;
    if (!result.success) {
      this.toast(`华为登录失败：${result.message}`);
      return;
    }
    this.toast('华为登录成功');
    this.agreementAccepted = true;
    await this.refreshUserState();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 16 }) {
        Row() {
          Text('我的')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
        }
        .width('100%')
        .padding({ left: 16, top: 22, right: 16, bottom: 6 });

        Column({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(84)
              .height(84)
              .fill(this.getThemePalette().cardBgSoft);

            if (this.avatarDisplayUri) {
              Image(this.avatarDisplayUri)
                .width(84)
                .height(84)
                .borderRadius(42)
                .objectFit(ImageFit.Cover);
            } else {
              Stack({ alignContent: Alignment.Center }) {
                Circle()
                  .width(32)
                  .height(32)
                  .fill(this.getThemePalette().textTertiary)
                  .margin({ top: -14 });
                Row()
                  .width(44)
                  .height(24)
                  .backgroundColor(this.getThemePalette().textTertiary)
                  .borderRadius(12)
                  .margin({ top: 26 });
              }
              .width(84)
              .height(84);
            }

            Text(this.avatarBusy ? '处理中' : '更换')
              .fontSize(11)
              .fontColor(Color.White)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#00000088')
              .borderRadius(9)
              .margin({ top: 56 });
          }
          .onClick(() => {
            void this.pickAvatarFromGallery();
          });

          Text(this.userName)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getThemePalette().textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .padding({ top: 26, bottom: 26 })
        .backgroundColor(this.getThemePalette().cardBg)
        .borderRadius(14);

        if (this.isGuestUser) {
          Column({ space: 10 }) {
            Text('使用华为登录')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemePalette().textPrimary)
              .width('100%')
              .textAlign(TextAlign.Start);

            Row({ space: 8 }) {
              Checkbox()
                .select(this.agreementAccepted)
                .onChange((value: boolean) => {
                  this.agreementAccepted = value;
                });
              Text('我已阅读并同意《用户协议》《隐私政策》')
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%');

            HuaweiAccountLoginButton({
              agreementAccepted: this.agreementAccepted,
              onCredential: (credential: HuaweiCredential) => {
                void this.loginWithHuaweiFromMyPage(credential);
              },
              onError: (message: string) => {
                const codeText = message.replace('huawei_login_error_', '').split('_')[0];
                const code = Number(codeText);
                if (code === 1001502003) {
                  void this.loginWithHuaweiApiFallback();
                  return;
                }
                this.toast(`华为登录失败：${message}`);
              }
            });
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);
        }

        Button('设置')
          .width('82%')
          .height(48)
          .alignSelf(ItemAlign.Center)
          .borderRadius(12)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .fontSize(16)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
          });

        if (!this.isGuestUser) {
          Button('退出')
            .width('82%')
            .height(46)
            .alignSelf(ItemAlign.Center)
            .borderRadius(12)
            .backgroundColor('#EF4444')
            .fontColor(Color.White)
            .fontSize(16)
            .onClick(() => {
              void this.doLogoutFromMyPage();
            });
        }

        if (this.actionLoading || this.avatarBusy) {
          Text('处理中，请稍候...')
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(12)
            .fontColor(this.getThemePalette().textSecondary);
        }

        Blank()
          .layoutWeight(1);
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 90 })
      .backgroundColor(this.getThemePalette().pageBg);

      GlobalBottomNavBar({
        currentTab: 'profile',
        showCenterFab: false
      })
        .zIndex(9);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}
