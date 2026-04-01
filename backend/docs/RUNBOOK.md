# 运行手册（单环境生产可用）

## 1. 环境变量
- `DATABASE_URL`
- `JWT_SECRET`
- `AUTH_ACCESS_TTL_SECONDS`
- `AUTH_REFRESH_TTL_SECONDS`
- `SMS_PROVIDER`
- 第三方回调配置：`HUAWEI_*`, `WECHAT_*`, `QQ_*`

## 2. 启动
```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/deploy.ps1
```

## 3. 健康检查
- API: `GET /admin-health`
- Swagger: `/docs`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`

## 4. 告警阈值（首版）
- 5xx 错误率 > 1% 持续 5 分钟
- P95 延迟 > 800ms 持续 10 分钟
- 短信发送失败率 > 3% 持续 10 分钟
- 登录失败率 > 5% 持续 10 分钟

## 5. 备份恢复
```powershell
powershell -ExecutionPolicy Bypass -File backend/scripts/backup.ps1 -OutFile ./backup.sql
powershell -ExecutionPolicy Bypass -File backend/scripts/restore.ps1 -SqlFile ./backup.sql
```

## 6. 事故回滚
1. 停止 backend 写入流量
2. 回滚到上一版镜像或提交
3. 如有数据损坏，按最近快照恢复
4. 恢复后执行登录域冒烟：手机号登录、社交登录、绑定解绑、会话刷新
