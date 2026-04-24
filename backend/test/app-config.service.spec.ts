import { AppConfigService } from '../src/config/app-config.service';
import * as fs from 'fs';

describe('unit_test_case_generator_autofill_app_config_service', () => {
  const ORIGINAL_ENV = process.env;
  let originalLocalEnv: Map<string, string>;

  beforeAll(() => {
    originalLocalEnv = (AppConfigService as any).localEnv as Map<string, string>;
  });

  beforeEach(() => {
    (AppConfigService as any).localEnv = new Map<string, string>();
    process.env = { ...ORIGINAL_ENV };
    delete process.env.DATABASE_URL;
    delete process.env.JWT_SECRET;
    delete process.env.AUTH_ACCESS_TTL_SECONDS;
    delete process.env.AUTH_REFRESH_TTL_SECONDS;
    delete process.env.AI_UPSTREAM_URL;
    delete process.env.AI_UPSTREAM_KEY;
    delete process.env.AI_UPSTREAM_MODEL;
    delete process.env.AI_API_URL;
    delete process.env.AI_API_KEY;
  });

  afterAll(() => {
    (AppConfigService as any).localEnv = originalLocalEnv;
    process.env = ORIGINAL_ENV;
  });

  it('normal: app_config_should_read_required_values', () => {
    // Arrange
    process.env.DATABASE_URL = 'postgres://u:p@localhost:5432/db';
    process.env.JWT_SECRET = 'secret';
    const service = new AppConfigService();
    // Act
    const databaseUrl = service.databaseUrl;
    const jwtSecret = service.jwtSecret;
    // Assert
    expect(databaseUrl).toBe('postgres://u:p@localhost:5432/db');
    expect(jwtSecret).toBe('secret');
  });

  it('boundary: app_config_should_use_default_ttl_when_env_missing', () => {
    // Arrange
    const service = new AppConfigService();
    // Act
    const accessTtl = service.authAccessTtlSeconds;
    const refreshTtl = service.authRefreshTtlSeconds;
    // Assert
    expect(accessTtl).toBe(7200);
    expect(refreshTtl).toBe(2592000);
  });

  it('invalid: app_config_should_throw_when_database_url_missing', () => {
    // Arrange
    process.env.JWT_SECRET = 'secret';
    const service = new AppConfigService();
    // Act
    const action = () => service.databaseUrl;
    // Assert
    expect(action).toThrow('DATABASE_URL is required');
  });

  it('conflict: app_config_should_throw_when_jwt_secret_missing', () => {
    // Arrange
    process.env.DATABASE_URL = 'postgres://u:p@localhost:5432/db';
    const service = new AppConfigService();
    // Act
    const action = () => service.jwtSecret;
    // Assert
    expect(action).toThrow('JWT_SECRET is required');
  });

  it('regression: app_config_should_apply_custom_access_ttl', () => {
    // Arrange
    process.env.AUTH_ACCESS_TTL_SECONDS = '3600';
    const service = new AppConfigService();
    // Act
    const accessTtl = service.authAccessTtlSeconds;
    // Assert
    expect(accessTtl).toBe(3600);
  });

  it('combined: app_config_should_parse_custom_ttls_together', () => {
    // Arrange
    process.env.AUTH_ACCESS_TTL_SECONDS = '1800';
    process.env.AUTH_REFRESH_TTL_SECONDS = '604800';
    const service = new AppConfigService();
    // Act
    const accessTtl = service.authAccessTtlSeconds;
    const refreshTtl = service.authRefreshTtlSeconds;
    // Assert
    expect(accessTtl).toBe(1800);
    expect(refreshTtl).toBe(604800);
  });

  it('normal: app_config_should_read_ai_upstream_values', () => {
    // Arrange
    process.env.AI_UPSTREAM_URL = 'https://api.deepseek.com/chat/completions';
    process.env.AI_UPSTREAM_KEY = 'k_test';
    process.env.AI_UPSTREAM_MODEL = 'deepseek-chat';
    const service = new AppConfigService();
    // Act
    const url = service.aiUpstreamUrl;
    const key = service.aiUpstreamKey;
    const model = service.aiUpstreamModel;
    // Assert
    expect(url).toBe('https://api.deepseek.com/chat/completions');
    expect(key).toBe('k_test');
    expect(model).toBe('deepseek-chat');
  });

  it('regression: app_config_should_fallback_to_ai_api_legacy_vars', () => {
    // Arrange
    process.env.AI_API_URL = 'https://legacy.example/v2/chat/completions';
    process.env.AI_API_KEY = 'legacy_key';
    const service = new AppConfigService();
    // Act
    const url = service.aiUpstreamUrl;
    const key = service.aiUpstreamKey;
    // Assert
    expect(url).toBe('https://legacy.example/v2/chat/completions');
    expect(key).toBe('legacy_key');
    expect(service.aiUpstreamModel).toBe('deepseek-chat');
  });

  it('invalid: app_config_should_throw_when_ai_upstream_missing', () => {
    // Arrange
    const service = new AppConfigService();
    // Act
    const readUrl = () => service.aiUpstreamUrl;
    const readKey = () => service.aiUpstreamKey;
    // Assert
    expect(readUrl).toThrow('AI_UPSTREAM_URL is required');
    expect(readKey).toThrow('AI_UPSTREAM_KEY is required');
  });

  it('boundary: app_config_should_ignore_invalid_local_env_lines_and_keep_first_value', () => {
    const existsSpy = jest.spyOn(fs, 'existsSync')
      .mockImplementation((filePath: fs.PathLike) => String(filePath).endsWith('.env'));
    const readSpy = jest.spyOn(fs, 'readFileSync')
      .mockReturnValue('INVALID_LINE\n=EMPTY_KEY\nJWT_SECRET = first_secret\nJWT_SECRET=second_secret\nAI_UPSTREAM_MODEL=   \n');

    const localEnv = (AppConfigService as any).loadLocalEnv() as Map<string, string>;

    expect(localEnv.get('JWT_SECRET')).toBe('first_secret');
    expect(localEnv.has('INVALID_LINE')).toBe(false);
    expect(localEnv.has('')).toBe(false);
    expect(localEnv.get('AI_UPSTREAM_MODEL')).toBe('');

    existsSpy.mockRestore();
    readSpy.mockRestore();
  });

  it('boundary: app_config_should_use_explicit_fallback_when_read_env_called_without_second_arg', () => {
    const service = new AppConfigService() as unknown as {
      readEnv(key: string): string;
    };

    const value = service.readEnv('MISSING_ENV_KEY');

    expect(value).toBe('');
  });

  it('boundary: app_config_should_fallback_model_when_config_value_is_blank_after_trim', () => {
    (AppConfigService as any).localEnv = new Map<string, string>([['AI_UPSTREAM_MODEL', '   ']]);
    const service = new AppConfigService();

    expect(service.aiUpstreamModel).toBe('deepseek-chat');
  });

  it('boundary: app_config_should_prefer_non_empty_local_env_over_process_env', () => {
    (AppConfigService as any).localEnv = new Map<string, string>([
      ['JWT_SECRET', 'local_secret'],
      ['AI_UPSTREAM_KEY', 'local_ai_key']
    ]);
    process.env.JWT_SECRET = 'process_secret';
    process.env.AI_UPSTREAM_KEY = 'process_ai_key';
    const service = new AppConfigService();

    expect(service.jwtSecret).toBe('local_secret');
    expect(service.aiUpstreamKey).toBe('local_ai_key');
  });
});
