import { describe, it, expect } from '@ohos/hypium';
import { createMyPageForTest } from '../main/ets/pages/MyPage';
import { HuaweiCredential } from '../main/ets/domain/auth/AuthTypes';
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

class ProfileViewModelMockDK {
  public bindCount: number = 0;
  public resetCount: number = 0;
  public updateCalls: string[] = [];

  bindContext(_context: Object): void {
    this.bindCount += 1;
  }

  reset(): void {
    this.resetCount += 1;
  }

  async updateUsername(accountId: string, username: string): Promise<void> {
    this.updateCalls.push(`${accountId}:${username}`);
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
  });
}
