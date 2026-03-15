# Travel Domino DDD架构文档

## 项目架构概述

Travel Domino采用领域驱动设计(DDD)架构，将代码组织为清晰的分层结构，确保业务逻辑与技术实现解耦。

## 核心原则

1. **依赖方向**：外层依赖内层，内层不依赖外层
2. **职责分离**：每层只关注自己的职责
3. **接口隔离**：通过接口定义层间契约
4. **技术无关**：Domain层不依赖任何技术框架

## 目录结构

```
entry/src/main/ets/
├── domain/                    # 领域层（核心业务逻辑）
│   ├── ports/                 # 接口定义
│   │   ├── IEventRepository.ets
│   │   └── IPlanRepository.ets
│   ├── serializers/           # 序列化逻辑
│   │   └── PlanSerializer.ets
│   ├── policy/                # 业务策略
│   └── timeline/              # 时间线领域服务
│       └── services/
│           ├── TimelineGroupingService.ets
│           ├── TimelineCalculationService.ets
│           └── TimelineConflictResolver.ets
│
├── infrastructure/            # 基础设施层（技术实现）
│   ├── persistence/           # 数据持久化
│   │   ├── EventRepositoryImpl.ets
│   │   └── PlanRepositoryImpl.ets
│   ├── services/              # 外部服务
│   │   ├── AmapService.ets
│   │   ├── AiService.ets
│   │   ├── ArrivalReminderEngine.ets
│   │   └── PlanImportExportService.ets
│   └── adapters/              # 技术适配器
│       ├── HttpRequestHelper.ets
│       └── NotificationGateway.ets
│
├── viewmodel/                 # 应用层（协调业务流程）
│   ├── TimelineViewModel.ets
│   ├── PlanAppService.ets
│   └── internal/
│       ├── PlanPersistenceFacade.ets
│       └── ReminderFacade.ets
│
├── pages/                     # 表现层（UI交互）
│   ├── Index.ets
│   ├── PlanListPage.ets
│   └── components/
│
├── model/                     # 数据模型
│   ├── entity/                # 实体定义
│   └── interface/             # 接口定义
│
└── common/                    # 公共工具
    ├── utils/
    └── constants/
```

## 各层职责

### Domain层（领域层）

**职责**：定义核心业务逻辑和规则

**特点**：
- 不依赖任何外部框架或技术
- 定义Repository接口（ports）
- 包含纯业务逻辑（如PlanSerializer）
- 定义领域服务和策略

**示例**：
- `domain/ports/IEventRepository.ets` - 事件仓储接口
- `domain/serializers/PlanSerializer.ets` - 计划序列化逻辑
- `domain/timeline/services/TimelineGroupingService.ets` - 时间线分组服务
- `domain/timeline/services/TimelineCalculationService.ets` - 时间线计算服务
- `domain/timeline/services/TimelineConflictResolver.ets` - 冲突解决服务

### Infrastructure层（基础设施层）

**职责**：实现技术细节和外部依赖

**特点**：
- 实现Domain层定义的接口
- 处理数据库、网络、文件等技术操作
- 封装第三方服务（高德地图、AI服务）

**示例**：
- `infrastructure/persistence/EventRepositoryImpl.ets` - 事件仓储实现
- `infrastructure/services/AmapService.ets` - 高德地图服务
- `infrastructure/adapters/HttpRequestHelper.ets` - HTTP请求适配器

### Application层（应用层/ViewModel）

**职责**：协调业务流程，连接UI和Domain

**特点**：
- 编排多个领域服务完成用例
- 管理事务和状态
- 不包含业务规则（委托给Domain层）

**示例**：
- `viewmodel/TimelineViewModel.ets` - 时间线视图模型
- `viewmodel/PlanAppService.ets` - 计划应用服务

### Presentation层（表现层）

**职责**：处理用户交互和UI渲染

**特点**：
- 调用ViewModel获取数据
- 处理用户输入
- 渲染UI组件

**示例**：
- `pages/Index.ets` - 主页面
- `pages/PlanListPage.ets` - 计划列表页

## 依赖规则

```
Presentation → Application → Domain ← Infrastructure
```

- ✅ Presentation可以依赖Application
- ✅ Application可以依赖Domain
- ✅ Infrastructure可以依赖Domain（实现接口）
- ❌ Domain不能依赖Infrastructure
- ❌ Domain不能依赖Application
- ❌ 内层不能依赖外层

## 已完成重构清单

### 阶段1：Repository抽象层 ✅
- 创建`IPlanRepository`和`IEventRepository`接口
- 实现`PlanRepositoryImpl`和`EventRepositoryImpl`
- 创建转发适配器保持兼容性

### 阶段2：基础设施服务迁移 ✅
- 迁移`AmapService`到`infrastructure/services/`
- 迁移`AiService`到`infrastructure/services/`
- 迁移`HttpRequestHelper`到`infrastructure/adapters/`
- 迁移`NotificationGateway`到`infrastructure/adapters/`

### 阶段3：拆分TimelineViewModel（部分完成）✅
- 提取`TimelineGroupingService` - 分组展示逻辑（5个方法）
- 提取`TimelineCalculationService` - 时间线计算逻辑（3个方法）
- 提取`TimelineConflictResolver` - 冲突解决逻辑（2个方法）
- TimelineViewModel从3193行减少到2919行（减少274行，8.6%）
- 详见：[Timeline服务文档](./TIMELINE-SERVICES.md)

### 阶段4：拆分PlanJsonTransferService ✅
- 创建`PlanSerializer`（Domain层）- 纯序列化逻辑
- 创建`PlanImportExportService`（Infrastructure层）- 数据库操作
- 职责分离完成

### 阶段5：清理和优化 ✅
- 更新所有依赖文件的导入路径
- 删除7个转发适配器
- 完成架构文档

## 待完成工作

### 进一步优化TimelineViewModel（可选）
- TimelineViewModel当前2919行，已达到可维护水平
- 剩余方法深度耦合私有方法和状态管理
- 建议：保持现状或等待更大规模架构重构

## 最佳实践

1. **新增功能**：优先考虑放在Domain层，保持业务逻辑纯净
2. **技术实现**：放在Infrastructure层，实现Domain接口
3. **流程编排**：放在Application层（ViewModel）
4. **避免跨层调用**：严格遵守依赖规则
5. **接口优先**：通过接口而非具体实现编程

## 参考资源

- [领域驱动设计(DDD)基础](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [清晰架构(Clean Architecture)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
