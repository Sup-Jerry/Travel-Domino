import { AppConfigService } from '../src/config/app-config.service';

describe('unit_test_case_generator_autofill_app_config_service', () => {
  const ORIGINAL_ENV = process.env;

  beforeEach(() => {
    process.env = { ...ORIGINAL_ENV };
    delete process.env.DATABASE_URL;
    delete process.env.JWT_SECRET;
    delete process.env.AUTH_ACCESS_TTL_SECONDS;
    delete process.env.AUTH_REFRESH_TTL_SECONDS;
  });

  afterAll(() => {
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
});
