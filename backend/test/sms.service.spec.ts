import { SmsService } from '../src/modules/sms/sms.service';

describe('SmsService', () => {
  const ORIGINAL_PROVIDER = process.env.SMS_PROVIDER;

  afterEach(() => {
    if (ORIGINAL_PROVIDER === undefined) {
      delete process.env.SMS_PROVIDER;
    } else {
      process.env.SMS_PROVIDER = ORIGINAL_PROVIDER;
    }
    jest.restoreAllMocks();
  });

  it('normal: sendCode should return hash/channel/expireAt for valid input', async () => {
    // Arrange
    const service = new SmsService();
    process.env.SMS_PROVIDER = '';
    jest.spyOn(Math, 'random').mockReturnValue(0.5);
    jest.spyOn(Date, 'now').mockReturnValue(1_710_000_000_000);

    // Act
    const result = await service.sendCode('13800000000', '+86', 'LOGIN');

    // Assert
    expect(result.codeHash).toBe('550000');
    expect(result.channel).toBe('PRODUCTION_ADAPTER');
    expect(result.expiredAt).toBe(1_710_000_300_000);
  });

  it('boundary: sendCode should still return payload for empty strings', async () => {
    // Arrange
    const service = new SmsService();
    jest.spyOn(Math, 'random').mockReturnValue(0);
    jest.spyOn(Date, 'now').mockReturnValue(1_710_000_010_000);

    // Act
    const result = await service.sendCode('', '', '');

    // Assert
    expect(result.codeHash).toBe('100000');
    expect(result.expiredAt).toBe(1_710_000_310_000);
  });

  it('invalid: sendCode should not throw when runtime inputs are non-string values', async () => {
    // Arrange
    const service = new SmsService();
    delete process.env.SMS_PROVIDER;
    jest.spyOn(Math, 'random').mockReturnValue(0.1);
    jest.spyOn(Date, 'now').mockReturnValue(1_710_000_020_000);

    // Act
    const run = async () =>
      service.sendCode(null as unknown as string, 123 as unknown as string, {} as unknown as string);

    // Assert
    await expect(run()).resolves.toMatchObject({
      channel: 'PRODUCTION_ADAPTER',
      expiredAt: 1_710_000_320_000
    });
  });

  it('conflict: sendCode should switch channel when environment provider is configured', async () => {
    // Arrange
    const service = new SmsService();
    process.env.SMS_PROVIDER = 'MOCK_PROVIDER';
    jest.spyOn(Math, 'random').mockReturnValue(0.2);
    jest.spyOn(Date, 'now').mockReturnValue(1_710_000_030_000);

    // Act
    const result = await service.sendCode('13800000000', '+86', 'LOGIN');

    // Assert
    expect(result.channel).toBe('MOCK_PROVIDER');
  });

  it('regression: td-20260411-sms-code-format should keep six-digit numeric hash', async () => {
    // Arrange
    const service = new SmsService();
    jest.spyOn(Math, 'random').mockReturnValue(0.999999);
    jest.spyOn(Date, 'now').mockReturnValue(1_710_000_040_000);

    // Act
    const result = await service.sendCode('13800000000', '+86', 'LOGIN');

    // Assert
    expect(/^\d{6}$/.test(result.codeHash)).toBe(true);
    expect(Number(result.codeHash)).toBeGreaterThanOrEqual(100000);
    expect(Number(result.codeHash)).toBeLessThanOrEqual(999999);
  });

  it('combined: sendCode should keep channel precedence and expiry progression across multiple calls', async () => {
    // Arrange
    const service = new SmsService();
    process.env.SMS_PROVIDER = 'CLOUD_SMS';
    const randomSpy = jest.spyOn(Math, 'random');
    randomSpy.mockReturnValueOnce(0.01).mockReturnValueOnce(0.02);
    const nowSpy = jest.spyOn(Date, 'now');
    nowSpy.mockReturnValueOnce(1_710_000_050_000).mockReturnValueOnce(1_710_000_055_000);

    // Act
    const first = await service.sendCode('13900000000', '+86', 'REGISTER');
    const second = await service.sendCode('13700000000', '+86', 'RESET');

    // Assert
    expect(first.channel).toBe('CLOUD_SMS');
    expect(second.channel).toBe('CLOUD_SMS');
    expect(second.expiredAt).toBeGreaterThan(first.expiredAt);
    expect(first.codeHash).not.toBe(second.codeHash);
  });

  it('boundary: sendCode should_keep_whitespace_provider_value_without_trimming', async () => {
    // Arrange
    const service = new SmsService();
    process.env.SMS_PROVIDER = '   ';
    jest.spyOn(Math, 'random').mockReturnValue(0.3);
    jest.spyOn(Date, 'now').mockReturnValue(1_710_000_060_000);

    // Act
    const result = await service.sendCode('13600000000', '+86', 'LOGIN');

    // Assert
    expect(result.channel).toBe('   ');
  });
});
