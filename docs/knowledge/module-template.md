# 模块模板（module-template）

> 六个上下文使用同一模板。执行卡按本文件落位文件，不自行调整目录结构。

---

## 一、后端模块目录

```
backend/src/modules/<context>/
├── index.ts
├── api/
│   └── <resource>.routes.ts
├── internal/
│   ├── <resource>.service.ts
│   ├── <resource>.repo.ts
│   └── domain/
│       ├── entities.ts
│       └── rules.ts
└── __tests__/
    ├── <resource>.rules.test.ts
    └── <resource>.service.test.ts
```

上下文代码：`access`、`visit`、`master`、`notify`、`report`、`compliance`。

---

## 二、路由文件模式

```ts
import { Router } from 'express';
import { requireAuth } from '../../../shared/middleware/requireAuth';
import { requirePermission } from '../../../shared/middleware/requirePermission';
import { success, paginated } from '../../../shared/http/envelope';
import { parsePagination } from '../../../shared/http/pagination';
import { asyncHandler } from '../../../shared/http/asyncHandler';
import * as service from '../internal/example.service';

const router = Router();

router.use(requireAuth);

router.get('/', requirePermission('context:resource:read'), asyncHandler(async (req, res) => {
  const pagination = parsePagination(req.query);
  const { items, total } = await service.list(req.query, pagination);
  return paginated(res, items, total, pagination.page, pagination.pageSize);
}));

router.post('/', requirePermission('context:resource:create'), asyncHandler(async (req, res) => {
  const data = await service.create(req.body, req.currentUser);
  return success(res, data, '创建成功');
}));

export default router;
```

规则：
- `export default router`；不写挂载路径。
- `router.use(requireAuth)` 在文件顶部。
- 每个端点显式 `requirePermission`。
- 处理函数用 `asyncHandler` 包装，异常交 `errorHandler`。
- 成功一律走 `success` / `paginated`；不手写 `res.json` 信封。
- 不支持的方法返回 405：在路由文件末尾 `router.all('/:id', ...)` 之前显式处理 DELETE 等。

---

## 三、领域服务模式

```ts
import { withTransaction } from '../../../shared/db/pool';
import { conflict, unprocessable } from '../../../shared/http/errors';
import { writeAudit } from '../../../shared/audit/writeAudit';
import * as repo from './example.repo';

export async function changeStatus(id: string, input: Input, actor: CurrentUser) {
  return withTransaction(async (client) => {
    const row = await repo.findByIdForUpdate(client, id);
    if (!row) throw notFound();
    if (row.status !== '待审核') throw conflict();
    if (!canTransit(row.status, '已通过')) throw conflict();
    const updated = await repo.updateStatus(client, id, '已通过');
    await repo.insertHistory(client, id, row.status, '已通过', actor.id, '审核同意');
    await writeAudit({ /* 最小字段 */ });
    return updated;
  });
}
```

规则：
- 状态迁移先读当前状态，再判允许集，再写。
- 同状态重复操作返回 409。
- 涉及多表写入必须 `withTransaction`。
- 审计在事务内调用；审计失败不阻断业务（`writeAudit` 内部吞错并记日志）。
- 领域纯函数放 `internal/domain/rules.ts`，可直接单测。

---

## 四、门面模式

```ts
// backend/src/modules/<context>/index.ts
export type ExampleDto = { id: string; name: string };
export async function getExample(id: string): Promise<ExampleDto | null> { ... }
```

规则：
- 只导出类型与函数，不导出 router、repo、client、内部常量。
- 门面函数不得返回 DB 行；必须映射为 DTO。
- 跨上下文调用只走门面。

---

## 五、种子文件模式

```
backend/db/seeds/
├── 01-shared.sql
├── 02-master.sql
├── 03-visit.sql
├── 04-notify.sql
└── 05-compliance.sql
```

规则：
- 文件名两位数字前缀。
- 只放 INSERT；`ON CONFLICT DO NOTHING`。
- 跨域锚点逐字取自 `seed-anchors.sql`。
- 领域卡新增夹具放本上下文文件，不新建顶层文件。

---

## 六、迁移文件模式

```
backend/db/migrations/
├── 001-shared.sql
├── 002-master.sql
├── 003-visit.sql
├── 004-notify.sql
└── 005-compliance.sql
```

规则：
- 三位数字前缀。
- 只放 DDL；`IF NOT EXISTS` 保证可重复执行。
- 每文件一个事务由 `runMigrations` 包裹；文件内可写 `BEGIN/COMMIT`。
- 禁止 INSERT。

---

## 七、前端模块目录

```
frontend/src/views/<context>/
├── <PageName>Page.vue
├── routes.ts
└── permissions.ts
```

### `routes.ts`

```ts
import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/example',
    name: 'example',
    component: () => import('./ExamplePage.vue'),
    meta: { layout: 'app', roles: ['admin'], title: '示例页面' },
  },
];

export default routes;
```

规则：
- 路由 `name` 全局唯一。
- `meta.layout` 取 `'app'` / `'h5'` / `'blank'`。
- `meta.roles` 与 `nav/navigation.ts` 一致。
- 不写菜单；菜单只在 `navigation.ts`。

### `permissions.ts`

```ts
export const examplePermissions = {
  list: 'context:resource:read',
  create: 'context:resource:create',
} as const;
```

规则：
- 键为页面内动作，值为权限点逐字。
- 页面按钮显隐读取该常量；服务端仍强制校验。

---

## 八、页面组件模式

```vue
<template>
  <PageHeader title="页面标题" />
  <a-spin :spinning="loading">
    <EmptyState v-if="!loading && items.length === 0" description="暂无数据" />
    <a-table v-else :data-source="items" :columns="columns" :pagination="pagination" @change="onPageChange" />
  </a-spin>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import apiClient from '@/api/client';
import PageHeader from '@/components/PageHeader.vue';
import EmptyState from '@/components/EmptyState.vue';

const loading = ref(false);
const items = ref<Row[]>([]);

async function load() {
  loading.value = true;
  try {
    const response = await apiClient.get('/example');
    items.value = response.data.data.items;
  } catch (error: any) {
    message.error(error.response?.data?.message ?? '数据加载失败，请点击重试');
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>
```

规则：
- Composition API + `<script setup lang="ts">`。
- 读数据一律 `response.data.data`。
- 错误提示优先 `error.response.data.message`。
- 页面不写 `alert` / `confirm`。
- 所有文案逐字取自卡片“用户可见文案清单”。

---

## 九、测试文件模式

```ts
import { describe, it, expect } from 'vitest';
import { canTransit } from '../internal/domain/state-machine';

describe('预约状态机', () => {
  it('已改期不能直接转为已通过', () => {
    expect(canTransit('已改期', '已通过')).toBe(false);
  });
});
```

```ts
import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../../app';

describe('GET /api/v1/example', () => {
  it('未登录返回 401', async () => {
    const app = createApp();
    const res = await request(app).get('/api/v1/example');
    expect(res.status).toBe(401);
    expect(res.body.message).toBe('请先登录');
  });
});
```

规则：
- 规则测试不连数据库。
- 接口测试用 `supertest`，断言状态码、`code`、`message`、`field`。
- 文件路径过滤：`npx vitest run src/modules/<ctx>/__tests__/<file>.test.ts`。

---

## 十、记忆文件

每张卡完成后写 `docs/memory/YYYY-MM-DD/{卡片ID}.md`。首张卡同时创建 `docs/memory/MEMORY.md`。卡片只写自己的文件，不写共享的当日汇总。
