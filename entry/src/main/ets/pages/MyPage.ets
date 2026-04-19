import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HuaweiCredential } from '../domain/auth/AuthTypes';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { SessionManager } from '../infrastructure/auth/SessionManager';
import { HuaweiAccountLoginButton } from './components/auth/HuaweiAccountLoginButton';
import { AvatarService } from '../infrastructure/avatar/AvatarService';
import { ProfileViewModel, ProfileViewState } from '../viewmodel/ProfileViewModel';

const DEFAULT_USER_NAME = '游客用户';
const MY_PAGE_USERNAME_PATTERN: RegExp = /^[\u4E00-\u9FFFa-zA-Z0-9_ ]+$/;
const MY_PAGE_LIGHT_HINT_DEDUP_MS = 12000;

export interface MyPageLightHintPayload {
  key: string;
  message: string;
}

export function resolveMyPageAgreementRequiredToast(): string {
  return '请先勾选《用户协议》和《隐私政策》';
}

export function normalizeMyPageUsername(rawValue: string, maxLength: number = 32): string {
  const normalized = rawValue.trim();
  if (!normalized || normalized.length > maxLength) {
    return '';
  }
  if (!MY_PAGE_USERNAME_PATTERN.test(normalized)) {
    return '';
  }
  return normalized;
}

export function normalizeMyPageLightHintKey(key: string): string {
  return String(key || '').trim();
}

export function shouldMyPageEmitLightHint(
  lastLightHintKey: string,
  lastLightHintAt: number,
  nextKey: string,
  now: number,
  dedupMs: number = MY_PAGE_LIGHT_HINT_DEDUP_MS
): boolean {
  const safeKey = normalizeMyPageLightHintKey(nextKey);
  if (!safeKey) {
    return false;
  }
  return !(lastLightHintKey === safeKey && (now - lastLightHintAt) < dedupMs);
}

export function resolveMyPageProfileBootstrapHint(
  accountId: string,
  state: ProfileViewState
): MyPageLightHintPayload | null {
  const safeAccountId = String(accountId || '').trim() || 'guest_local';
  if (state === 'offline') {
    return {
      key: `profile_offline:${safeAccountId}`,
      message: '当前为离线缓存资料'
    };
  }
  if (state === 'error') {
    return {
      key: `profile_cloud_fail:${safeAccountId}`,
      message: '云端同步失败，请稍后重试'
    };
  }
  return null;
}

export function resolveMyPageAvatarUpdateToast(uploadState: string): string {
  return String(uploadState || '').trim() === 'SYNCED' ? '头像已更新并同步' : '头像已更新（本地）';
}

export function resolveMyPageAvatarSyncPendingHint(currentUserId: string): MyPageLightHintPayload {
  const safeUserId = String(currentUserId || '').trim() || 'guest_local';
  return {
    key: `avatar_cloud_sync_pending:${safeUserId}`,
    message: '云端同步失败或延迟，稍后将自动重试'
  };
}

export function resolveMyPageRemoteAvatarUrl(
  authAvatarUrl: string,
  cloudAvatarPath: string,
  defaultAvatarPath: string
): string {
  const safeAuthAvatarUrl = String(authAvatarUrl || '').trim();
  const safeCloudAvatarPath = String(cloudAvatarPath || '').trim();
  const safeDefaultAvatarPath = String(defaultAvatarPath || '').trim();
  if (safeCloudAvatarPath.length > 0 && safeCloudAvatarPath !== safeDefaultAvatarPath) {
    return safeCloudAvatarPath;
  }
  return safeAuthAvatarUrl;
}

@Entry
@Component
struct MyPage {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'MyPage';
  private static readonly LIGHT_HINT_DEDUP_MS: number = MY_PAGE_LIGHT_HINT_DEDUP_MS;
  @State userName: string = DEFAULT_USER_NAME;
  @State loadingProfile: boolean = false;
  @State actionLoading: boolean = false;
  @State isGuestUser: boolean = true;
  @State agreementAccepted: boolean = false;
  @State avatarDisplayUri: string = '';
  @State useDefaultAvatar: boolean = false;
  @State avatarBusy: boolean = false;
  @State currentUserId: string = 'guest_local';
  @State currentRemoteAvatarUrl: string = '';
  @State showUsernameEditor: boolean = false;
  @State usernameDraft: string = '';
  @State profileReady: boolean = false;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();
  private avatarService: AvatarService | null = null;
  private lastLightHintKey: string = '';
  private lastLightHintAt: number = 0;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private ensureAgreement(): boolean {
    if (!this.agreementAccepted) {
      this.toast(resolveMyPageAgreementRequiredToast());
      return false;
    }
    return true;
  }

