import { MODULE_METADATA } from '@nestjs/common/constants';
import { AppConfigModule } from '../src/config/app-config.module';
import { HealthController } from '../src/modules/health/health.controller';
import { HealthModule } from '../src/modules/health/health.module';

describe('unit_test_case_generator_autofill_health_module', () => {
  it('normal: health_module_should_register_health_controller', () => {
    // Arrange
    const controllers = Reflect.getMetadata(MODULE_METADATA.CONTROLLERS, HealthModule) as unknown[] | undefined;
    // Act
    const hasController = Array.isArray(controllers) && controllers.includes(HealthController);
    // Assert
    expect(hasController).toBe(true);
  });

  it('boundary: health_module_should_define_single_controller', () => {
    // Arrange
    const controllers = Reflect.getMetadata(MODULE_METADATA.CONTROLLERS, HealthModule) as unknown[] | undefined;
    // Act
    const count = controllers?.length ?? 0;
    // Assert
    expect(count).toBe(1);
  });

  it('invalid: health_module_should_not_register_empty_imports', () => {
    // Arrange
    const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, HealthModule) as unknown[] | undefined;
    // Act
    const hasImports = Array.isArray(imports) && imports.length > 0;
    // Assert
    expect(hasImports).toBe(true);
  });

  it('conflict: health_module_should_import_app_config_module', () => {
    // Arrange
    const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, HealthModule) as unknown[] | undefined;
    // Act
    const hasAppConfigModule = Array.isArray(imports) && imports.includes(AppConfigModule);
    // Assert
    expect(hasAppConfigModule).toBe(true);
  });

  it('regression: health_module_should_not_register_providers', () => {
    // Arrange
    const providers = Reflect.getMetadata(MODULE_METADATA.PROVIDERS, HealthModule) as unknown[] | undefined;
    // Act
    const providerCount = providers?.length ?? 0;
    // Assert
    expect(providerCount).toBe(0);
  });

  it('combined: health_module_should_keep_import_and_controller_contract', () => {
    // Arrange
    const imports = Reflect.getMetadata(MODULE_METADATA.IMPORTS, HealthModule) as unknown[] | undefined;
    const controllers = Reflect.getMetadata(MODULE_METADATA.CONTROLLERS, HealthModule) as unknown[] | undefined;
    // Act
    const pass = Array.isArray(imports) && imports.includes(AppConfigModule) &&
      Array.isArray(controllers) && controllers.includes(HealthController);
    // Assert
    expect(pass).toBe(true);
  });
});
