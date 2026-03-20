// 文件路径: ets/common/utils/AppConfig.template.ets
// 说明：这是配置模板文件，可提交到仓库。
// 使用方式：复制一份为 AppConfig.ets，并填入你本地真实配置。
// 注意：真实的 AppConfig.ets 不要提交到 Git。

export class AppConfig {
  // AI 服务配置
  static readonly AI_API_URL: string = 'https://api.modelarts-maas.com/v2/chat/completions';
  static readonly AI_API_KEY: string = '';

  // 高德 Web API Key（用于地理编码 / 逆地理编码）
  static readonly AMAP_WEB_API_KEY: string = '';

  // 高德 Native SDK Key（用于 MapsInitializer.setApiKey）
  

  // 认证后端配置
  static readonly AUTH_API_BASE_URL: string = 'http://127.0.0.1:3000';
  static readonly AUTH_USE_MOCK: boolean = true;

  static validateAiConfig(): void {
    if (!AppConfig.AI_API_URL || AppConfig.AI_API_URL.trim() === '') {
      throw new Error('AI_API_URL 未配置，请检查 AppConfig.ets');
    }
    if (!AppConfig.AI_API_KEY || AppConfig.AI_API_KEY.trim() === '') {
      throw new Error('AI_API_KEY 未配置，请检查 AppConfig.ets');
    }
  }

  static validateAmapWebConfig(): void {
    if (!AppConfig.AMAP_WEB_API_KEY || AppConfig.AMAP_WEB_API_KEY.trim() === '') {
      throw new Error('AMAP_WEB_API_KEY 未配置，请检查 AppConfig.ets');
    }
  }

  

  static validateAuthConfig(): void {
    if (!AppConfig.AUTH_API_BASE_URL || AppConfig.AUTH_API_BASE_URL.trim() === '') {
      throw new Error('AUTH_API_BASE_URL 未配置，请检查 AppConfig.ets');
    }
  }
}

