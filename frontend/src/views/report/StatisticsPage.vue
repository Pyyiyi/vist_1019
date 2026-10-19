<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import dayjs, { type Dayjs } from 'dayjs';

import apiClient from '@/api/client';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import type { IncidentTypeCount, VisitBucket } from './types';

type Granularity = 'day' | 'week' | 'month';
type DateRange = [Dayjs, Dayjs];

type ChartSegment = {
  key: string;
  type: string;
  count: number;
  x: number;
  y: number;
  width: number;
  height: number;
  color: string;
};

type ChartBar = {
  period: string;
  label: string;
  total: number;
  x: number;
  width: number;
  segments: ChartSegment[];
};

const CHART_WIDTH = 900;
const CHART_HEIGHT = 310;
const MARGIN = { top: 28, right: 24, bottom: 72, left: 58 };
const PLOT_WIDTH = CHART_WIDTH - MARGIN.left - MARGIN.right;
const PLOT_HEIGHT = CHART_HEIGHT - MARGIN.top - MARGIN.bottom;
const COLORS = ['#1677ff', '#13c2c2', '#fa8c16', '#52c41a', '#722ed1', '#eb2f96', '#a0d911'];

const loading = ref(true);
const failed = ref(false);
const buckets = ref<VisitBucket[]>([]);
const incidentTypes = ref<IncidentTypeCount[]>([]);
const timeoutCount = ref(0);
const availableTypes = ref<string[]>([]);
const hiddenTypes = ref<string[]>([]);

const filters = reactive<{
  granularity: Granularity;
  type: string | undefined;
  dateRange: DateRange | undefined;
}>({
  granularity: 'day',
  type: undefined,
  dateRange: undefined,
});

const granularityOptions = [
  { label: '按日', value: 'day' },
  { label: '按周', value: 'week' },
  { label: '按月', value: 'month' },
];

const typeOptions = computed(() =>
  availableTypes.value.map((type) => ({ label: type, value: type })),
);

const incidentColumns = [
  { title: '异常类型', dataIndex: 'type', key: 'type' },
  { title: '数量', dataIndex: 'count', key: 'count', width: 160, align: 'right' },
];

const periods = computed(() => [...new Set(buckets.value.map((item) => item.period))]);
const allTypes = computed(() => [...new Set(buckets.value.map((item) => item.type))]);
const totalVisits = computed(() => buckets.value.reduce((sum, item) => sum + Number(item.count), 0));
const totalIncidents = computed(
  () => incidentTypes.value.reduce((sum, item) => sum + Number(item.count), 0) + timeoutCount.value,
);
const empty = computed(() => totalVisits.value === 0 && totalIncidents.value === 0);

function colorFor(type: string): string {
  const index = Math.max(0, allTypes.value.indexOf(type));
  return COLORS[index % COLORS.length];
}

function isVisible(type: string): boolean {
  return !hiddenTypes.value.includes(type);
}

function toggleType(type: string): void {
  hiddenTypes.value = isVisible(type)
    ? [...hiddenTypes.value, type]
    : hiddenTypes.value.filter((item) => item !== type);
}

function labelForPeriod(period: string): string {
  if (filters.granularity === 'month') return period.slice(0, 7);
  return period.slice(5);
}

const chartBars = computed<ChartBar[]>(() => {
  const visibleTypes = allTypes.value.filter(isVisible);
  const totalsByPeriod = new Map<string, number>();
  for (const period of periods.value) {
    totalsByPeriod.set(
      period,
      buckets.value
        .filter((item) => item.period === period && visibleTypes.includes(item.type))
        .reduce((sum, item) => sum + Number(item.count), 0),
    );
  }
  const maxTotal = Math.max(1, ...totalsByPeriod.values());
  const step = periods.value.length > 0 ? PLOT_WIDTH / periods.value.length : PLOT_WIDTH;
  const barWidth = Math.min(52, step * 0.58);

  return periods.value.map((period, periodIndex) => {
    const x = MARGIN.left + step * periodIndex + (step - barWidth) / 2;
    let cumulative = 0;
    const segments: ChartSegment[] = [];

    for (const type of visibleTypes) {
      const count = Number(
        buckets.value.find((item) => item.period === period && item.type === type)?.count ?? 0,
      );
      const height = (count / maxTotal) * PLOT_HEIGHT;
      const y = MARGIN.top + PLOT_HEIGHT - cumulative - height;
      if (count > 0) {
        segments.push({
          key: `${period}-${type}`,
          type,
          count,
          x,
          y,
          width: barWidth,
          height,
          color: colorFor(type),
        });
      }
      cumulative += height;
    }

    return {
      period,
      label: labelForPeriod(period),
      total: totalsByPeriod.get(period) ?? 0,
      x,
      width: barWidth,
      segments,
    };
  });
});

