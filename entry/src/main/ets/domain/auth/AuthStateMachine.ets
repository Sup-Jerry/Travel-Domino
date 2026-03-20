export type AuthUserRuntimeState = 'UNAUTHENTICATED' | 'GUEST' | 'AUTH_PENDING' | 'AUTHENTICATED' | 'BLOCKED';
export type AuthSessionRuntimeState = 'ACTIVE' | 'EXPIRED' | 'REVOKED';

export class AuthStateMachine {
  public static resolveUserRuntimeState(
    isGuest: boolean,
    isAuthenticated: boolean,
    blocked: boolean,
    pending: boolean
  ): AuthUserRuntimeState {
    if (blocked) {
      return 'BLOCKED';
    }
    if (pending) {
      return 'AUTH_PENDING';
    }
    if (!isAuthenticated) {
      return 'UNAUTHENTICATED';
    }
    if (isGuest) {
      return 'GUEST';
    }
    return 'AUTHENTICATED';
  }

  public static resolveSessionRuntimeState(expireAt: number, revoked: boolean): AuthSessionRuntimeState {
    if (revoked) {
      return 'REVOKED';
    }
    if (Date.now() >= expireAt) {
      return 'EXPIRED';
    }
    return 'ACTIVE';
  }
}
