export class StorageKeys {
  static readonly SESSION_CACHE: string = 'session_cache';
  static readonly PROFILE_CACHE_PREFIX: string = 'profile_cache_';
  static readonly AVATAR_CACHE_PREFIX: string = 'avatar_cache_';

  public static buildProfileCacheKey(accountId: string): string {
    const safeAccountId = StorageKeys.normalizeAccountId(accountId);
    return `${StorageKeys.PROFILE_CACHE_PREFIX}${safeAccountId}`;
  }

  public static buildAvatarCacheKey(accountId: string): string {
    const safeAccountId = StorageKeys.normalizeAccountId(accountId);
    return `${StorageKeys.AVATAR_CACHE_PREFIX}${safeAccountId}`;
  }

  private static normalizeAccountId(accountId: string): string {
    const normalized = String(accountId || '').trim();
    return normalized.length > 0 ? normalized : 'guest_local';
  }
}
