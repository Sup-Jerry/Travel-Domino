export interface UsernameSyncPort {
  onUsernameChanged(userId: string, username: string): Promise<void>;
}

export class NoopUsernameSyncPort implements UsernameSyncPort {
  async onUsernameChanged(_userId: string, _username: string): Promise<void> {
    return;
  }
}
