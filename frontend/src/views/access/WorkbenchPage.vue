<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { DownloadOutlined, PrinterOutlined } from '@ant-design/icons-vue';
import { message } from 'ant-design-vue';
import { useRouter } from 'vue-router';

import apiClient from '@/api/client';
import CopyButton from '@/components/CopyButton.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import { useAuthStore } from '@/stores/auth';

type WorkbenchTodo = {
  id: string;
  kind: 'review' | 'verify' | 'incident';
  title: string;
  time: string;
  status: string;
  path: string;
};

type WorkbenchSummary = {
  role: string;
  todo: {
    pendingReview: number;
    pendingVerify: number;
    pendingIncident: number;
  };
  kpi: {
    todayAppointments: number;
    onCampus: number;
  };
  unreadCount: number;
  todos: WorkbenchTodo[];
};

type KpiCard = {
  key: string;
  title: string;
  value: number;
  path: string;
  roles: string[];
  tone: string;
};

const router = useRouter();
const authStore = useAuthStore();
const loading = ref(true);
const failed = ref(false);
const summary = ref<WorkbenchSummary | null>(null);
const qrLoading = ref(false);
const qrFailed = ref(false);
const qrDataUrl = ref('');
const entryUrl = ref('');
const downloading = ref(false);

const role = computed(() => authStore.role ?? '');
const displayName = computed(() => authStore.user?.displayName ?? '');
const subtitleCount = computed(() => summary.value?.todo.pendingReview ?? 0);

const kpiCards = computed<KpiCard[]>(() => {
  if (!summary.value) return [];
  return [
    {
      key: 'pending-review',
      title: '待审核',
      value: summary.value.todo.pendingReview,
      path: '/reviews',
      roles: ['admin', 'host'],
      tone: 'review',
    },
    {
      key: 'pending-verify',
      title: '待核验',
      value: summary.value.todo.pendingVerify,
      path: '/gate',
      roles: ['admin', 'guard'],
      tone: 'verify',
    },
    {
      key: 'pending-incident',
      title: '异常待处理',
      value: summary.value.todo.pendingIncident,
      path: '/gate',
      roles: ['admin', 'guard'],
      tone: 'incident',
    },
    {
      key: 'today-appointments',
      title: '今日预约',
      value: summary.value.kpi.todayAppointments,
      path: '/appointments',
      roles: ['admin', 'host'],
      tone: 'today',
    },
    {
      key: 'on-campus',
      title: '在校访客',
      value: summary.value.kpi.onCampus,
      path: '/on-campus',
      roles: ['admin', 'guard'],
      tone: 'campus',
    },
  ].filter((card) => card.roles.includes(role.value));
});

async function loadSummary(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const response = await apiClient.get('/workbench/summary');
    summary.value = response.data.data as WorkbenchSummary;
  } catch {
    summary.value = null;
    failed.value = true;
  } finally {
    loading.value = false;
  }
}

async function loadQr(): Promise<void> {
  if (role.value !== 'admin') return;
  qrLoading.value = true;
  qrFailed.value = false;
  try {
    const response = await apiClient.get('/system/entry-qr');
    qrDataUrl.value = String(response.data.data.qrDataUrl ?? '');
    entryUrl.value = String(response.data.data.entryUrl ?? '');
  } catch {
    qrFailed.value = true;
    qrDataUrl.value = '';
    message.error('二维码生成失败，请重试');
  } finally {
    qrLoading.value = false;
  }
}

async function downloadQr(): Promise<void> {
  if (downloading.value || !qrDataUrl.value) return;
  downloading.value = true;
  try {
    const response = await apiClient.get('/system/entry-qr.png', { responseType: 'blob' });
    const url = URL.createObjectURL(response.data as Blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = '访客入口二维码.png';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  } catch {
    message.error('二维码生成失败，请重试');
  } finally {
    downloading.value = false;
  }
}

function printQr(): void {
  window.print();
}

function openTodo(todo: WorkbenchTodo): void {
  void router.push(todo.path);
}

function openKpi(card: KpiCard): void {
  void router.push(card.path);
}

onMounted(async () => {
  await loadSummary();
  await loadQr();
});
</script>

<template>
  <div class="workbench-page">
    <LoadingState v-if="loading" class="no-print" />
    <ErrorState v-else-if="failed" class="no-print" @retry="loadSummary" />

    <template v-else-if="summary">
      <PageHeader
        class="no-print"
        :title="`您好，${displayName}`"
        :subtitle="`今天有 ${subtitleCount} 条预约等待处理`"
      />

      <div class="workbench-content">
        <div class="workbench-main no-print">
          <section class="kpi-grid" aria-label="工作台指标">
            <button
              v-for="card in kpiCards"
              :key="card.key"
              type="button"
              class="kpi-card"
              :class="`kpi-${card.tone}`"
              @click="openKpi(card)"
            >
              <span class="kpi-title">{{ card.title }}</span>
              <strong class="kpi-value">{{ card.value }}</strong>
              <span class="kpi-arrow" aria-hidden="true">→</span>
            </button>
          </section>

          <section class="todo-card page-card" aria-labelledby="todo-title">
            <div class="card-heading">
              <div>
                <h2 id="todo-title">我的待办</h2>
                <p>聚合待审核、待核验与异常处置事项</p>
              </div>
              <a-tag color="blue">{{ summary.todos.length }}</a-tag>
            </div>

            <EmptyState
              v-if="summary.todos.length === 0"
              description="暂无待办事项"
            />
            <ul v-else class="todo-list">
              <li v-for="todo in summary.todos" :key="`${todo.kind}-${todo.id}`">
                <button type="button" class="todo-item" @click="openTodo(todo)">
                  <span class="todo-dot" :class="`dot-${todo.kind}`" aria-hidden="true" />
                  <span class="todo-copy">
                    <strong>{{ todo.title }}</strong>
                    <span>{{ todo.time }}</span>
                  </span>
                  <a-tag :color="todo.kind === 'incident' ? 'gold' : todo.kind === 'verify' ? 'green' : 'blue'">
                    {{ todo.status }}
                  </a-tag>
                  <span class="todo-arrow" aria-hidden="true">→</span>
                </button>
              </li>
            </ul>
          </section>
        </div>

        <aside v-if="role === 'admin'" class="entry-qr-card page-card">
          <div class="card-heading">
            <div>
              <h2>访客入口二维码</h2>
              <p>访客扫码后可提交来访申请</p>
            </div>
          </div>

          <div class="qr-preview">
            <template v-if="qrLoading">
              <div class="qr-placeholder">正在生成二维码...</div>
            </template>
            <template v-else-if="qrFailed">
              <div class="qr-placeholder qr-error">
                <p>二维码生成失败，请重试</p>
                <a-button type="primary" size="small" @click="loadQr">重试</a-button>
              </div>
            </template>
            <img v-else-if="qrDataUrl" :src="qrDataUrl" alt="访客入口二维码" />
          </div>

          <div class="entry-url-block">
            <span>入口地址</span>
            <code>{{ entryUrl }}</code>
          </div>

          <div class="qr-actions no-print">
            <a-button
              :loading="downloading"
              :disabled="!qrDataUrl"
              @click="downloadQr"
            >
              <template #icon><DownloadOutlined /></template>
              下载 PNG
            </a-button>
            <a-button :disabled="!qrDataUrl" @click="printQr">
              <template #icon><PrinterOutlined /></template>
              打印
            </a-button>
            <CopyButton :text="entryUrl" success-message="入口链接已复制" />
          </div>
        </aside>
      </div>
    </template>
  </div>
</template>

<style scoped>
.workbench-content {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 340px;
  gap: var(--space-6);
  align-items: start;
}

.workbench-main {
  min-width: 0;
}

.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: var(--space-4);
  margin-bottom: var(--space-6);
}

