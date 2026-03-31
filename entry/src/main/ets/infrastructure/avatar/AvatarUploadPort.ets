import { AvatarUploadInput, AvatarUploadResult } from '../../domain/auth/AvatarModels';

export interface AvatarUploadPort {
  uploadAvatar(input: AvatarUploadInput): Promise<AvatarUploadResult>;
}