  aboutToAppear(): void {
    this.profileReady = false;
    void this.refreshUserState();
  }

  private async refreshUserState(): Promise<void> {
    if (this.loadingProfile) {
      return;
    }
    const quickSession = SessionManager.getInstance().load();
    hilog.info(
      MyPage.LOG_DOMAIN,
      MyPage.LOG_TAG,
      `[PROFILE_TRACE][page] refresh_start hasSession=${quickSession ? 1 : 0} sessionGuest=${quickSession?.isGuest ? 1 : 0}`
    );
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    const profileViewModel = ProfileViewModel.getInstance();
    profileViewModel.bindContext(hostContext);
    if (!this.avatarService) {
      this.avatarService = AvatarService.createDefault(hostContext);
    }
    this.loadingProfile = true;
    try {
      const profile = await this.authFacade.getCurrentUserProfile(DEFAULT_USER_NAME);
      const sessionAccountId = SessionManager.getInstance().getCurrentAccountId();
      this.isGuestUser = profile.isGuest;
      this.userName = profile.nickname;
      this.currentUserId = sessionAccountId || profile.accountId || profile.userId || 'guest_local';
      this.currentRemoteAvatarUrl = profile.avatarUrl;
      this.useDefaultAvatar = false;

      const accountId = String(sessionAccountId || profile.accountId || '').trim();
      if (!profile.isGuest && accountId.length > 0) {
        const cloudProfile = await profileViewModel.bootstrap(accountId);
        this.showProfileBootstrapHint(accountId, profileViewModel.getState());
        if (cloudProfile) {
          this.userName = cloudProfile.username || this.userName;
          this.currentUserId = cloudProfile.accountId;
          this.currentRemoteAvatarUrl = resolveMyPageRemoteAvatarUrl(
            profile.avatarUrl,
            cloudProfile.avatarPath,
            ProfileViewModel.DEFAULT_AVATAR_PATH
          );
          if (cloudProfile.avatarPath === ProfileViewModel.DEFAULT_AVATAR_PATH && !this.currentRemoteAvatarUrl) {
            this.useDefaultAvatar = true;
            this.avatarDisplayUri = '';
            return;
          }
          if (this.avatarService) {
            const avatarProfile = await this.avatarService.loadAvatarProfile(cloudProfile.accountId, this.currentRemoteAvatarUrl);
            this.avatarDisplayUri = this.avatarService.resolveDisplayUri(avatarProfile);
            this.useDefaultAvatar = false;
            return;
          }
        }
      }

      if (this.avatarService) {
        const avatarProfile = await this.avatarService.loadAvatarProfile(this.currentUserId, this.currentRemoteAvatarUrl);
        this.avatarDisplayUri = this.avatarService.resolveDisplayUri(avatarProfile);
      }
    } catch (_error) {
      this.isGuestUser = true;
      this.userName = DEFAULT_USER_NAME;
      this.currentUserId = 'guest_local';
      this.currentRemoteAvatarUrl = '';
      this.avatarDisplayUri = '';
      this.useDefaultAvatar = false;
    } finally {
      this.loadingProfile = false;
      this.profileReady = true;
      hilog.info(
        MyPage.LOG_DOMAIN,
        MyPage.LOG_TAG,
        `[PROFILE_TRACE][page] refresh_done ready=1 isGuest=${this.isGuestUser ? 1 : 0} userId=${this.currentUserId}`
      );
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
      this.useDefaultAvatar = false;
      this.toast(resolveMyPageAvatarUpdateToast(profile.uploadState));
      if (profile.uploadState !== 'SYNCED') {
        const hint = resolveMyPageAvatarSyncPendingHint(this.currentUserId);
        this.toastLightHintOnce(hint.key, hint.message);
      }
    } catch (_error) {
      this.toast('头像选择失败，请稍后重试');
    } finally {
      this.avatarBusy = false;
    }
  }

