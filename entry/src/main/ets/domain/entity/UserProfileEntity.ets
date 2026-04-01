export class UserProfileEntity {
  profileId: string = '';
  accountId: string = '';
  username: string = '';
  avatarPath: string = '';
  avatarVersion: number = 1;
  isInitialized: boolean = false;
  createdAt: number = 0;
  updatedAt: number = 0;
}

// Cloud DB object type generated from AGC console model.
export class UserProfileCloudRecord {
  static className: string = 'UserProfile';

  accountId: string | undefined = undefined;
  username: string = '';
  avatarPath: string | undefined = undefined;
  avatarVersion: number = 1;
  isInitialized: boolean = false;
  createdAt: Object | undefined = undefined;
  updatedAt: Object | undefined = undefined;
}
