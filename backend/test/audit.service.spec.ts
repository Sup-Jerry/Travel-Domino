import { AuditService } from '../src/modules/audit/audit.service';

describe('AuditService', () => {
  const buildService = () => {
    const pg = {
      query: jest.fn().mockResolvedValue({ rowCount: 1, rows: [] })
    };
    return {
      service: new AuditService(pg as any),
      pg
    };
  };

  it('normal: write should insert security log with serialized payload', async () => {
    // Arrange
    const { service, pg } = buildService();
    const payload = { planId: 1, op: 'CREATE' };

    // Act
    await service.write('PLAN_CREATE', 'u_1', payload);

    // Assert
    expect(pg.query).toHaveBeenCalledTimes(1);
    const params = pg.query.mock.calls[0][1];
    expect(params[1]).toBe('u_1');
    expect(params[2]).toBe('PLAN_CREATE');
    expect(params[3]).toBe(JSON.stringify(payload));
  });

  it('boundary: write should allow empty payload object', async () => {
    // Arrange
    const { service, pg } = buildService();

    // Act
    await service.write('EMPTY_PAYLOAD', 'u_2', {});

    // Assert
    const params = pg.query.mock.calls[0][1];
    expect(params[3]).toBe('{}');
  });

  it('invalid: write should propagate pg query rejection', async () => {
    // Arrange
    const pg = {
      query: jest.fn().mockRejectedValue(new Error('db-down'))
    };
    const service = new AuditService(pg as any);

    // Act
    const run = async () => service.write('LOGIN_FAIL', 'u_3', { reason: 'x' });

    // Assert
    await expect(run()).rejects.toThrow('db-down');
  });

  it('conflict: write should keep null userId instead of coercing to string', async () => {
    // Arrange
    const { service, pg } = buildService();

    // Act
    await service.write('ANONYMOUS_ACTION', null, { path: '/guest' });

    // Assert
    const params = pg.query.mock.calls[0][1];
    expect(params[1]).toBeNull();
  });

  it('regression: td-20260411-audit-json should persist nested payload as stringified json', async () => {
    // Arrange
    const { service, pg } = buildService();
    const payload = { a: 1, nested: { b: true, c: ['x', 'y'] } };

    // Act
    await service.write('NESTED', 'u_4', payload);

    // Assert
    const params = pg.query.mock.calls[0][1];
    expect(params[3]).toBe(JSON.stringify(payload));
  });

  it('combined: write should handle multiple actions in sequence', async () => {
    // Arrange
    const { service, pg } = buildService();

    // Act
    await service.write('ACT_1', 'u_1', { idx: 1 });
    await service.write('ACT_2', null, { idx: 2 });
    await service.write('ACT_3', 'u_3', { idx: 3, tags: ['a'] });

    // Assert
    expect(pg.query).toHaveBeenCalledTimes(3);
    const secondParams = pg.query.mock.calls[1][1];
    const thirdParams = pg.query.mock.calls[2][1];
    expect(secondParams[2]).toBe('ACT_2');
    expect(thirdParams[3]).toBe(JSON.stringify({ idx: 3, tags: ['a'] }));
  });
});

