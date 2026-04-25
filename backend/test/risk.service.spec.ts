import { BadRequestException } from '@nestjs/common';
import { RiskService } from '../src/modules/risk/risk.service';

type QueryResult = { rowCount: number; rows: any[] };

describe('RiskService', () => {
  const buildService = (impl: (...args: any[]) => Promise<QueryResult>) => {
    const pg = {
      query: jest.fn(impl)
    };
    return {
      service: new RiskService(pg as any),
      pg
    };
  };

  it('normal: checkSmsRateLimit should pass when all counters are fresh', async () => {
    // Arrange
    const { service, pg } = buildService(async (sql: string) => {
      if (sql.includes('select')) {
        return { rowCount: 0, rows: [] };
      }
      return { rowCount: 1, rows: [] };
    });

    // Act
    await service.checkSmsRateLimit('13800000000', '127.0.0.1', 'device-a');

    // Assert
    expect(pg.query).toHaveBeenCalled();
    expect(pg.query.mock.calls.length).toBeGreaterThanOrEqual(8);
  });

  it('boundary: consumePendingSocial should return null for unknown token', async () => {
    // Arrange
    const { service } = buildService(async () => ({ rowCount: 0, rows: [] }));

    // Act
    const result = await service.consumePendingSocial('unknown-token');

    // Assert
    expect(result).toBeNull();
  });

  it('invalid: checkSmsRateLimit should throw SMS_SEND_TOO_FREQUENT when cooldown not reached', async () => {
    // Arrange
    const queue: QueryResult[] = [
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] },
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] },
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] },
      { rowCount: 1, rows: [{ window_start: new Date() }] }
    ];
    const { service } = buildService(async () => queue.shift() || { rowCount: 1, rows: [] });

    // Act
    const run = async () => service.checkSmsRateLimit('13800000000', '127.0.0.1', 'device-a');

    // Assert
    await expect(run()).rejects.toThrow('SMS_SEND_TOO_FREQUENT');
  });

  it('conflict: checkSmsRateLimit should throw RISK_BLOCKED when counter exceeds max in window', async () => {
    // Arrange
    const now = new Date();
    const queue: QueryResult[] = [
      { rowCount: 1, rows: [{ window_start: now, count: 10 }] },
      { rowCount: 1, rows: [] }
    ];
    const { service } = buildService(async () => queue.shift() || { rowCount: 1, rows: [] });

    // Act
    const run = async () => service.checkSmsRateLimit('13800000000', '127.0.0.1', 'device-a');

    // Assert
    await expect(run()).rejects.toThrow('RISK_BLOCKED');
  });

  it('regression: td-20260411-risk-pending-social should be consumable only once', async () => {
    // Arrange
    const { service } = buildService(async () => ({ rowCount: 1, rows: [] }));
    await service.savePendingSocial('token-1', 'HUAWEI', 'uid-1');

    // Act
    const first = await service.consumePendingSocial('token-1');
    const second = await service.consumePendingSocial('token-1');

    // Assert
    expect(first).toEqual({ providerType: 'HUAWEI', providerUid: 'uid-1' });
    expect(second).toBeNull();
  });

  it('combined: should support cooldown check + failure increase + pending token flow together', async () => {
    // Arrange
    const queue: QueryResult[] = [
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] },
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] },
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] },
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] },
      { rowCount: 0, rows: [] },
      { rowCount: 1, rows: [] }
    ];
    const { service } = buildService(async () => queue.shift() || { rowCount: 1, rows: [] });
    await service.savePendingSocial('token-2', 'HUAWEI', 'uid-2');

    // Act
    await service.checkSmsRateLimit('13900000000', '10.0.0.1', 'device-b');
    await service.increaseCodeFailure('13900000000');
    const pending = await service.consumePendingSocial('token-2');

    // Assert
    expect(pending).toEqual({ providerType: 'HUAWEI', providerUid: 'uid-2' });
  });

  it('boundary: checkSmsRateLimit_should_generate_risk_prefixed_counter_id_on_first_insert', async () => {
    // Arrange
    const { service, pg } = buildService(async (sql: string) => {
      if (sql.includes('select')) {
        return { rowCount: 0, rows: [] };
      }
      return { rowCount: 1, rows: [] };
    });

    // Act
    await service.checkSmsRateLimit('13800000001', '127.0.0.2', 'device-risk-prefix');

    // Assert
    const insertCall = pg.query.mock.calls.find((call: unknown[]) => String(call[0]).includes('insert into risk_counter'));
    expect(insertCall).toBeDefined();
    expect(String(insertCall?.[1]?.[0] || '').startsWith('risk_')).toBe(true);
  });
});