const yTicks = computed(() => {
  const maxTotal = Math.max(1, ...chartBars.value.map((bar) => bar.total));
  return [0, 0.25, 0.5, 0.75, 1].map((ratio) => {
    const value = Math.round(maxTotal * ratio);
    return {
      value,
      y: MARGIN.top + PLOT_HEIGHT - ratio * PLOT_HEIGHT,
    };
  });
});

function requestParams(): Record<string, unknown> {
  const params: Record<string, unknown> = { granularity: filters.granularity };
  if (filters.type) params.type = filters.type;
  if (filters.dateRange) {
    params.dateFrom = filters.dateRange[0].format('YYYY-MM-DD');
    params.dateTo = filters.dateRange[1].format('YYYY-MM-DD');
  }
  return params;
}

async function load(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const [visitResponse, incidentResponse] = await Promise.all([
      apiClient.get('/stats/visits', { params: requestParams() }),
      apiClient.get('/stats/incidents', { params: requestParams() }),
    ]);
    buckets.value = (visitResponse.data.data.buckets ?? []) as VisitBucket[];
    incidentTypes.value = (incidentResponse.data.data.types ?? []) as IncidentTypeCount[];
    timeoutCount.value = Number(incidentResponse.data.data.timeoutCount ?? 0);
    const responseTypes = [...new Set(buckets.value.map((item) => item.type))];
    if (responseTypes.length > 0) {
      availableTypes.value = [...new Set([...availableTypes.value, ...responseTypes])];
    }
    hiddenTypes.value = hiddenTypes.value.filter((type) => availableTypes.value.includes(type));
  } catch {
    failed.value = true;
    buckets.value = [];
    incidentTypes.value = [];
    timeoutCount.value = 0;
  } finally {
    loading.value = false;
  }
}

function applyFilters(): void {
  void load();
}

function resetFilters(): void {
  filters.granularity = 'day';
  filters.type = undefined;
  filters.dateRange = undefined;
  hiddenTypes.value = [];
  void load();
}

function setGranularity(value: unknown): void {
  filters.granularity = value as Granularity;
  void load();
}

onMounted(load);
</script>

