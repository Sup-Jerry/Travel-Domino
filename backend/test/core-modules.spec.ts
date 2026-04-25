import 'reflect-metadata';
import { AppConfigModule } from '../src/config/app-config.module';
import { AppConfigService } from '../src/config/app-config.service';
import { PgService } from '../src/config/pg.service';
import { AuditModule } from '../src/modules/audit/audit.module';
import { AuditService } from '../src/modules/audit/audit.service';
import { RiskModule } from '../src/modules/risk/risk.module';
import { RiskService } from '../src/modules/risk/risk.service';
import { SmsModule } from '../src/modules/sms/sms.module';
import { SmsService } from '../src/modules/sms/sms.service';
import { SocialModule } from '../src/modules/social/social.module';
import { SocialService } from '../src/modules/social/social.service';

describe('Core Modules Metadata', () => {
  const getProviders = (moduleType: object): unknown[] => Reflect.getMetadata('providers', moduleType) || [];
  const getExports = (moduleType: object): unknown[] => Reflect.getMetadata('exports', moduleType) || [];
  const getImports = (moduleType: object): unknown[] => Reflect.getMetadata('imports', moduleType) || [];

  it('normal: each core module should provide its primary service', () => {
    // Arrange
    const riskProviders = getProviders(RiskModule);
    const smsProviders = getProviders(SmsModule);
    const socialProviders = getProviders(SocialModule);
    const auditProviders = getProviders(AuditModule);

    // Act
    const hasRisk = riskProviders.includes(RiskService);
    const hasSms = smsProviders.includes(SmsService);
    const hasSocial = socialProviders.includes(SocialService);
    const hasAudit = auditProviders.includes(AuditService);

    // Assert
    expect(hasRisk).toBe(true);
    expect(hasSms).toBe(true);
    expect(hasSocial).toBe(true);
    expect(hasAudit).toBe(true);
  });

  it('boundary: sms and social modules should not require imports', () => {
    // Arrange
    const smsImports = getImports(SmsModule);
    const socialImports = getImports(SocialModule);

    // Act
    const smsImportCount = smsImports.length;
    const socialImportCount = socialImports.length;

    // Assert
    expect(smsImportCount).toBe(0);
    expect(socialImportCount).toBe(0);
  });

  it('invalid: module metadata should not include undefined providers', () => {
    // Arrange
    const modules = [RiskModule, SmsModule, SocialModule, AuditModule];

    // Act
    const hasUndefinedProvider = modules.some((m) => getProviders(m).some((p) => p === undefined));

    // Assert
    expect(hasUndefinedProvider).toBe(false);
  });

  it('conflict: each module should export the same primary service it provides', () => {
    // Arrange
    const matrix = [
      { module: RiskModule, service: RiskService },
      { module: SmsModule, service: SmsService },
      { module: SocialModule, service: SocialService },
      { module: AuditModule, service: AuditService }
    ];

    // Act
    const mismatches = matrix.filter((item) => {
      const providers = getProviders(item.module);
      const exports = getExports(item.module);
      return !(providers.includes(item.service) && exports.includes(item.service));
    });

    // Assert
    expect(mismatches.length).toBe(0);
  });

  it('regression: td-20260411-module-imports should keep AppConfigModule in risk and audit modules', () => {
    // Arrange
    const riskImports = getImports(RiskModule);
    const auditImports = getImports(AuditModule);

    // Act
    const riskHasConfig = riskImports.includes(AppConfigModule);
    const auditHasConfig = auditImports.includes(AppConfigModule);

    // Assert
    expect(riskHasConfig).toBe(true);
    expect(auditHasConfig).toBe(true);
  });

  it('combined: provider/export/import contracts should hold across all core modules', () => {
    // Arrange
    const modules = [
      { module: RiskModule, service: RiskService, requiresConfig: true },
      { module: SmsModule, service: SmsService, requiresConfig: false },
      { module: SocialModule, service: SocialService, requiresConfig: false },
      { module: AuditModule, service: AuditService, requiresConfig: true }
    ];

    // Act
    const contractOk = modules.every((item) => {
      const providers = getProviders(item.module);
      const exports = getExports(item.module);
      const imports = getImports(item.module);
      const configOk = item.requiresConfig ? imports.includes(AppConfigModule) : true;
      return providers.includes(item.service) && exports.includes(item.service) && configOk;
    });

    // Assert
    expect(contractOk).toBe(true);
  });

  it('boundary: app_config_module_should_export_both_config_and_pg_services_without_imports', () => {
    const providers = getProviders(AppConfigModule);
    const exports = getExports(AppConfigModule);
    const imports = getImports(AppConfigModule);

    expect(providers.includes(AppConfigService)).toBe(true);
    expect(providers.includes(PgService)).toBe(true);
    expect(exports.includes(AppConfigService)).toBe(true);
    expect(exports.includes(PgService)).toBe(true);
    expect(imports.length).toBe(0);
  });
});
