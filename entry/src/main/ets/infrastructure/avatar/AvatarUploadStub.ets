import { hilog } from '@kit.PerformanceAnalysisKit';
import { AvatarUploadInput, AvatarUploadResult } from '../../domain/auth/AvatarModels';
import { AvatarUploadPort } from './AvatarUploadPort';

const TAG = 'AvatarUploadStub';

export class AvatarUploadStub implements AvatarUploadPort {
  public async uploadAvatar(_input: AvatarUploadInput): Promise<AvatarUploadResult> {
    const result = new AvatarUploadResult();
    result.status = 'PENDING_IMPLEMENTATION';
    result.requestId = `avatar_req_${Date.now()}`;
    hilog.info(0x0000, TAG, `upload stub called, requestId=${result.requestId}`);
    return result;
  }
}
