import { SocialService } from '../src/modules/social/social.service';

describe('SocialService', () => {
  it('normal: verifyCredential should build provider uid from openId', async () => {
    // Arrange
    const service = new SocialService();

    // Act
    const result = await service.verifyCredential('HUAWEI', { openId: 'open-001' });

    // Assert
    expect(result).toBe('HUAWEI:open-001');
  });

  it('boundary: verifyCredential should return empty string when no credential id exists', async () => {
    // Arrange
    const service = new SocialService();

    // Act
    const result = await service.verifyCredential('HUAWEI', {});

    // Assert
    expect(result).toBe('');
  });

  it('invalid: verifyCredential should trim whitespace-only uid to empty result', async () => {
    // Arrange
    const service = new SocialService();

    // Act
    const result = await service.verifyCredential('HUAWEI', { idToken: '   ' });

    // Assert
    expect(result).toBe('');
  });

  it('conflict: verifyCredential should prefer unionId over other credential fields', async () => {
    // Arrange
    const service = new SocialService();

    // Act
    const result = await service.verifyCredential('WX', {
      unionId: 'union-priority',
      openId: 'open-second',
      authCode: 'code-third',
      idToken: 'id-fourth'
    });

    // Assert
    expect(result).toBe('WX:union-priority');
  });

  it('regression: td-20260411-social-trim should keep trimmed id in provider uid', async () => {
    // Arrange
    const service = new SocialService();

    // Act
    const result = await service.verifyCredential('QQ', { authCode: '  code-123  ' });

    // Assert
    expect(result).toBe('QQ:code-123');
  });

  it('combined: verifyCredential should apply fallback order openId -> authCode -> idToken', async () => {
    // Arrange
    const service = new SocialService();

    // Act
    const first = await service.verifyCredential('A', { openId: 'open-a', authCode: 'code-a', idToken: 'id-a' });
    const second = await service.verifyCredential('B', { authCode: 'code-b', idToken: 'id-b' });
    const third = await service.verifyCredential('C', { idToken: 'id-c' });

    // Assert
    expect(first).toBe('A:open-a');
    expect(second).toBe('B:code-b');
    expect(third).toBe('C:id-c');
  });

  it('boundary: verifyCredential should fallback_to_id_token_when_other_ids_missing', async () => {
    // Arrange
    const service = new SocialService();

    // Act
    const result = await service.verifyCredential('HUAWEI', {
      idToken: '  id-token-only  '
    });

    // Assert
    expect(result).toBe('HUAWEI:id-token-only');
  });
});

