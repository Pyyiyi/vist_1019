<script setup lang="ts">
import { onMounted, ref } from 'vue';

import apiClient from '@/api/client';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';
import { formatDateTime, formatOnCampusDuration } from './format';
import type { LedgerItem } from './types';

const loading = ref(true);
const failed = ref(false);
const items = ref<LedgerItem[]>([]);

const columns = [
  { title: '访客', key: 'visitor', width: 180 },
  { title: '找谁', dataIndex: 'hostName', key: 'hostName', width: 140 },
  { title: '进校时刻', key: 'checkinAt', width: 180 },
  { title: '已在校时长', key: 'duration', width: 160 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 150 },
];

async function load(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const response = await apiClient.get('/logs/on-campus');
    items.value = (response.data.data.items ?? []) as LedgerItem[];
  } catch {
    failed.value = true;
    items.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="report-page on-campus-page">
    <PageHeader title="在校清单" />

    <LoadingState v-if="loading" />
    <ErrorState v-else-if="failed" @retry="load" />
    <EmptyState v-else-if="items.length === 0" description="当前没有在校访客" />
    <section v-else class="table-card page-card">
      <a-table row-key="appointmentId" :columns="columns" :data-source="items" :pagination="false">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'visitor'">
            <div class="visitor-cell">
              <strong>{{ record.visitorName || '—' }}</strong>
              <span>{{ record.visitorType }}</span>
            </div>
          </template>
          <template v-else-if="column.key === 'checkinAt'">{{ formatDateTime(record.checkinAt) || '—' }}</template>
          <template v-else-if="column.key === 'duration'">{{ formatOnCampusDuration(record.checkinAt) }}</template>
          <template v-else-if="column.key === 'status'"><StatusTag :status="record.status" /></template>
        </template>
      </a-table>
    </section>
  </div>
</template>

<style scoped>
.table-card {
  padding: var(--space-4);
}

.visitor-cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.visitor-cell span {
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}
</style>
