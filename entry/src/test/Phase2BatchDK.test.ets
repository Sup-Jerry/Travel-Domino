import { describe, it, expect } from '@ohos/hypium';
import { createMyPageForTest } from '../main/ets/pages/MyPage';
import { HuaweiCredential } from '../main/ets/domain/auth/AuthTypes';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { AvatarService } from '../main/ets/infrastructure/avatar/AvatarService';
import { ProfileViewModel } from '../main/ets/viewmodel/ProfileViewModel';

interface MyPagePrivateDK {
  userName: string;
  loadingProfile: boolean;
  actionLoading: boolean;
  isGuestUser: boolean;
  agreementAccepted: boolean;
  avatarDisplayUri: string;
  useDefaultAvatar: boolean;
  avatarBusy: boolean;
  currentUserId: string;
  currentRemoteAvatarUrl: string;
  showUsernameEditor: boolean;
  usernameDraft: string;
  profileReady: boolean;
  authFacade: AuthFacadeMockDK;
  refreshUserState(): Promise<void>;
  ensureAgreement(): boolean;
  pickAvatarFromGallery(): Promise<void>;
  showProfileBootstrapHint(accountId: string, state: string): void;
  toastLightHintOnce(key: string, message: string): void;
  doLogoutFromMyPage(): Promise<void>;
  normalizeAndValidateUsername(rawValue: string): string;
  openUsernameEditor(): void;
  saveUsername(): Promise<void>;
  loginWithHuaweiFromMyPage(credential: HuaweiCredential): Promise<void>;
  loginWithHuaweiApiFallback(): Promise<void>;
}

interface RouterOptionsDK {
  url: string;
}

class RouterMockDK {
  public replacedUrls: string[] = [];

  async replaceUrl(options: RouterOptionsDK): Promise<void> {
    this.replacedUrls.push(options.url);
  }
}

class UiContextMockDK {
  public readonly router: RouterMockDK = new RouterMockDK();
  public readonly hostContext: Object = new Object();

  getHostContext(): Object {
    return this.hostContext;
  }

  getRouter(): RouterMockDK {
    return this.router;
  }
}

class AuthFacadeMockDK {
  public bindCount: number = 0;
  public logoutCount: number = 0;
  public updateUsernameCalls: string[] = [];
  public loginCalls: number = 0;
  public lastCredentialWasUndefined: boolean = false;
  public updateSuccess: boolean = true;
  public loginSuccess: boolean = false;
  public profileThrows: boolean = false;
  public nextProfile: AuthProfileResultDK = new AuthProfileResultDK();

  bindContext(_context: Object): void {
    this.bindCount += 1;
  }

  async logout(): Promise<void> {
    this.logoutCount += 1;
  }

  async updateUsername(username: string): Promise<AuthUpdateResultDK> {
    this.updateUsernameCalls.push(username);
    if (!this.updateSuccess) {
      return {
        success: false,
        message: 'update_failed_dk',
        data: null
      };
    }
    return {
      success: true,
      message: 'ok',
      data: {
        nickname: username
      }
    };
  }

  async explicitLoginByButton(credential: HuaweiCredential | undefined, _silent: boolean): Promise<AuthLoginResultDK> {
    this.loginCalls += 1;
    this.lastCredentialWasUndefined = credential === undefined;
    return {
      success: this.loginSuccess,
      message: this.loginSuccess ? 'ok' : 'login_failed_dk'
    };
  }

  async getCurrentUserProfile(_defaultName: string): Promise<AuthProfileResultDK> {
    if (this.profileThrows) {
      throw new Error('profile_failed_dk');
    }
    return this.nextProfile;
  }
}

class AuthProfileResultDK {
  isGuest: boolean = true;
  nickname: string = 'guest_dk';
  accountId: string = '';
  userId: string = 'guest_local';
  avatarUrl: string = '';
}

interface AuthUpdateDataDK {
  nickname: string;
}

interface AuthUpdateResultDK {
  success: boolean;
  message: string;
  data: AuthUpdateDataDK | null;
}

