import { UserProfileEntity } from '../entity/UserProfileEntity';

export interface IUserProfileRepository {
  getByAccountId(accountId: string): Promise<UserProfileEntity | null>;
  createDefaultProfile(accountId: string): Promise<UserProfileEntity>;
  updateUsername(accountId: string, username: string): Promise<UserProfileEntity>;
  updateAvatar(accountId: string, avatarPath: string, avatarVersion: number): Promise<UserProfileEntity>;
}
