import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HuaweiCredential } from '../../domain/auth/AuthTypes';

export class HuaweiAccountProvider {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'HuaweiAccountProvider';
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
    hilog.info(
      HuaweiAccountProvider.LOG_DOMAIN,
      HuaweiAccountProvider.LOG_TAG,
      `[LOGIN_TRACE][provider] normalize credential authCodeLen=${normalized.authorizationCode.length}, idTokenLen=${normalized.idToken.length}, openIdLen=${normalized.openId.length}, unionIdLen=${normalized.unionId.length}`
    );
    return normalized;
  }

  private async executeLoginRequest(forceLogin: boolean, context?: common.Context): Promise<HuaweiCredential> {
    hilog.info(
      HuaweiAccountProvider.LOG_DOMAIN,
      HuaweiAccountProvider.LOG_TAG,
      `[LOGIN_TRACE][provider] execute start forceLogin=${forceLogin ? 1 : 0}, hasContext=${context ? 1 : 0}`
    );
    const provider = new authentication.HuaweiIDProvider();
    const request = provider.createLoginWithHuaweiIDRequest();
    request.forceLogin = forceLogin;

    try {
      const controller = new authentication.AuthenticationController(context);
      const response = await controller.executeRequest(request);
      const typed = response as authentication.LoginWithHuaweiIDResponse;
      const credential = typed.data;
      hilog.info(
        HuaweiAccountProvider.LOG_DOMAIN,
        HuaweiAccountProvider.LOG_TAG,
        `[LOGIN_TRACE][provider] execute response hasResponse=${response ? 1 : 0}, hasData=${credential ? 1 : 0}`
      );
      if (!credential) {
        hilog.warn(HuaweiAccountProvider.LOG_DOMAIN, HuaweiAccountProvider.LOG_TAG, '[LOGIN_TRACE][provider] empty credential');
        throw new Error('HUAWEI_CREDENTIAL_EMPTY');
      }
      hilog.info(HuaweiAccountProvider.LOG_DOMAIN, HuaweiAccountProvider.LOG_TAG, '[LOGIN_TRACE][provider] execute success');
      return this.fromAuthenticationCredential(credential);
    } catch (error) {
      const errCode = Number((error as Record<string, Object>)?.code || 0);
      const errMessage = error instanceof Error ? error.message : 'auth_provider_error';
      hilog.error(
        HuaweiAccountProvider.LOG_DOMAIN,
        HuaweiAccountProvider.LOG_TAG,
        `[LOGIN_TRACE][provider] execute fail code=${errCode}, message=${errMessage}`
      );
      throw new Error(errMessage);
    }
  }
}
