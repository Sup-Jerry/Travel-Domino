import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { HuaweiCredential } from '../../domain/auth/AuthTypes';

export class HuaweiAccountProvider {
  private static instance: HuaweiAccountProvider = new HuaweiAccountProvider();

  public static getInstance(): HuaweiAccountProvider {
    return HuaweiAccountProvider.instance;
  }

  public async explicitLogin(context?: common.Context): Promise<HuaweiCredential> {
    return this.executeLoginRequest(true, context);
  }

  public async silentLogin(context?: common.Context): Promise<HuaweiCredential> {
    return this.executeLoginRequest(false, context);
  }

  public fromAuthenticationCredential(credential: authentication.LoginWithHuaweiIDCredential): HuaweiCredential {
    const normalized = new HuaweiCredential();
    normalized.authorizationCode = credential.authorizationCode || '';
    normalized.idToken = credential.idToken || '';
    normalized.openId = credential.openID || '';
    normalized.unionId = credential.unionID || '';
    return normalized;
  }

  private async executeLoginRequest(forceLogin: boolean, context?: common.Context): Promise<HuaweiCredential> {
    const provider = new authentication.HuaweiIDProvider();
    const request = provider.createLoginWithHuaweiIDRequest();
    request.forceLogin = forceLogin;

    const controller = new authentication.AuthenticationController(context);
    const response = await controller.executeRequest(request);
    const typed = response as authentication.LoginWithHuaweiIDResponse;
    const credential = typed.data;
    if (!credential) {
      throw new Error('HUAWEI_CREDENTIAL_EMPTY');
    }
    return this.fromAuthenticationCredential(credential);
  }
}