.kpi-card {
  position: relative;
  display: flex;
  min-height: 116px;
  padding: 22px;
  overflow: hidden;
  border: 0;
  border-radius: var(--radius-card);
  background: var(--color-surface);
  box-shadow: var(--shadow-card);
  cursor: pointer;
  text-align: left;
  transition: transform 160ms ease, box-shadow 160ms ease;
}

.kpi-card:hover {
  box-shadow: 0 8px 22px rgba(22, 119, 255, 0.12);
  transform: translateY(-2px);
}

.kpi-card::after {
  position: absolute;
  top: -28px;
  right: -24px;
  width: 88px;
  height: 88px;
  border-radius: 50%;
  background: currentColor;
  content: '';
  opacity: 0.08;
}

.kpi-title {
  color: var(--color-text-secondary);
  font-size: var(--font-size-base);
}

.kpi-value {
  position: absolute;
  bottom: 18px;
  left: 22px;
  color: var(--color-text-primary);
  font-size: 38px;
  font-weight: 700;
  line-height: 1;
}

.kpi-arrow {
  position: absolute;
  right: 18px;
  bottom: 18px;
  font-size: 18px;
}

.kpi-review { color: #1677ff; }
.kpi-verify { color: #52c41a; }
.kpi-incident { color: #faad14; }
.kpi-today { color: #722ed1; }
.kpi-campus { color: #13c2c2; }

.todo-card,
.entry-qr-card {
  padding: var(--space-6);
}

.card-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-3);
}

.card-heading h2 {
  color: var(--color-text-primary);
  font-size: 18px;
  font-weight: 600;
}

.card-heading p {
  margin-top: 4px;
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

.todo-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin: 20px 0 0;
  padding: 0;
  list-style: none;
}

.todo-item {
  display: flex;
  width: 100%;
  min-height: 64px;
  align-items: center;
  gap: 12px;
  padding: 10px 8px;
  border: 0;
  border-radius: 8px;
  background: transparent;
  cursor: pointer;
  text-align: left;
}

.todo-item:hover {
  background: #f5f8ff;
}

.todo-dot {
  width: 9px;
  height: 9px;
  flex: 0 0 auto;
  border-radius: 50%;
}

.dot-review { background: #1677ff; }
.dot-verify { background: #52c41a; }
.dot-incident { background: #faad14; }

.todo-copy {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 3px;
}

.todo-copy strong {
  overflow: hidden;
  font-weight: 550;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.todo-copy span {
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

.todo-arrow {
  color: #a8abb2;
}

.entry-qr-card {
  position: sticky;
  top: calc(var(--layout-header-height) + 24px);
}

.qr-preview {
  display: grid;
  aspect-ratio: 1;
  margin-top: 20px;
  border: 1px dashed var(--color-border);
  border-radius: 10px;
  background: #fafafa;
  place-items: center;
}

.qr-preview img {
  width: min(260px, 88%);
  height: auto;
}

.qr-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 24px;
  color: var(--color-text-secondary);
  text-align: center;
}

.qr-error p {
  color: var(--color-error);
}

.entry-url-block {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-top: 16px;
}

.entry-url-block span {
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

.entry-url-block code {
  overflow-wrap: anywhere;
  color: var(--color-text-primary);
  font-size: var(--font-size-sm);
}

.qr-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 18px;
}

@media (max-width: 1280px) {
  .workbench-content {
    grid-template-columns: minmax(0, 1fr);
  }

  .entry-qr-card {
    position: static;
  }
}
</style>
