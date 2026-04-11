import { HealthController } from '../src/modules/health/health.controller';

describe('unit_test_case_generator_autofill_health_controller', () => {
  it('normal: health_should_return_up_when_db_has_rows', async () => {
    // Arrange
    const pg = {
      query: jest.fn().mockResolvedValue({ rowCount: 1, rows: [{ ok: 1 }] })
    };
    const controller = new HealthController(pg as never);
    // Act
    const result = await controller.health() as { status: string; db: string; timestamp: string };
    // Assert
    expect(result.status).toBe('UP');
    expect(result.db).toBe('UP');
  });

  it('boundary: health_should_return_down_when_db_has_no_rows', async () => {
    // Arrange
    const pg = {
      query: jest.fn().mockResolvedValue({ rowCount: 0, rows: [] })
    };
    const controller = new HealthController(pg as never);
    // Act
    const result = await controller.health() as { db: string };
    // Assert
    expect(result.db).toBe('DOWN');
  });

  it('invalid: health_should_throw_when_pg_query_fails', async () => {
    // Arrange
    const pg = {
      query: jest.fn().mockRejectedValue(new Error('db_fail'))
    };
    const controller = new HealthController(pg as never);
    // Act
    const action = controller.health();
    // Assert
    await expect(action).rejects.toThrow('db_fail');
  });

  it('conflict: health_should_use_fixed_sql_probe', async () => {
    // Arrange
    const pg = {
      query: jest.fn().mockResolvedValue({ rowCount: 1, rows: [{ ok: 1 }] })
    };
    const controller = new HealthController(pg as never);
    // Act
    await controller.health();
    // Assert
    expect(pg.query).toHaveBeenCalledWith('select 1 as ok');
  });

  it('regression: health_should_include_iso_timestamp', async () => {
    // Arrange
    const pg = {
      query: jest.fn().mockResolvedValue({ rowCount: 1, rows: [{ ok: 1 }] })
    };
    const controller = new HealthController(pg as never);
    // Act
    const result = await controller.health() as { timestamp: string };
    // Assert
    expect(/\d{4}-\d{2}-\d{2}T/.test(result.timestamp)).toBe(true);
  });

  it('combined: health_should_keep_shape_with_up_status_and_probe_call', async () => {
    // Arrange
    const pg = {
      query: jest.fn().mockResolvedValue({ rowCount: 2, rows: [{ ok: 1 }, { ok: 1 }] })
    };
    const controller = new HealthController(pg as never);
    // Act
    const result = await controller.health() as { status: string; db: string };
    // Assert
    expect(result).toMatchObject({ status: 'UP', db: 'UP' });
    expect(pg.query).toHaveBeenCalledTimes(1);
  });
});