interface AuthLoginResultDK {
  success: boolean;
  message: string;
}

class AvatarProfileResultDK {
  cloudUrl: string = '';
  uploadState: string = '';
}

interface AvatarServiceLikeDK {
  loadAvatarProfile(userId: string, remoteUrl: string): Promise<AvatarProfileResultDK>;
  pickAndSaveAvatar(hostContext: Object, userId: string, remoteUrl: string): Promise<AvatarProfileResultDK | null>;
  resolveDisplayUri(profile: AvatarProfileResultDK): string;
}

class AvatarServiceMockDK implements AvatarServiceLikeDK {
  public nextProfile: AvatarProfileResultDK | null = null;
  public nextDisplayUri: string = '';
  public loadCalls: string[] = [];

  async loadAvatarProfile(userId: string, remoteUrl: string): Promise<AvatarProfileResultDK> {
    this.loadCalls.push(`${userId}:${remoteUrl}`);
    return this.nextProfile ?? new AvatarProfileResultDK();
  }

  async pickAndSaveAvatar(_hostContext: Object, _userId: string, _remoteUrl: string): Promise<AvatarProfileResultDK | null> {
    return this.nextProfile;
  }

  resolveDisplayUri(_profile: AvatarProfileResultDK): string {
    return this.nextDisplayUri;
  }
}

class ProfileViewModelMockDK {
  public bindCount: number = 0;
  public resetCount: number = 0;
  public updateCalls: string[] = [];
  public bootstrapCalls: string[] = [];
  public nextState: string = 'ready';
  public nextBootstrapProfile: ProfileBootstrapResultDK | null = null;

  bindContext(_context: Object): void {
    this.bindCount += 1;
  }

  reset(): void {
    this.resetCount += 1;
  }

  async updateUsername(accountId: string, username: string): Promise<void> {
    this.updateCalls.push(`${accountId}:${username}`);
  }

  async bootstrap(accountId: string): Promise<ProfileBootstrapResultDK | null> {
    this.bootstrapCalls.push(accountId);
    return this.nextBootstrapProfile;
  }

  getState(): string {
    return this.nextState;
  }
}

class ProfileBootstrapResultDK {
  username: string = '';
  accountId: string = '';
  avatarPath: string = '';
}

class SessionSnapshotDK {
  accountId: string = '';
  userId: string = '';
  isGuest: boolean = false;
}

class SessionManagerMockDK {
  public nextLoad: SessionSnapshotDK | null = null;
  public nextAccountId: string = '';

  load(): SessionSnapshotDK | null {
    return this.nextLoad;
  }

  getCurrentAccountId(): string {
    return this.nextAccountId;
  }
}

