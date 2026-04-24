import { AppConfigService } from '../src/config/app-config.service';
import { PgService } from '../src/config/pg.service';

type MockQueryResult = { rowCount: number; rows: unknown[] };

describe('unit_test_case_generator_autofill_pg_service', () => {
  const ORIGINAL_ENV = process.env;

  beforeEach(() => {
    process.env = {
      ...ORIGINAL_ENV,
      DATABASE_URL: 'postgres://localhost:5432/db'
    };
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  it('normal: pg_service_query_should_proxy_to_pool_query', async () => {
    // Arrange
    const service = new PgService(new AppConfigService());
    const query = jest.fn<Promise<MockQueryResult>, [string, unknown[]]>().mockResolvedValue({ rowCount: 1, rows: [{ ok: 1 }] });
    (service as unknown as { pool: { query: typeof query } }).pool = { query };
    // Act
    const result = await service.query('select 1 as ok', []);
    // Assert
    expect(query).toHaveBeenCalledWith('select 1 as ok', []);
    expect(result.rowCount).toBe(1);
  });

  it('boundary: pg_service_with_transaction_should_commit_on_success', async () => {
    // Arrange
    const service = new PgService(new AppConfigService());
    const clientQuery = jest.fn().mockResolvedValue({ rowCount: 1, rows: [] });
    const release = jest.fn();
    const connect = jest.fn().mockResolvedValue({ query: clientQuery, release });
    (service as unknown as { pool: { connect: typeof connect } }).pool = { connect };
    // Act
    const result = await service.withTransaction(async (query) => {
      await query('select 1');
      return 'ok';
    });
    // Assert
    expect(result).toBe('ok');
    expect(clientQuery).toHaveBeenNthCalledWith(1, 'BEGIN');
    expect(clientQuery).toHaveBeenNthCalledWith(2, 'select 1', []);
    expect(clientQuery).toHaveBeenNthCalledWith(3, 'COMMIT');
    expect(release).toHaveBeenCalledTimes(1);
  });

  it('invalid: pg_service_with_transaction_should_rollback_on_error', async () => {
    // Arrange
    const service = new PgService(new AppConfigService());
    const clientQuery = jest.fn().mockResolvedValue({ rowCount: 1, rows: [] });
    const release = jest.fn();
    const connect = jest.fn().mockResolvedValue({ query: clientQuery, release });
    (service as unknown as { pool: { connect: typeof connect } }).pool = { connect };
    // Act
    const action = service.withTransaction(async () => {
      throw new Error('boom');
    });
    // Assert
    await expect(action).rejects.toThrow('boom');
    expect(clientQuery).toHaveBeenNthCalledWith(1, 'BEGIN');
    expect(clientQuery).toHaveBeenNthCalledWith(2, 'ROLLBACK');
    expect(release).toHaveBeenCalledTimes(1);
  });

  it('conflict: pg_service_with_transaction_should_forward_query_params', async () => {
    // Arrange
    const service = new PgService(new AppConfigService());
    const clientQuery = jest.fn().mockResolvedValue({ rowCount: 1, rows: [] });
    const release = jest.fn();
    const connect = jest.fn().mockResolvedValue({ query: clientQuery, release });
    (service as unknown as { pool: { connect: typeof connect } }).pool = { connect };
    // Act
    await service.withTransaction(async (query) => {
      await query('select $1::int as v', [7]);
      return null;
    });
    // Assert
    expect(clientQuery).toHaveBeenCalledWith('select $1::int as v', [7]);
  });

  it('regression: pg_service_on_module_destroy_should_close_pool', async () => {
    // Arrange
    const service = new PgService(new AppConfigService());
    const end = jest.fn().mockResolvedValue(undefined);
    (service as unknown as { pool: { end: typeof end } }).pool = { end };
    // Act
    await service.onModuleDestroy();
    // Assert
    expect(end).toHaveBeenCalledTimes(1);
  });

  it('combined: pg_service_should_support_query_and_transaction_paths_together', async () => {
    // Arrange
    const service = new PgService(new AppConfigService());
    const query = jest.fn().mockResolvedValue({ rowCount: 2, rows: [{ id: 1 }, { id: 2 }] });
    const clientQuery = jest.fn().mockResolvedValue({ rowCount: 1, rows: [] });
    const release = jest.fn();
    const connect = jest.fn().mockResolvedValue({ query: clientQuery, release });
    (service as unknown as { pool: { query: typeof query; connect: typeof connect } }).pool = { query, connect };
    // Act
    const queryResult = await service.query('select * from t', []);
    await service.withTransaction(async (fn) => {
      await fn('update t set x=$1', [1]);
      return true;
    });
    // Assert
    expect(queryResult.rowCount).toBe(2);
    expect(clientQuery).toHaveBeenCalledWith('update t set x=$1', [1]);
  });

  it('boundary: pg_service_query_should_default_params_to_empty_array_when_omitted', async () => {
    const service = new PgService(new AppConfigService());
    const query = jest.fn<Promise<MockQueryResult>, [string, unknown[]]>().mockResolvedValue({ rowCount: 0, rows: [] });
    (service as unknown as { pool: { query: typeof query } }).pool = { query };

    await service.query('select now()');

    expect(query).toHaveBeenCalledWith('select now()', []);
  });
});
