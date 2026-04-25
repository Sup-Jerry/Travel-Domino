import { describe, expect, it } from '@ohos/hypium';
import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { AddItemDialog } from '../main/ets/pages/components/dialogs/AddItemDialog';

interface AccessManagerLikeGZ {
  checkAccessToken(tokenId: number, permission: string): Promise<number>;
  requestPermissionsFromUser(context: Object, permissions: string[]): Promise<PermissionResultGZ>;
}

interface AddItemDialogPrivateGZ {
  checkAndRequestPermission(): Promise<boolean>;
  safeShowToast(message: string): void;
  getUIContext(): Object;
}

interface DialogButtonGZ {
  value: string;
  action: () => void | Promise<void>;
}

interface AlertDialogOptionsGZ {
  title: string;
  message: string;
  primaryButton: DialogButtonGZ;
  secondaryButton: DialogButtonGZ;
}

interface AppInfoGZ {
  accessTokenId: number;
}

interface BundleInfoGZ {
  appInfo: AppInfoGZ;
}

class PermissionResultGZ {
  authResults: number[] = [];
}

class HostContextGZ {
}

class AbilityKitHooksGZ {
  private readonly originCreateAtManager: Object;
  private readonly originGetBundleInfoForSelf: Object;

  constructor() {
    const aacObj: Object = Reflect.get(globalThis, 'abilityAccessCtrl') as Object;
    const bmObj: Object = Reflect.get(globalThis, 'bundleManager') as Object;
    this.originCreateAtManager = Reflect.get(aacObj, 'createAtManager') as Object;
    this.originGetBundleInfoForSelf = Reflect.get(bmObj, 'getBundleInfoForSelf') as Object;
  }

  setAccessManager(manager: AccessManagerLikeGZ): void {
    const aacObj: Object = Reflect.get(globalThis, 'abilityAccessCtrl') as Object;
    Reflect.set(aacObj, 'createAtManager', (): Object => manager as Object);
  }

  setBundleInfoResolver(fn: () => Promise<BundleInfoGZ>): void {
    const bmObj: Object = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(bmObj, 'getBundleInfoForSelf', fn);
  }

  restore(): void {
    const aacObj: Object = Reflect.get(globalThis, 'abilityAccessCtrl') as Object;
    const bmObj: Object = Reflect.get(globalThis, 'bundleManager') as Object;
    Reflect.set(aacObj, 'createAtManager', this.originCreateAtManager);
    Reflect.set(bmObj, 'getBundleInfoForSelf', this.originGetBundleInfoForSelf);
  }
}

class PermissionUiContextGZ {
  public readonly toastMessages: string[] = [];
  private readonly hostContext: HostContextGZ = new HostContextGZ();
  private actionMode: 'primary' | 'secondary' = 'primary';

  setActionMode(mode: 'primary' | 'secondary'): void {
    this.actionMode = mode;
  }

  showAlertDialog(options: AlertDialogOptionsGZ): void {
    if (this.actionMode === 'secondary') {
      void options.secondaryButton.action();
      return;
    }
    void options.primaryButton.action();
  }

  getHostContext(): Object {
    return this.hostContext;
  }
}

class AccessManagerMockGZ implements AccessManagerLikeGZ {
  public grantStatus: number = -1;
  public requestResult: number = -1;

  async checkAccessToken(_tokenId: number, _permission: string): Promise<number> {
    return this.grantStatus;
  }

  async requestPermissionsFromUser(_context: Object, _permissions: string[]): Promise<PermissionResultGZ> {
    const result = new PermissionResultGZ();
    result.authResults = [this.requestResult];
    return result;
  }
}

function createDialogGZ(uiContext: PermissionUiContextGZ): AddItemDialogPrivateGZ {
  const page = new AddItemDialog(undefined, {} as LocalStorage) as Object as AddItemDialogPrivateGZ;
  Reflect.set(page as Object, 'getUIContext', (): Object => uiContext as Object);
  Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
    uiContext.toastMessages.push(message);
  });
  return page;
}