class StaticPatchDK {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

function createPageDK(authFacade: AuthFacadeMockDK, uiContext?: UiContextMockDK): MyPagePrivateDK {
  const page = createMyPageForTest() as MyPagePrivateDK;
  Reflect.set(page as Object, 'authFacade', authFacade);
  Reflect.set(page as Object, 'toast', (_message: string): void => {});
  if (uiContext) {
    Reflect.set(page as Object, 'getUIContext', (): UiContextMockDK => uiContext);
  }
  return page;
}

function patchProfileViewModelDK(vm: ProfileViewModelMockDK): StaticPatchDK {
  return new StaticPatchDK(ProfileViewModel as Object, 'getInstance', (): ProfileViewModelMockDK => vm);
}

function patchSessionManagerDK(manager: SessionManagerMockDK): StaticPatchDK {
  return new StaticPatchDK(SessionManager as Object, 'getInstance', (): SessionManagerMockDK => manager);
}

function patchAvatarServiceFactoryDK(service: AvatarServiceMockDK): StaticPatchDK {
  return new StaticPatchDK(AvatarService as Object, 'createDefault', (_context: Object): AvatarServiceMockDK => service);
}

function buildCredentialDK(): HuaweiCredential {
  const credential = new HuaweiCredential();
  credential.openId = 'open_dk';
  credential.unionId = 'union_dk';
  credential.authorizationCode = 'code_dk';
  credential.idToken = '';
  return credential;
}

export default function phase2BatchDKTest() {
  describe('phase2BatchDKTest', () => {
    it('normal: my_page_agreement_guard_should_block_login_until_checked', 0, () => {
      // Arrange
      const page = createPageDK(new AuthFacadeMockDK());
      page.agreementAccepted = false;

      // Act
      const blocked = page.ensureAgreement();
      page.agreementAccepted = true;
      const allowed = page.ensureAgreement();

      // Assert
      expect(blocked).assertFalse();
      expect(allowed).assertTrue();
    });

    it('boundary: my_page_light_hint_should_emit_once_for_same_key_inside_dedup_window', 0, () => {
      // Arrange
      const page = createPageDK(new AuthFacadeMockDK());

      // Act
      page.toastLightHintOnce('profile_cloud_fail:dk', 'cloud failed');
      page.toastLightHintOnce('profile_cloud_fail:dk', 'cloud failed again');
      page.showProfileBootstrapHint('account_dk', 'offline');

      // Assert
      expect(page.profileReady).assertFalse();
    });

    it('invalid: my_page_save_username_should_reject_invalid_or_guest_state_without_remote_call', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const page = createPageDK(auth, new UiContextMockDK());

      // Act
      page.isGuestUser = true;
      page.usernameDraft = 'Guest_1';
      await page.saveUsername();
      page.isGuestUser = false;
      page.usernameDraft = 'bad-name!';
      await page.saveUsername();

      // Assert
      expect(auth.updateUsernameCalls.length).assertEqual(0);
      expect(page.normalizeAndValidateUsername('Valid_Name 1')).assertEqual('Valid_Name 1');
    });

    it('combined: my_page_save_username_should_update_remote_profile_and_close_editor', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const profileVm = new ProfileViewModelMockDK();
      const profilePatch = patchProfileViewModelDK(profileVm);
      const page = createPageDK(auth, new UiContextMockDK());
      page.isGuestUser = false;
      page.currentUserId = 'account_dk';
      page.userName = 'OldName';
      page.openUsernameEditor();
      page.usernameDraft = 'NewName';

      // Act
      await page.saveUsername();
      profilePatch.restore();

      // Assert
      expect(page.actionLoading).assertFalse();
      expect(page.showUsernameEditor).assertFalse();
      expect(page.userName).assertEqual('NewName');
      expect(auth.updateUsernameCalls[0]).assertEqual('NewName');
      expect(profileVm.updateCalls[0]).assertEqual('account_dk:NewName');
    });

    it('regression: my_page_logout_should_reset_profile_state_and_route_to_login', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const uiContext = new UiContextMockDK();
      const profileVm = new ProfileViewModelMockDK();
      const profilePatch = patchProfileViewModelDK(profileVm);
      const page = createPageDK(auth, uiContext);
      page.avatarDisplayUri = 'file://avatar.png';
      page.currentRemoteAvatarUrl = 'https://avatar.example/a.png';
      page.useDefaultAvatar = true;

      // Act
      await page.doLogoutFromMyPage();
      profilePatch.restore();

      // Assert
      expect(page.actionLoading).assertFalse();
      expect(auth.logoutCount).assertEqual(1);
      expect(profileVm.resetCount).assertEqual(1);
      expect(page.avatarDisplayUri).assertEqual('');
      expect(uiContext.router.replacedUrls[0]).assertEqual('pages/LoginPage');
    });

    it('conflict: my_page_busy_avatar_picker_should_noop_without_context_or_service_work', 0, async () => {
      // Arrange
      const page = createPageDK(new AuthFacadeMockDK());
      page.avatarBusy = true;
      page.loadingProfile = false;
      page.actionLoading = false;

      // Act
      await page.pickAvatarFromGallery();

      // Assert
      expect(page.avatarBusy).assertTrue();
    });

