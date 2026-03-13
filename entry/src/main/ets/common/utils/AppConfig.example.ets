// 文件路径: ets/common/utils/AppConfig.ets
// 说明: 复制本文件为 AppConfig.ets 并填写本地私密密钥。请勿提交真实密钥。
export class AppConfig {
  static readonly AI_API_URL: string = 'https://api.modelarts-maas.com/v2/chat/completions';
  static readonly AI_API_KEY: string = 'REPLACE_WITH_YOUR_AI_API_KEY';

  static readonly AMAP_WEB_API_KEY: string = 'REPLACE_WITH_YOUR_AMAP_WEB_API_KEY';
  static readonly AMAP_SDK_API_KEY: string = 'REPLACE_WITH_YOUR_AMAP_SDK_API_KEY';

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

  static validateAmapSdkConfig(): void {
    if (!AppConfig.AMAP_SDK_API_KEY || AppConfig.AMAP_SDK_API_KEY.trim() === '') {
      throw new Error('AMAP_SDK_API_KEY 未配置，请检查 AppConfig.ets');
    }
  }
}