export default function phase2BatchGZTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGZ_add_item_permission', () => {
    it('boundary: add_item_permission_should_return_false_when_user_cancels_pre_permission_dialog', 0,
      async (done: Function) => {
        const hooks = new AbilityKitHooksGZ();
        const uiContext = new PermissionUiContextGZ();
        uiContext.setActionMode('primary');
        const manager = new AccessManagerMockGZ();
        manager.grantStatus = -1;
        hooks.setAccessManager(manager);
        hooks.setBundleInfoResolver(async (): Promise<BundleInfoGZ> => {
          const appInfo: AppInfoGZ = { accessTokenId: 1024 };
          const info: BundleInfoGZ = { appInfo: appInfo };
          return info;
        });
        const page = createDialogGZ(uiContext);

        const allowed = await page.checkAndRequestPermission();

        expect(allowed).assertFalse();
        expect(uiContext.toastMessages.length).assertEqual(0);
        hooks.restore();
        done();
      });

    it('normal: add_item_permission_should_return_true_when_location_already_granted', 0, async (done: Function) => {
      const hooks = new AbilityKitHooksGZ();
      const uiContext = new PermissionUiContextGZ();
      const manager = new AccessManagerMockGZ();
      const granted = Reflect.get(Reflect.get(globalThis, 'abilityAccessCtrl') as Object, 'GrantStatus') as Record<string, number>;
      manager.grantStatus = granted.PERMISSION_GRANTED;
      hooks.setAccessManager(manager);
      hooks.setBundleInfoResolver(async (): Promise<BundleInfoGZ> => {
        const appInfo: AppInfoGZ = { accessTokenId: 9527 };
        const info: BundleInfoGZ = { appInfo: appInfo };
        return info;
      });
      const page = createDialogGZ(uiContext);

      const allowed = await page.checkAndRequestPermission();

      expect(allowed).assertTrue();
      expect(uiContext.toastMessages.length).assertEqual(0);
      hooks.restore();
      done();
    });

    it('boundary: add_item_permission_should_return_false_when_bundle_lookup_fails', 0, async (done: Function) => {
      const hooks = new AbilityKitHooksGZ();
      const uiContext = new PermissionUiContextGZ();
      const manager = new AccessManagerMockGZ();
      hooks.setAccessManager(manager);
      hooks.setBundleInfoResolver(async (): Promise<BundleInfoGZ> => {
        throw new Error('bundle_lookup_failed_gz');
      });
      const page = createDialogGZ(uiContext);

      const allowed = await page.checkAndRequestPermission();

      expect(allowed).assertFalse();
      expect(uiContext.toastMessages.length).assertEqual(1);
      expect(uiContext.toastMessages[0].indexOf('权限检查失败') >= 0).assertTrue();
      hooks.restore();
      done();
    });

    it('regression: add_item_permission_should_keep_map_entry_when_user_denies_system_dialog', 0, async (done: Function) => {
      const hooks = new AbilityKitHooksGZ();
      const uiContext = new PermissionUiContextGZ();
      uiContext.setActionMode('secondary');
      const manager = new AccessManagerMockGZ();
      manager.grantStatus = -1;
      manager.requestResult = 1;
      hooks.setAccessManager(manager);
      hooks.setBundleInfoResolver(async (): Promise<BundleInfoGZ> => {
        const appInfo: AppInfoGZ = { accessTokenId: 2048 };
        const info: BundleInfoGZ = { appInfo: appInfo };
        return info;
      });
      const page = createDialogGZ(uiContext);

      const allowed = await page.checkAndRequestPermission();

      expect(allowed).assertTrue();
      expect(uiContext.toastMessages.length).assertEqual(1);
      expect(uiContext.toastMessages[0].indexOf('定位权限') >= 0).assertTrue();
      hooks.restore();
      done();
    });
  });
}
