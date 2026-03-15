# Travel Domino DDD迁移指南

## 导入路径变更对照表

本指南帮助开发者快速适应DDD架构重构后的导入路径变更。

## Repository访问

### 旧方式（已废弃）
```typescript
import { PlanDao } from '../model/entity/PlanDao';
import { EventDao } from '../model/entity/EventDao';

// 使用
await PlanDao.getPlanById(planId);
await EventDao.getAllEvents(planId);
```

### 新方式（推荐）
```typescript
import { PlanRepositoryImpl } from '../infrastructure/persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../infrastructure/persistence/EventRepositoryImpl';

// 使用
await PlanRepositoryImpl.getPlanById(planId);
await EventRepositoryImpl.getAllEvents(planId);
```

### 类型导入
```typescript
// 旧
import { PlanItem } from '../model/entity/PlanDao';
import { EventFieldUpdate } from '../model/entity/EventDao';

// 新
import { PlanItem } from '../infrastructure/persistence/PlanRepositoryImpl';
import { EventFieldUpdate } from '../infrastructure/persistence/EventRepositoryImpl';
```

## 基础设施服务

### AmapService（高德地图服务）
```typescript
// 旧
import { AmapService } from '../common/utils/AmapService';

// 新
import { AmapService } from '../infrastructure/services/AmapService';
```

### AiService（AI服务）
```typescript
// 旧
import { AiService } from '../common/utils/AiService';

// 新
import { AiService } from '../infrastructure/services/AiService';
```

### HttpRequestHelper（HTTP请求）
```typescript
// 旧
import { HttpRequestHelper } from '../common/utils/HttpRequestHelper';

// 新
import { HttpRequestHelper } from '../infrastructure/adapters/HttpRequestHelper';
```

### NotificationGateway（通知网关）
```typescript
// 旧
import { NotificationGateway } from '../common/utils/NotificationGateway';

// 新
import { NotificationGateway } from '../infrastructure/adapters/NotificationGateway';
```

## 计划导入导出

### PlanJsonTransferService → PlanImportExportService
```typescript
// 旧
import { PlanJsonTransferService, PlanJsonImportCancelToken } from '../common/utils/PlanJsonTransferService';

await PlanJsonTransferService.exportPlanToJson(planId);
await PlanJsonTransferService.importPlanFromJson(jsonString, cancelToken);

// 新
import { PlanImportExportService, PlanJsonImportCancelToken } from '../infrastructure/services/PlanImportExportService';

await PlanImportExportService.exportPlanToJson(planId);
await PlanImportExportService.importPlanFromJson(jsonString, cancelToken);
```

## 完整路径映射表

| 旧路径 | 新路径 | 说明 |
|--------|--------|------|
| `model/entity/PlanDao` | `infrastructure/persistence/PlanRepositoryImpl` | 计划仓储 |
| `model/entity/EventDao` | `infrastructure/persistence/EventRepositoryImpl` | 事件仓储 |
| `common/utils/AmapService` | `infrastructure/services/AmapService` | 高德地图 |
| `common/utils/AiService` | `infrastructure/services/AiService` | AI服务 |
| `common/utils/HttpRequestHelper` | `infrastructure/adapters/HttpRequestHelper` | HTTP适配器 |
| `common/utils/NotificationGateway` | `infrastructure/adapters/NotificationGateway` | 通知适配器 |
| `common/utils/PlanJsonTransferService` | `infrastructure/services/PlanImportExportService` | 导入导出 |

## 最佳实践

### 1. 使用Repository接口（推荐）
```typescript
// 更好的方式：依赖接口而非实现
import type { IEventRepository } from '../domain/ports/IEventRepository';
import { EventRepositoryImpl } from '../infrastructure/persistence/EventRepositoryImpl';

class MyService {
  private eventRepo: IEventRepository = EventRepositoryImpl;

  async getEvents(planId: number) {
    return this.eventRepo.getAllEvents(planId);
  }
}
```

### 2. 避免直接依赖Infrastructure
```typescript
// ❌ 不推荐：Domain层直接依赖Infrastructure
// domain/services/MyDomainService.ets
import { EventRepositoryImpl } from '../../infrastructure/persistence/EventRepositoryImpl';

// ✅ 推荐：Domain层依赖接口
// domain/services/MyDomainService.ets
import type { IEventRepository } from '../ports/IEventRepository';
```

### 3. 新增功能的放置位置

**纯业务逻辑** → `domain/`
```typescript
// 示例：计划验证规则
// domain/validators/PlanValidator.ets
export class PlanValidator {
  static validateTitle(title: string): boolean {
    return title.length > 0 && title.length <= 80;
  }
}
```

**技术实现** → `infrastructure/`
```typescript
// 示例：文件存储服务
// infrastructure/services/FileStorageService.ets
export class FileStorageService {
  static async saveFile(path: string, content: string): Promise<void> {
    // 文件系统操作
  }
}
```

**流程编排** → `viewmodel/`
```typescript
// 示例：创建计划流程
// viewmodel/CreatePlanService.ets
export class CreatePlanService {
  async createPlan(title: string): Promise<number> {
    // 1. 验证（Domain）
    // 2. 保存（Infrastructure）
    // 3. 通知（Infrastructure）
  }
}
```

## 常见问题

### Q: 为什么要改名为PlanImportExportService？
A: 原名PlanJsonTransferService混合了序列化和数据库操作。新架构将序列化逻辑提取到`PlanSerializer`（Domain层），数据库操作放在`PlanImportExportService`（Infrastructure层），职责更清晰。

### Q: 旧代码会报错吗？
A: 不会。所有转发适配器已在阶段5.2删除，但所有引用已在阶段5.1更新。如果遇到导入错误，请参考本文档更新路径。

### Q: 如何判断代码应该放在哪一层？
A:
- 包含if/for/算法但不涉及数据库/网络 → Domain层
- 涉及数据库/网络/文件/第三方SDK → Infrastructure层
- 协调多个服务完成业务流程 → Application层（ViewModel）
- 处理用户交互和UI → Presentation层（Pages）

### Q: 可以跨层调用吗？
A: 严格遵守依赖规则：Presentation → Application → Domain ← Infrastructure。内层不能依赖外层。

## 迁移检查清单

- [ ] 更新所有`PlanDao`导入为`PlanRepositoryImpl`
- [ ] 更新所有`EventDao`导入为`EventRepositoryImpl`
- [ ] 更新`AmapService`导入路径
- [ ] 更新`AiService`导入路径
- [ ] 更新`HttpRequestHelper`导入路径
- [ ] 更新`NotificationGateway`导入路径
- [ ] 更新`PlanJsonTransferService`为`PlanImportExportService`
- [ ] 运行编译验证：`hvigorw assembleHap`
- [ ] 运行功能测试验证

## 获取帮助

如遇到迁移问题，请参考：
- `docs/DDD-STRUCTURE.md` - 架构说明
- Git提交历史 - 查看具体更改示例
