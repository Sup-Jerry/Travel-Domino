# 项目架构说明

## 技术背景
- 项目类型：HarmonyOS / ArkTS
- 领域：旅游规划、时间约束调度、旅行陪伴
- 开发环境：DevEco Studio

## 当前已知分层
- `common/utils`：通用工具层，如配置、HTTP、地图、日期、导航、偏好、数据库辅助
- `model/entity`：实体层与 DAO
- `model/interface`：接口定义与标准结构
- `model/logic`：时间约束、调度、压缩、分配等核心逻辑
- `viewmodel`：页面/视图状态编排与业务联动
- `ui/view`：界面展示层
- `entryability`：应用入口能力

## 修改原则
1. 工具逻辑放工具层，不要把通用逻辑塞进 UI。
2. 数据定义变化要同步检查 Entity / DAO / 调用方。
3. 时间规划规则优先在 logic 或 viewmodel 处理，不要在 UI 层硬编码业务判断。
4. UI 只负责展示与交互，不承担核心调度算法。
5. 优先局部修复，不随意整体改造。
