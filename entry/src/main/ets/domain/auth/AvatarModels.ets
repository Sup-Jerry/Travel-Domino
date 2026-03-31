export type AvatarUploadState = 'EMPTY' | 'LOCAL_ONLY' | 'PENDING_IMPLEMENTATION' | 'SYNCED';

export class AvatarProfile {
  userId: string = '';
  localUri: string = '';
  compressedUri: string = '';
  cloudUrl: string = '';
  uploadState: AvatarUploadState = 'EMPTY';
  updatedAt: number = 0;
}

export class AvatarUploadInput {
  userId: string = '';
  fileUri: string = '';
  mimeType: string = 'image/jpeg';
  byteSize?: number;
}

export class AvatarUploadResult {
  status: AvatarUploadState = 'PENDING_IMPLEMENTATION';
  requestId: string = '';
  remoteUrl?: string;
  errorCode?: string;
}