<template>
  <div class="report-page statistics-page">
    <PageHeader title="统计分析" />

    <section class="filter-card page-card report-filters no-print">
      <div class="filter-row">
        <a-segmented
          :value="filters.granularity"
          :options="granularityOptions"
          :disabled="loading"
          @change="setGranularity"
        />
        <a-select
          v-model:value="filters.type"
          allow-clear
          :options="typeOptions"
          :disabled="loading"
          placeholder="全部访客类型"
          class="type-select"
        />
        <a-range-picker v-model:value="filters.dateRange" :disabled="loading" format="YYYY-MM-DD" />
        <a-button type="primary" :loading="loading" :disabled="loading" @click="applyFilters">查询</a-button>
        <a-button :loading="loading" :disabled="loading" @click="resetFilters">重置</a-button>
      </div>
    </section>

    <LoadingState v-if="loading" />
    <ErrorState v-else-if="failed" @retry="load" />
    <EmptyState v-else-if="empty" description="所选时间范围内没有数据" />
    <div v-else class="statistics-grid">
      <section class="chart-card page-card">
        <div class="card-heading">
          <h2>来访量</h2>
          <span>单位：人次</span>
        </div>

        <div class="legend">
          <button
            v-for="type in allTypes"
            :key="type"
            type="button"
            class="legend-item"
            :class="{ muted: !isVisible(type) }"
            @click="toggleType(type)"
          >
            <span class="legend-dot" :style="{ backgroundColor: colorFor(type) }" />
            {{ type }}
          </button>
        </div>

        <svg
          class="visit-chart"
          :viewBox="`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`"
          role="img"
          aria-label="来访量堆叠柱状图"
        >
          <line
            v-for="tick in yTicks"
            :key="tick.value"
            :x1="MARGIN.left"
            :y1="tick.y"
            :x2="CHART_WIDTH - MARGIN.right"
            :y2="tick.y"
            stroke="#e5e7eb"
          />
          <text
            v-for="tick in yTicks"
            :key="`label-${tick.value}`"
            :x="MARGIN.left - 10"
            :y="tick.y + 4"
            text-anchor="end"
            class="axis-label"
          >
            {{ tick.value }}
          </text>
          <text
            :x="18"
            :y="MARGIN.top + PLOT_HEIGHT / 2"
            text-anchor="middle"
            transform="rotate(-90 18 145)"
            class="axis-unit"
          >
            人次
          </text>

          <g v-for="bar in chartBars" :key="bar.period">
            <rect
              v-for="segment in bar.segments"
              :key="segment.key"
              :x="segment.x"
              :y="segment.y"
              :width="segment.width"
              :height="segment.height"
              :fill="segment.color"
            >
              <title>{{ bar.period }} · {{ segment.type }} · {{ segment.count }} 人次</title>
            </rect>
            <text
              :x="bar.x + bar.width / 2"
              :y="MARGIN.top + PLOT_HEIGHT - 8"
              text-anchor="middle"
              class="bar-total"
            >
              {{ bar.total }}
            </text>
            <text
              :x="bar.x + bar.width / 2"
              :y="MARGIN.top + PLOT_HEIGHT + 22"
              text-anchor="end"
              class="axis-label"
              :transform="`rotate(-35 ${bar.x + bar.width / 2} ${MARGIN.top + PLOT_HEIGHT + 22})`"
            >
              {{ bar.label }}
            </text>
          </g>
        </svg>
      </section>

      <section class="incident-card page-card">
        <div class="card-heading"><h2>异常类型分布</h2></div>
        <a-table
          row-key="type"
          size="small"
          :columns="incidentColumns"
          :data-source="incidentTypes"
          :pagination="false"
        />
        <div class="timeout-count">
          <span>超时未离（当前）</span>
          <strong>{{ timeoutCount }}</strong>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.filter-card {
  padding: var(--space-4);
  margin-bottom: var(--space-5);
}

.filter-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.type-select {
  min-width: 180px;
}

.statistics-grid {
  display: grid;
  grid-template-columns: minmax(0, 2fr) minmax(300px, 1fr);
  gap: var(--space-5);
}

.chart-card,
.incident-card {
  padding: var(--space-5);
}

.card-heading {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--space-3);
  margin-bottom: var(--space-4);
}

.card-heading h2 {
  color: var(--color-text-primary);
  font-size: var(--font-size-lg);
  font-weight: 600;
}

.card-heading span {
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

.legend {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-bottom: var(--space-3);
}

.legend-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 8px;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: transparent;
  color: var(--color-text-primary);
  cursor: pointer;
}

.legend-item.muted {
  opacity: 0.38;
}

.legend-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
}

.visit-chart {
  display: block;
  width: 100%;
  min-height: 260px;
}

.axis-label,
.axis-unit,
.bar-total {
  fill: var(--color-text-secondary);
  font-size: 11px;
}

.bar-total {
  fill: var(--color-text-primary);
  font-size: 11px;
  font-weight: 600;
}

.timeout-count {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: var(--space-4);
  margin-top: var(--space-3);
  border-top: 1px solid var(--color-border);
}

.timeout-count strong {
  color: var(--color-error);
  font-size: var(--font-size-xl);
}

@media (max-width: 1100px) {
  .statistics-grid {
    grid-template-columns: 1fr;
  }
}
</style>
