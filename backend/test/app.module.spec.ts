import { MODULE_METADATA } from '@nestjs/common/constants';
import { AppModule } from '../src/app.module';
import { AppConfigModule } from '../src/config/app-config.module';
import { AuthModule } from '../src/modules/auth/auth.module';
import { HealthModule } from '../src/modules/health/health.module';

describe('unit_test_case_generator_autofill_app_module', () => {
  it('normal: app_module_should_import_app_config_auth_and_health_modules', () => {
    // Arrange
    const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, AppModule) as unknown[] | undefined;
    // Act
    const hasCoreModules = Array.isArray(imports) &&
      imports.includes(AppConfigModule) &&
      imports.includes(AuthModule) &&
      imports.includes(HealthModule);
    // Assert
    expect(hasCoreModules).toBe(true);
  });

  it('boundary: app_module_should_register_four_import_entries', () => {
    // Arrange
    const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, AppModule) as unknown[] | undefined;
    // Act
    const count = imports?.length ?? 0;
    // Assert
    expect(count).toBe(4);
  });

  it('invalid: app_module_should_not_have_controller_metadata', () => {
    // Arrange
    const controllers = Reflect.getMetadata(MODULE_METADATA.CONTROLLERS, AppModule) as unknown[] | undefined;
    // Act
    const count = controllers?.length ?? 0;
    // Assert
    expect(count).toBe(0);
  });

  it('conflict: app_module_should_not_have_provider_metadata', () => {
    // Arrange
    const providers = Reflect.getMetadata(MODULE_METADATA.PROVIDERS, AppModule) as unknown[] | undefined;
    // Act
    const count = providers?.length ?? 0;
    // Assert
    expect(count).toBe(0);
  });

  it('regression: app_module_should_keep_global_config_registration', () => {
    // Arrange
    const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, AppModule) as unknown[] | undefined;
    // Act
    const hasConfigRoot = Array.isArray(imports) && imports.some((item) => item instanceof Promise);
    // Assert
    expect(hasConfigRoot).toBe(true);
  });

  it('combined: app_module_should_keep_config_and_business_module_contract', () => {
    // Arrange
    const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, AppModule) as unknown[] | undefined;
    // Act
    const pass = Array.isArray(imports) &&
      imports.some((item) => item instanceof Promise) &&
      imports.includes(AppConfigModule) &&
      imports.includes(AuthModule) &&
      imports.includes(HealthModule);
    // Assert
    expect(pass).toBe(true);
  });
});
