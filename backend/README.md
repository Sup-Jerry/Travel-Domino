# Travel Auth Backend

NestJS + PostgreSQL 单体认证服务。

## 快速开始
```bash
cd backend
npm install
npm run start:dev
```

## 依赖环境变量
- `DATABASE_URL`
- `JWT_SECRET`
- `AUTH_ACCESS_TTL_SECONDS`
- `AUTH_REFRESH_TTL_SECONDS`
- `SMS_PROVIDER`
- `HUAWEI_*` `WECHAT_*` `QQ_*`（生产接入时必填）

## 主要接口
- `POST /auth/phone/send-code`
- `POST /auth/phone/login`
- `POST /auth/social/login`
- `POST /auth/social/create-account`
- `POST /auth/social/bind-existing-phone`
- `POST /auth/guest/create`
- `POST /auth/guest/upgrade`
- `POST /auth/session/refresh`
- `GET /auth/me`
- `GET /auth/identities`
- `POST /auth/identities/bind/social`
- `POST /auth/identities/bind/phone`
- `POST /auth/identities/unbind`
- `POST /auth/logout`
- `POST /auth/logout-all`
- `GET /auth/sessions`
- `POST /auth/cancel/request`

## 数据库
初始化 SQL：`migrations/001_init.sql`

## 运维
- 部署：`../docker-compose.auth.yml`
- 运行手册：`docs/RUNBOOK.md`
- TC 跟踪：`docs/TC_TRACE_MATRIX.md`