    it('normal: my_page_avatar_picker_should_update_avatar_and_emit_pending_hint_when_not_synced', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const page = createPageDK(auth, new UiContextMockDK());
      const toasts: string[] = [];
      let lightHintCount = 0;
      const avatarService = new AvatarServiceMockDK();
      const avatarProfile: AvatarProfileResultDK = {
        cloudUrl: 'https://avatar.example/new.png',
        uploadState: 'PENDING'
      };
      avatarService.nextProfile = avatarProfile;
      avatarService.nextDisplayUri = 'file://avatar-updated.png';
      Reflect.set(page as Object, 'toast', (message: string): void => {
        toasts.push(message);
      });
      Reflect.set(page as Object, 'toastLightHintOnce', (_key: string, _message: string): void => {
        lightHintCount += 1;
      });
      Reflect.set(page as Object, 'avatarService', avatarService as Object);
      page.currentUserId = 'account_dk';
      page.currentRemoteAvatarUrl = 'https://avatar.example/old.png';
      page.avatarBusy = false;

      // Act
      await page.pickAvatarFromGallery();

      // Assert
      expect(auth.bindCount).assertEqual(1);
      expect(page.avatarDisplayUri).assertEqual('file://avatar-updated.png');
      expect(page.currentRemoteAvatarUrl).assertEqual('https://avatar.example/new.png');
      expect(page.useDefaultAvatar).assertFalse();
      expect(lightHintCount).assertEqual(1);
      expect(page.avatarBusy).assertFalse();
      expect(toasts.length).assertEqual(1);
    });

    it('boundary: my_page_avatar_picker_should_toast_cancel_when_user_dismisses_selection', 0, async () => {
      // Arrange
      const page = createPageDK(new AuthFacadeMockDK(), new UiContextMockDK());
      const toasts: string[] = [];
      const avatarService = new AvatarServiceMockDK();
      Reflect.set(page as Object, 'toast', (message: string): void => {
        toasts.push(message);
      });
      avatarService.nextProfile = null;
      avatarService.nextDisplayUri = 'unused';
      Reflect.set(page as Object, 'avatarService', avatarService as Object);
      page.currentUserId = 'account_cancel';

      // Act
      await page.pickAvatarFromGallery();

      // Assert
      expect(page.avatarBusy).assertFalse();
      expect(page.avatarDisplayUri).assertEqual('');
      expect(toasts.length).assertEqual(1);
    });

    it('boundary: my_page_save_username_should_toast_failure_when_remote_update_rejects', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      auth.updateSuccess = false;
      const page = createPageDK(auth, new UiContextMockDK());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'toast', (message: string): void => {
        toasts.push(message);
      });
      page.isGuestUser = false;
      page.currentUserId = 'account_fail';
      page.usernameDraft = 'ValidName';

      // Act
      await page.saveUsername();

      // Assert
      expect(auth.updateUsernameCalls.length).assertEqual(1);
      expect(page.actionLoading).assertFalse();
      expect(page.showUsernameEditor).assertFalse();
      expect(toasts.length).assertEqual(1);
    });

    it('combined: my_page_huawei_login_failure_paths_should_clear_loading_without_refresh', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const page = createPageDK(auth, new UiContextMockDK());
      page.agreementAccepted = false;

      // Act
      await page.loginWithHuaweiFromMyPage(buildCredentialDK());
      page.agreementAccepted = true;
      await page.loginWithHuaweiFromMyPage(buildCredentialDK());
      await page.loginWithHuaweiApiFallback();

      // Assert
      expect(page.actionLoading).assertFalse();
      expect(auth.loginCalls).assertEqual(2);
      expect(auth.lastCredentialWasUndefined).assertTrue();
    });

    it('normal: my_page_huawei_login_success_paths_should_accept_agreement_and_refresh_profile', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      auth.loginSuccess = true;
      const page = createPageDK(auth, new UiContextMockDK());
      let refreshCount = 0;
      Reflect.set(page as Object, 'refreshUserState', async (): Promise<void> => {
        refreshCount += 1;
      });
      page.agreementAccepted = true;

      // Act
      await page.loginWithHuaweiFromMyPage(buildCredentialDK());
      await page.loginWithHuaweiApiFallback();

      // Assert
      expect(auth.loginCalls).assertEqual(2);
      expect(auth.lastCredentialWasUndefined).assertTrue();
      expect(page.agreementAccepted).assertTrue();
      expect(refreshCount).assertEqual(2);
      expect(page.actionLoading).assertFalse();
    });

    it('normal: my_page_refresh_user_state_should_use_quick_guest_session_and_load_avatar', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const uiContext = new UiContextMockDK();
      const page = createPageDK(auth, uiContext);
      const session = new SessionManagerMockDK();
      const avatarService = new AvatarServiceMockDK();
      const guest = new SessionSnapshotDK();
      guest.isGuest = true;
      guest.accountId = 'guest_account_dk';
      guest.userId = 'guest_user_dk';
      const avatarProfile = new AvatarProfileResultDK();
      avatarProfile.cloudUrl = '';
      avatarProfile.uploadState = 'SYNCED';
      session.nextLoad = guest;
      avatarService.nextProfile = avatarProfile;
      avatarService.nextDisplayUri = 'file://guest-avatar.png';
      const sessionPatch = patchSessionManagerDK(session);
      const avatarPatch = patchAvatarServiceFactoryDK(avatarService);
      const profilePatch = patchProfileViewModelDK(new ProfileViewModelMockDK());

      // Act
      await page.refreshUserState();

      // Assert
      expect(auth.bindCount).assertEqual(1);
      expect(page.isGuestUser).assertTrue();
      expect(page.currentUserId).assertEqual('guest_account_dk');
      expect(page.userName.length > 0).assertTrue();
      expect(page.avatarDisplayUri).assertEqual('file://guest-avatar.png');
      expect(page.profileReady).assertTrue();
      expect(page.loadingProfile).assertFalse();
      expect(avatarService.loadCalls.length).assertEqual(1);
      profilePatch.restore();
      avatarPatch.restore();
      sessionPatch.restore();
    });

    it('boundary: my_page_refresh_user_state_should_use_profile_guest_data_when_no_quick_guest_session_exists', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      auth.nextProfile.isGuest = true;
      auth.nextProfile.nickname = 'GuestFromProfile';
      auth.nextProfile.accountId = '';
      auth.nextProfile.userId = 'guest_profile_dk';
      auth.nextProfile.avatarUrl = '';
      const page = createPageDK(auth, new UiContextMockDK());
      const session = new SessionManagerMockDK();
      const avatarService = new AvatarServiceMockDK();
      const avatarProfile = new AvatarProfileResultDK();
      avatarProfile.uploadState = 'SYNCED';
      avatarService.nextProfile = avatarProfile;
      avatarService.nextDisplayUri = 'file://guest-profile.png';
      const sessionPatch = patchSessionManagerDK(session);
      const avatarPatch = patchAvatarServiceFactoryDK(avatarService);
      const profilePatch = patchProfileViewModelDK(new ProfileViewModelMockDK());

      // Act
      await page.refreshUserState();

      // Assert
      expect(page.isGuestUser).assertTrue();
      expect(page.userName).assertEqual('GuestFromProfile');
      expect(page.currentUserId).assertEqual('guest_profile_dk');
      expect(page.avatarDisplayUri).assertEqual('file://guest-profile.png');
      expect(avatarService.loadCalls.length).assertEqual(1);
      profilePatch.restore();
      avatarPatch.restore();
      sessionPatch.restore();
    });

    it('boundary: my_page_refresh_user_state_should_use_default_avatar_when_cloud_profile_points_to_default_and_no_remote_url', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      auth.nextProfile.isGuest = false;
      auth.nextProfile.nickname = 'CloudUser';
      auth.nextProfile.accountId = 'account_cloud_dk';
      auth.nextProfile.userId = 'user_cloud_dk';
      auth.nextProfile.avatarUrl = '';
      const uiContext = new UiContextMockDK();
      const page = createPageDK(auth, uiContext);
      const session = new SessionManagerMockDK();
      session.nextLoad = null;
      session.nextAccountId = 'account_cloud_dk';
      const profileVm = new ProfileViewModelMockDK();
      const cloudProfile = new ProfileBootstrapResultDK();
      cloudProfile.username = 'CloudName';
      cloudProfile.accountId = 'account_cloud_dk';
      cloudProfile.avatarPath = '/defaults/avatar.png';
      profileVm.nextBootstrapProfile = cloudProfile;
      const avatarService = new AvatarServiceMockDK();
      const sessionPatch = patchSessionManagerDK(session);
      const avatarPatch = patchAvatarServiceFactoryDK(avatarService);
      const profilePatch = patchProfileViewModelDK(profileVm);
      const defaultAvatarPatch = new StaticPatchDK(ProfileViewModel as Object, 'DEFAULT_AVATAR_PATH', '/defaults/avatar.png' as Object);

      // Act
      await page.refreshUserState();

      // Assert
      expect(page.isGuestUser).assertFalse();
      expect(page.userName).assertEqual('CloudName');
      expect(page.currentUserId).assertEqual('account_cloud_dk');
      expect(page.useDefaultAvatar).assertTrue();
      expect(page.avatarDisplayUri).assertEqual('');
      expect(profileVm.bootstrapCalls.length).assertEqual(1);
      expect(avatarService.loadCalls.length).assertEqual(0);
      defaultAvatarPatch.restore();
      profilePatch.restore();
      avatarPatch.restore();
      sessionPatch.restore();
    });

    it('combined: my_page_refresh_user_state_should_fallback_to_session_avatar_load_when_cloud_profile_is_missing', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      auth.nextProfile.isGuest = false;
      auth.nextProfile.nickname = 'CloudFallback';
      auth.nextProfile.accountId = 'account_fallback_dk';
      auth.nextProfile.userId = 'user_fallback_dk';
      auth.nextProfile.avatarUrl = 'https://avatar.example/fallback.png';
      const page = createPageDK(auth, new UiContextMockDK());
      const session = new SessionManagerMockDK();
      session.nextAccountId = 'account_fallback_dk';
      const avatarService = new AvatarServiceMockDK();
      const avatarProfile = new AvatarProfileResultDK();
      avatarProfile.uploadState = 'SYNCED';
      avatarService.nextProfile = avatarProfile;
      avatarService.nextDisplayUri = 'file://fallback-avatar.png';
      const profileVm = new ProfileViewModelMockDK();
      profileVm.nextBootstrapProfile = null;
      const sessionPatch = patchSessionManagerDK(session);
      const avatarPatch = patchAvatarServiceFactoryDK(avatarService);
      const profilePatch = patchProfileViewModelDK(profileVm);

      // Act
      await page.refreshUserState();

      // Assert
      expect(page.isGuestUser).assertFalse();
      expect(page.userName).assertEqual('CloudFallback');
      expect(page.currentUserId).assertEqual('account_fallback_dk');
      expect(page.avatarDisplayUri).assertEqual('file://fallback-avatar.png');
      expect(profileVm.bootstrapCalls.length).assertEqual(1);
      expect(avatarService.loadCalls[0]).assertEqual('account_fallback_dk:https://avatar.example/fallback.png');
      profilePatch.restore();
      avatarPatch.restore();
      sessionPatch.restore();
    });

    it('invalid: my_page_refresh_user_state_should_fallback_to_guest_when_profile_load_throws', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      auth.profileThrows = true;
      const page = createPageDK(auth, new UiContextMockDK());
      const session = new SessionManagerMockDK();
      const avatarService = new AvatarServiceMockDK();
      const sessionPatch = patchSessionManagerDK(session);
      const avatarPatch = patchAvatarServiceFactoryDK(avatarService);
      const profilePatch = patchProfileViewModelDK(new ProfileViewModelMockDK());
      page.userName = 'BeforeFail';
      page.currentUserId = 'before_fail_dk';
      page.currentRemoteAvatarUrl = 'https://avatar.example/fail.png';
      page.avatarDisplayUri = 'file://before-fail.png';
      page.useDefaultAvatar = true;

      // Act
      await page.refreshUserState();

      // Assert
      expect(page.isGuestUser).assertTrue();
      expect(page.userName.length > 0).assertTrue();
      expect(page.currentUserId).assertEqual('guest_local');
      expect(page.currentRemoteAvatarUrl).assertEqual('');
      expect(page.avatarDisplayUri).assertEqual('');
      expect(page.useDefaultAvatar).assertFalse();
      expect(page.profileReady).assertTrue();
      expect(page.loadingProfile).assertFalse();
      profilePatch.restore();
      avatarPatch.restore();
      sessionPatch.restore();
    });

    it('boundary: my_page_avatar_picker_should_update_avatar_without_pending_hint_when_synced', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const page = createPageDK(auth, new UiContextMockDK());
      const toasts: string[] = [];
      let lightHintCount = 0;
      const avatarService = new AvatarServiceMockDK();
      const avatarProfile = new AvatarProfileResultDK();
      avatarProfile.cloudUrl = 'https://avatar.example/synced.png';
      avatarProfile.uploadState = 'SYNCED';
      avatarService.nextProfile = avatarProfile;
      avatarService.nextDisplayUri = 'file://avatar-synced.png';
      Reflect.set(page as Object, 'toast', (message: string): void => {
        toasts.push(message);
      });
      Reflect.set(page as Object, 'toastLightHintOnce', (_key: string, _message: string): void => {
        lightHintCount += 1;
      });
      Reflect.set(page as Object, 'avatarService', avatarService as Object);
      page.currentUserId = 'account_synced_dk';

      // Act
      await page.pickAvatarFromGallery();

      // Assert
      expect(page.avatarDisplayUri).assertEqual('file://avatar-synced.png');
      expect(page.currentRemoteAvatarUrl).assertEqual('https://avatar.example/synced.png');
      expect(lightHintCount).assertEqual(0);
      expect(toasts.length).assertEqual(1);
      expect(page.avatarBusy).assertFalse();
    });

    it('invalid: my_page_light_hint_should_ignore_blank_key_or_message', 0, () => {
      // Arrange
      const page = createPageDK(new AuthFacadeMockDK());
      let toastCount = 0;
      Reflect.set(page as Object, 'toast', (_message: string): void => {
        toastCount += 1;
      });

      // Act
      page.toastLightHintOnce('   ', 'hint');
      page.toastLightHintOnce('profile_offline:dk', '');

      // Assert
      expect(toastCount).assertEqual(0);
    });

    it('boundary: my_page_save_username_should_skip_profile_view_model_update_when_account_id_blank', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const profileVm = new ProfileViewModelMockDK();
      const profilePatch = patchProfileViewModelDK(profileVm);
      const page = createPageDK(auth, new UiContextMockDK());
      page.isGuestUser = false;
      page.currentUserId = '   ';
      page.usernameDraft = 'SoloName';

      // Act
      await page.saveUsername();

      // Assert
      expect(auth.updateUsernameCalls.length).assertEqual(1);
      expect(profileVm.updateCalls.length).assertEqual(0);
      expect(page.userName).assertEqual('SoloName');
      profilePatch.restore();
    });

    it('boundary: my_page_huawei_api_fallback_should_block_when_agreement_unchecked', 0, async () => {
      // Arrange
      const auth = new AuthFacadeMockDK();
      const page = createPageDK(auth, new UiContextMockDK());
      page.agreementAccepted = false;

      // Act
      await page.loginWithHuaweiApiFallback();

      // Assert
      expect(auth.loginCalls).assertEqual(0);
      expect(page.actionLoading).assertFalse();
    });
  });
}
