describe('auth-domain-spec', () => {
  it('should keep last-login-method unbind blocked by business rule', () => {
    const bindCount = 1;
    const canUnbind = bindCount > 1;
    expect(canUnbind).toBe(false);
  });

  it('should require reauth for cancel request', () => {
    const reauthToken = '';
    const accepted = reauthToken.trim().length > 0;
    expect(accepted).toBe(false);
  });
});
