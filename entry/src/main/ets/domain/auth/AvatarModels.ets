export type AvatarUploadState = 'EMPTY' | 'LOCAL_ONLY' | 'SYNCED';

export class AvatarProfile {
  userId: string = '';
  localUri: string = '';
  compressedUri: string = '';
  cloudUrl: string = '';
  cloudPath: string = '';
  avatarVersion: number = 0;
  uploadState: AvatarUploadState = 'EMPTY';
  updatedAt: number = 0;
}

export class AvatarUploadInput {
  userId: string = '';
  accountId: string = '';
  fileUri: string = '';
  mimeType: string = 'image/jpeg';
  avatarVersion?: number;
  byteSize?: number;
}

export class AvatarUploadResult {
  status: AvatarUploadState = 'LOCAL_ONLY';
  requestId: string = '';
  remoteUrl?: string;
  avatarPath?: string;
  avatarVersion?: number;
  errorCode?: string;
}
