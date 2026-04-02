import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HuaweiCredential } from '../domain/auth/AuthTypes';
import { AvatarProfile } from '../domain/auth/AvatarModels';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { SessionManager } from '../infrastructure/auth/SessionManager';
import { HuaweiAccountLoginButton } from './components/auth/HuaweiAccountLoginButton';
import { AvatarService } from '../infrastructure/avatar/AvatarService';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { AvatarStorageService } from '../infrastructure/storage/AvatarStorageService';

const DEFAULT_USER_NAME = '\u6e38\u5ba2\u7528\u6237';

@Entry
@Component
struct MyPage {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'MyPage';
  private static readonly USERNAME_PATTERN: RegExp = /^[\u4E00-\u9FFFa-zA-Z0-9_ ]+$/;

  @State userName: string = DEFAULT_USER_NAME;
  @State loadingProfile: boolean = false;
  @State actionLoading: boolean = false;
  @State isGuestUser: boolean = true;
  @State agreementAccepted: boolean = false;
  @State avatarDisplayUri: string = '';
  @State useDefaultAvatar: boolean = false;
  @State avatarBusy: boolean = false;
  @State currentAccountId: string = '';
  @State currentUserId: string = 'guest_local';
  @State currentRemoteAvatarUrl: string = '';
  @State showUsernameEditor: boolean = false;
  @State usernameDraft: string = '';
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private readonly authFacade: AuthFacade = AuthFacade.getInstance();
  private avatarService: AvatarService | null = null;
  private avatarStorageService: AvatarStorageService | null = null;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private ensureAgreement(): boolean {
    if (!this.agreementAccepted) {
      this.toast('\u8bf7\u5148\u52fe\u9009\u300a\u7528\u6237\u534f\u8bae\u300b\u548c\u300a\u9690\u79c1\u653f\u7b56\u300b');
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
    const profileViewModel = ProfileViewModel.getInstance();
    profileViewModel.bindContext(hostContext);
    this.ensureAvatarDependency(hostContext);

    this.loadingProfile = true;
    try {
      const profile = await this.authFacade.getCurrentUserProfile(DEFAULT_USER_NAME);
      const sessionAccountId = SessionManager.getInstance().getCurrentAccountId();
      const resolvedAccountId = String(sessionAccountId || profile.accountId || '').trim();
      this.isGuestUser = profile.isGuest;
      this.userName = profile.nickname;
      this.currentAccountId = resolvedAccountId;
      this.currentUserId = resolvedAccountId || profile.userId || 'guest_local';
      this.currentRemoteAvatarUrl = profile.avatarUrl;
      this.useDefaultAvatar = false;

      const accountId = resolvedAccountId;
      if (!profile.isGuest && accountId.length > 0) {
        const cloudProfile = await profileViewModel.bootstrap(accountId);
        if (cloudProfile) {
          this.userName = cloudProfile.username || this.userName;
          this.currentAccountId = cloudProfile.accountId;
          this.currentUserId = cloudProfile.accountId;
          this.currentRemoteAvatarUrl = await this.resolveCloudAvatarUri(cloudProfile.avatarPath);
          if (cloudProfile.avatarPath === ProfileViewModel.DEFAULT_AVATAR_PATH) {
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
      this.currentAccountId = '';
      this.currentUserId = 'guest_local';
      this.currentRemoteAvatarUrl = '';
      this.avatarDisplayUri = '';
      this.useDefaultAvatar = false;
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
    this.ensureAvatarDependency(hostContext);
    if (!this.avatarService) {
      return;
    }
    hilog.info(
      MyPage.LOG_DOMAIN,
      MyPage.LOG_TAG,
      `[PROFILE_TRACE][page] pick avatar start accountId=${String(this.currentAccountId || this.currentUserId || '').trim()}, isGuest=${this.isGuestUser ? 1 : 0}`
    );

    this.avatarBusy = true;
    try {
      const uploadAccountId = String(this.currentAccountId || this.currentUserId || '').trim();
      const profile = await this.avatarService.pickAndSaveAvatar(
        hostContext,
        uploadAccountId,
        this.currentRemoteAvatarUrl,
        {
          waitForUpload: false,
          onUploadSynced: async (syncedProfile: AvatarProfile) => {
            await this.syncCloudAvatarProfile(hostContext, uploadAccountId, syncedProfile);
          }
        }
      );
      if (!profile) {
        hilog.info(MyPage.LOG_DOMAIN, MyPage.LOG_TAG, '[PROFILE_TRACE][page] pick avatar canceled by user');
        this.toast('\u5df2\u53d6\u6d88\u9009\u62e9\u5934\u50cf');
        return;
      }
      this.avatarDisplayUri = this.avatarService.resolveDisplayUri(profile);
      if (profile.cloudUrl) {
        this.currentRemoteAvatarUrl = profile.cloudUrl;
      }
      this.useDefaultAvatar = false;
      hilog.info(
        MyPage.LOG_DOMAIN,
        MyPage.LOG_TAG,
        `[PROFILE_TRACE][page] pick avatar result accountId=${uploadAccountId}, uploadState=${profile.uploadState}, cloudPath=${profile.cloudPath || 'empty'}, version=${profile.avatarVersion}`
      );
      this.toast('\u5934\u50cf\u5df2\u66f4\u65b0\uff08\u672c\u5730\uff09');
      hilog.info(
        MyPage.LOG_DOMAIN,
        MyPage.LOG_TAG,
        `[PROFILE_TRACE][page] local avatar updated accountId=${uploadAccountId}, waitCloudSync=1`
      );
    } catch (error) {
      const reason = error instanceof Error ? (error.message || 'pick_avatar_failed') : 'pick_avatar_failed';
      hilog.error(MyPage.LOG_DOMAIN, MyPage.LOG_TAG, `[PROFILE_TRACE][page] pick avatar failed reason=${reason}`);
      this.toast('\u5934\u50cf\u9009\u62e9\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5');
    } finally {
      this.avatarBusy = false;
    }
  }

  private async syncCloudAvatarProfile(hostContext: common.Context, accountId: string, profile: AvatarProfile): Promise<void> {
    const safeAccountId = String(accountId || '').trim();
    if (this.isGuestUser || !safeAccountId) {
      hilog.warn(
        MyPage.LOG_DOMAIN,
        MyPage.LOG_TAG,
        `[PROFILE_TRACE][page] cloud sync skipped accountId=${safeAccountId || 'empty'}, isGuest=${this.isGuestUser ? 1 : 0}, reason=guest_or_empty`
      );
      return;
    }
    if (!profile.cloudPath || Number(profile.avatarVersion) <= 0) {
      hilog.warn(
        MyPage.LOG_DOMAIN,
        MyPage.LOG_TAG,
        `[PROFILE_TRACE][page] cloud sync skipped accountId=${safeAccountId}, reason=cloud_payload_incomplete, cloudPath=${profile.cloudPath || 'empty'}, version=${Number(profile.avatarVersion || 0)}`
      );
      return;
    }

    hilog.info(
      MyPage.LOG_DOMAIN,
      MyPage.LOG_TAG,
      `[PROFILE_TRACE][page] cloud profile avatar updating accountId=${safeAccountId}, avatarPath=${profile.cloudPath}, version=${profile.avatarVersion}`
    );
    const profileViewModel = ProfileViewModel.getInstance();
    profileViewModel.bindContext(hostContext);
    const updatedProfile = await profileViewModel.updateAvatar(safeAccountId, profile.cloudPath, profile.avatarVersion);
    if (!updatedProfile) {
      hilog.warn(
        MyPage.LOG_DOMAIN,
        MyPage.LOG_TAG,
        `[PROFILE_TRACE][page] cloud profile avatar update skipped accountId=${safeAccountId}, reason=update_avatar_return_null`
      );
      return;
    }

    this.currentRemoteAvatarUrl = await this.resolveCloudAvatarUri(updatedProfile.avatarPath);
    hilog.info(
      MyPage.LOG_DOMAIN,
      MyPage.LOG_TAG,
      `[PROFILE_TRACE][page] cloud profile avatar updated accountId=${safeAccountId}, avatarPath=${updatedProfile.avatarPath}, version=${updatedProfile.avatarVersion}`
    );
    this.toast('\u5934\u50cf\u5df2\u540c\u6b65');
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
      this.toast('\u5df2\u9000\u51fa\u767b\u5f55');
      await this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
    } finally {
      this.actionLoading = false;
    }
  }

  private normalizeAndValidateUsername(rawValue: string): string {
    const normalized = rawValue.trim();
    if (!normalized || normalized.length < 2 || normalized.length > 20) {
      return '';
    }
    if (!MyPage.USERNAME_PATTERN.test(normalized)) {
      return '';
    }
    return normalized;
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
      this.toast('\u7528\u6237\u540d\u4ec5\u652f\u6301\u4e2d\u82f1\u6587\u3001\u6570\u5b57\u3001\u4e0b\u5212\u7ebf\u548c\u7a7a\u683c\uff0c\u957f\u5ea6 2-20');
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.actionLoading = true;
    const result = await this.authFacade.updateUsername(username);
    this.actionLoading = false;
    if (!result.success || !result.data) {
      this.toast(`\u4fee\u6539\u7528\u6237\u540d\u5931\u8d25\uff1a${result.message}`);
      return;
    }

    const accountId = String(this.currentAccountId || this.currentUserId || '').trim();
    if (accountId.length > 0) {
      const profileViewModel = ProfileViewModel.getInstance();
      profileViewModel.bindContext(hostContext);
      void profileViewModel.updateUsername(accountId, username);
    }
    this.userName = result.data.nickname || DEFAULT_USER_NAME;
    this.showUsernameEditor = false;
    this.toast('\u7528\u6237\u540d\u5df2\u66f4\u65b0');
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
      this.toast(`\u534e\u4e3a\u767b\u5f55\u5931\u8d25\uff1a${result.message}`);
      return;
    }
    this.toast('\u534e\u4e3a\u767b\u5f55\u6210\u529f');
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
      this.toast(`\u534e\u4e3a\u767b\u5f55\u5931\u8d25\uff1a${result.message}`);
      return;
    }
    this.toast('\u534e\u4e3a\u767b\u5f55\u6210\u529f');
    this.agreementAccepted = true;
    await this.refreshUserState();
  }

  private ensureAvatarDependency(context: common.Context): void {
    if (!this.avatarService) {
      this.avatarService = AvatarService.createDefault(context);
    }
    if (!this.avatarStorageService) {
      this.avatarStorageService = AvatarStorageService.createDefault(context);
    }
  }

  private async resolveCloudAvatarUri(rawAvatarPath: string): Promise<string> {
    const avatarPath = String(rawAvatarPath || '').trim();
    if (!avatarPath || avatarPath === ProfileViewModel.DEFAULT_AVATAR_PATH) {
      return avatarPath;
    }
    if (this.isDirectUri(avatarPath)) {
      return avatarPath;
    }
    if (!this.avatarStorageService) {
      return avatarPath;
    }
    try {
      return await this.avatarStorageService.getDownloadUrl(avatarPath);
    } catch (_error) {
      return avatarPath;
    }
  }

  private isDirectUri(uri: string): boolean {
    return uri.startsWith('http://') || uri.startsWith('https://') || uri.startsWith('file://');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 16 }) {
        Row() {
          Text('\u6211\u7684')
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

            Text(this.avatarBusy ? '\u5904\u7406\u4e2d' : '\u66f4\u6362')
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
            Button(this.showUsernameEditor ? '\u53d6\u6d88\u4fee\u6539' : '\u4fee\u6539\u7528\u6237\u540d')
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
              TextInput({ text: this.usernameDraft, placeholder: '\u8f93\u5165\u65b0\u7528\u6237\u540d\uff082-20\uff09' })
                .maxLength(20)
                .onChange((value: string) => {
                  this.usernameDraft = value;
                })
                .height(40)
                .width('100%')
                .backgroundColor(this.getThemePalette().cardBgSoft)
                .borderRadius(10)
                .padding({ left: 10, right: 10 });

              Button(this.actionLoading ? '\u4fdd\u5b58\u4e2d...' : '\u4fdd\u5b58\u7528\u6237\u540d')
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

        if (this.isGuestUser) {
          Column({ space: 10 }) {
            Text('\u4f7f\u7528\u534e\u4e3a\u767b\u5f55')
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
              Text('\u6211\u5df2\u9605\u8bfb\u5e76\u540c\u610f\u300a\u7528\u6237\u534f\u8bae\u300b\u300a\u9690\u79c1\u653f\u7b56\u300b')
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
                this.toast(`\u534e\u4e3a\u767b\u5f55\u5931\u8d25\uff1a${message}`);
              }
            });
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);
        }

        Button('\u8bbe\u7f6e')
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
          Button('\u9000\u51fa')
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
          Text('\u5904\u7406\u4e2d\uff0c\u8bf7\u7a0d\u5019...')
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