  private showProfileBootstrapHint(accountId: string, state: ProfileViewState): void {
    const hint = resolveMyPageProfileBootstrapHint(accountId, state);
    if (hint) {
      this.toastLightHintOnce(hint.key, hint.message);
    }
  }

  private toastLightHintOnce(key: string, message: string): void {
    const safeKey = normalizeMyPageLightHintKey(key);
    if (!safeKey || !message) {
      return;
    }
    const now = Date.now();
    if (!shouldMyPageEmitLightHint(this.lastLightHintKey, this.lastLightHintAt, safeKey, now, MyPage.LIGHT_HINT_DEDUP_MS)) {
      return;
    }
    this.lastLightHintKey = safeKey;
    this.lastLightHintAt = now;
    this.toast(message);
    hilog.info(MyPage.LOG_DOMAIN, MyPage.LOG_TAG, `[PROFILE_TRACE][page] light_hint key=${safeKey}`);
  }

  private async doLogoutFromMyPage(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.actionLoading = true;
    try {
      await this.authFacade.logout();
      ProfileViewModel.getInstance().reset();
      this.avatarDisplayUri = '';
      this.currentRemoteAvatarUrl = '';
      this.useDefaultAvatar = false;
      this.toast('已退出登录');
      await this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
    } finally {
      this.actionLoading = false;
    }
  }

  private normalizeAndValidateUsername(rawValue: string): string {
    return normalizeMyPageUsername(rawValue, 32);
  }

  private openUsernameEditor(): void {
    this.usernameDraft = this.userName;
    this.showUsernameEditor = true;
  }

  private async saveUsername(): Promise<void> {
    if (this.actionLoading || this.loadingProfile || this.isGuestUser) {
      return;
    }
    const username = this.normalizeAndValidateUsername(this.usernameDraft);
    if (!username) {
      this.toast('用户名仅支持中英文、数字、下划线和空格，长度 1-32');
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.actionLoading = true;
    const result = await this.authFacade.updateUsername(username);
    this.actionLoading = false;
    if (!result.success || !result.data) {
      this.toast(`修改用户名失败：${result.message}`);
      return;
    }
    const accountId = String(this.currentUserId || '').trim();
    if (accountId.length > 0) {
      const profileViewModel = ProfileViewModel.getInstance();
      profileViewModel.bindContext(hostContext);
      void profileViewModel.updateUsername(accountId, username);
    }
    this.userName = result.data.nickname || DEFAULT_USER_NAME;
    this.showUsernameEditor = false;
    this.toast('用户名已更新');
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

            if (this.useDefaultAvatar) {
              Image($r('app.media.headphoto'))
                .width(84)
                .height(84)
                .borderRadius(42)
                .objectFit(ImageFit.Cover);
            } else if (this.avatarDisplayUri) {
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

          if (!this.isGuestUser) {
            Button(this.showUsernameEditor ? '取消修改' : '修改用户名')
              .height(32)
              .padding({ left: 14, right: 14 })
              .borderRadius(16)
              .backgroundColor(this.getThemePalette().cardBgSoft)
              .fontColor(this.getThemePalette().textPrimary)
              .fontSize(12)
              .onClick(() => {
                if (this.showUsernameEditor) {
                  this.showUsernameEditor = false;
                  return;
                }
                this.openUsernameEditor();
              });
          }

          if (this.showUsernameEditor && !this.isGuestUser) {
            Column({ space: 8 }) {
              TextInput({ text: this.usernameDraft, placeholder: '输入新用户名（1-32）' })
                .maxLength(32)
                .onChange((value: string) => {
                  this.usernameDraft = value;
                })
                .height(40)
                .width('100%')
                .backgroundColor(this.getThemePalette().cardBgSoft)
                .borderRadius(10)
                .padding({ left: 10, right: 10 });

              Button(this.actionLoading ? '保存中...' : '保存用户名')
                .width('100%')
                .height(38)
                .backgroundColor(this.getThemePalette().primary)
                .fontColor(Color.White)
                .borderRadius(10)
                .onClick(() => {
                  void this.saveUsername();
                });
            }
            .width('100%');
          }
        }
        .width('100%')
        .padding({ top: 26, bottom: 26 })
        .backgroundColor(this.getThemePalette().cardBg)
        .borderRadius(14);

        if (this.profileReady && this.isGuestUser) {
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
