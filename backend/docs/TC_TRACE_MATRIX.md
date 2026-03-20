# 登录域 TC Trace Matrix（模板）

| TC 编号 | 场景 | 接口/页面 | 自动化覆盖 | 结果 | 备注 |
|---|---|---|---|---|---|
| TC-LOGIN-001 | 登录页展示 | LoginPage | 是 | 待执行 | |
| TC-LOGIN-002 | 协议拦截 | LoginPage | 是 | 待执行 | |
| TC-PHONE-001 | 首次手机号注册登录 | POST /auth/phone/login | 是 | 待执行 | |
| TC-PHONE-002 | 老用户手机号登录 | POST /auth/phone/login | 是 | 待执行 | |
| TC-HW-001 | HUAWEI 已绑定直登 | POST /auth/social/login | 否 | 待执行 | 需真实回调 |
| TC-WX-001 | 微信已绑定直登 | POST /auth/social/login | 否 | 待执行 | 需真实回调 |
| TC-QQ-001 | QQ 已绑定直登 | POST /auth/social/login | 否 | 待执行 | 需真实回调 |
| TC-GUEST-003 | 游客升级迁移 | POST /auth/guest/upgrade | 是 | 待执行 | |
| TC-BIND-004 | 绑定冲突阻止 | POST /auth/identities/bind/* | 是 | 待执行 | |
| TC-UNBIND-002 | 最后方式不可解绑 | POST /auth/identities/unbind | 是 | 待执行 | |
| TC-SESSION-003 | refresh 失效回登录 | POST /auth/session/refresh | 是 | 待执行 | |
| TC-RISK-001 | 发送频控 | POST /auth/phone/send-code | 是 | 待执行 | |
| TC-CANCEL-001 | 注销重认证 | POST /auth/cancel/request | 是 | 待执行 | |
