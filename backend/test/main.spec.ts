type BootstrapMocks = {
  app: {
    useGlobalPipes: jest.Mock;
    useGlobalInterceptors: jest.Mock;
    useGlobalFilters: jest.Mock;
    listen: jest.Mock;
  };
  create: jest.Mock;
  documentBuilderChain: {
    setTitle: jest.Mock;
    setDescription: jest.Mock;
    setVersion: jest.Mock;
    addBearerAuth: jest.Mock;
    build: jest.Mock;
  };
  createDocument: jest.Mock;
  setup: jest.Mock;
};

async function runMainBootstrap(port?: string): Promise<BootstrapMocks> {
  jest.resetModules();

  const app = {
    useGlobalPipes: jest.fn(),
    useGlobalInterceptors: jest.fn(),
    useGlobalFilters: jest.fn(),
    listen: jest.fn().mockResolvedValue(undefined)
  };

  const create = jest.fn().mockResolvedValue(app);

  const documentBuilderChain = {
    setTitle: jest.fn().mockReturnThis(),
    setDescription: jest.fn().mockReturnThis(),
    setVersion: jest.fn().mockReturnThis(),
    addBearerAuth: jest.fn().mockReturnThis(),
    build: jest.fn().mockReturnValue({ openapi: '3.0.0' })
  };

  const createDocument = jest.fn().mockReturnValue({ swagger: true });
  const setup = jest.fn();

  jest.doMock('@nestjs/core', () => ({
    NestFactory: { create }
  }));

  jest.doMock('@nestjs/swagger', () => ({
    DocumentBuilder: jest.fn(() => documentBuilderChain),
    SwaggerModule: {
      createDocument,
      setup
    }
  }));

  if (port === undefined) {
    delete process.env.PORT;
  } else {
    process.env.PORT = port;
  }

  await import('../src/main');
  await new Promise((resolve) => setImmediate(resolve));

  return {
    app,
    create,
    documentBuilderChain,
    createDocument,
    setup
  };
}

describe('unit_test_case_generator_autofill_main_bootstrap', () => {
  const ORIGINAL_ENV = process.env;

  beforeEach(() => {
    process.env = { ...ORIGINAL_ENV };
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  it('normal: bootstrap_should_create_app_and_listen_on_configured_port', async () => {
    // Arrange
    const port = '3100';
    // Act
    const mocks = await runMainBootstrap(port);
    // Assert
    expect(mocks.create).toHaveBeenCalledTimes(1);
    expect(mocks.app.listen).toHaveBeenCalledWith(3100, '0.0.0.0');
  });

  it('boundary: bootstrap_should_use_default_port_when_env_missing', async () => {
    // Arrange
    // Act
    const mocks = await runMainBootstrap(undefined);
    // Assert
    expect(mocks.app.listen).toHaveBeenCalledWith(3000, '0.0.0.0');
  });

  it('invalid: bootstrap_should_forward_nan_when_port_env_is_not_number', async () => {
    // Arrange
    const invalidPort = 'bad_port';
    // Act
    const mocks = await runMainBootstrap(invalidPort);
    // Assert
    expect(Number.isNaN(mocks.app.listen.mock.calls[0][0])).toBe(true);
    expect(mocks.app.listen.mock.calls[0][1]).toBe('0.0.0.0');
  });

  it('conflict: bootstrap_should_register_global_interceptor_and_filter', async () => {
    // Arrange
    // Act
    const mocks = await runMainBootstrap('3200');
    // Assert
    const interceptor = mocks.app.useGlobalInterceptors.mock.calls[0][0] as { constructor?: { name?: string } };
    const filter = mocks.app.useGlobalFilters.mock.calls[0][0] as { constructor?: { name?: string } };
    expect(interceptor?.constructor?.name).toBe('ApiResponseInterceptor');
    expect(filter?.constructor?.name).toBe('AllExceptionsFilter');
  });

  it('regression: bootstrap_should_build_and_setup_swagger_docs', async () => {
    // Arrange
    // Act
    const mocks = await runMainBootstrap('3300');
    // Assert
    expect(mocks.documentBuilderChain.setTitle).toHaveBeenCalledWith('Travel Auth Backend');
    expect(mocks.documentBuilderChain.setDescription).toHaveBeenCalledWith('Unified auth APIs for Travel Domino');
    expect(mocks.documentBuilderChain.setVersion).toHaveBeenCalledWith('1.0.0');
    expect(mocks.documentBuilderChain.addBearerAuth).toHaveBeenCalledTimes(1);
    expect(mocks.createDocument).toHaveBeenCalledTimes(1);
    expect(mocks.setup).toHaveBeenCalledWith('docs', mocks.app, { swagger: true });
  });

  it('combined: bootstrap_should_register_validation_pipe_before_listen', async () => {
    // Arrange
    // Act
    const mocks = await runMainBootstrap('3400');
    // Assert
    const pipe = mocks.app.useGlobalPipes.mock.calls[0][0] as {
      isTransformEnabled?: boolean;
      validatorOptions?: { whitelist?: boolean };
    };
    expect(pipe.isTransformEnabled).toBe(true);
    expect(pipe.validatorOptions?.whitelist).toBe(true);
    expect(mocks.app.listen).toHaveBeenCalledTimes(1);
  });
});
