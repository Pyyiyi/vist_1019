<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';
import { PlayCircleOutlined, PlusOutlined, StopOutlined } from '@ant-design/icons-vue';

import apiClient, { snakeToCamelKey } from '@/api/client';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';

type SoftStatus = 'active' | 'inactive';
type Param = {
  configKey: string;
  configValue: string;
  valueType: 'string' | 'number' | 'boolean' | 'json';
  description: string;
  updatedAt: string;
};
type DictionaryItem = {
  id: string;
  dictType: string;
  dictKey: string;
  dictLabel: string;
  sortOrder: number;
  status: SoftStatus;
};

const paramsLoading = ref(true);
const paramsFailed = ref(false);
const params = ref<Param[]>([]);
const paramDrafts = reactive<Record<string, string>>({});
const savingKey = ref('');

const dictionaryLoading = ref(true);
const dictionaryFailed = ref(false);
const dictionaryItems = ref<DictionaryItem[]>([]);

const formOpen = ref(false);
const formSubmitting = ref(false);
const fieldErrors = reactive<Record<string, string>>({});
const dictForm = reactive({ dictType: '', dictKey: '', dictLabel: '', sortOrder: 0 });

const statusDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);
const statusTarget = ref<DictionaryItem | null>(null);
const statusNext = ref<SoftStatus>('inactive');
const statusSubmitting = ref(false);

const paramColumns = [
  { title: '参数键', dataIndex: 'configKey', key: 'configKey', width: 250, ellipsis: true },
  { title: '参数值', dataIndex: 'configValue', key: 'configValue', width: 240 },
  { title: '类型', dataIndex: 'valueType', key: 'valueType', width: 100 },
  { title: '说明', dataIndex: 'description', key: 'description', ellipsis: true },
  { title: '操作', key: 'actions', width: 92, fixed: 'right' as const },
];
const dictionaryColumns = [
  { title: '字典类型', dataIndex: 'dictType', key: 'dictType', width: 140, ellipsis: true },
  { title: '字典键', dataIndex: 'dictKey', key: 'dictKey', width: 140, ellipsis: true },
  { title: '字典名称', dataIndex: 'dictLabel', key: 'dictLabel', ellipsis: true },
  { title: '排序', dataIndex: 'sortOrder', key: 'sortOrder', width: 90 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 92, fixed: 'right' as const },
];

const statusTitle = computed(() => statusNext.value === 'inactive' ? '确认停用' : '确认启用');
const statusContent = computed(() => statusNext.value === 'inactive' ? '停用后该数据不再出现在新增下拉中，历史记录保留。可再次启用。是否继续？' : '启用后该数据将重新出现在新增下拉中。是否继续？');

async function loadParams(): Promise<void> {
  paramsLoading.value = true;
  paramsFailed.value = false;
  try {
    const response = await apiClient.get('/system/params');
    params.value = response.data.data.items as Param[];
    Object.keys(paramDrafts).forEach((key) => delete paramDrafts[key]);
    params.value.forEach((item) => { paramDrafts[item.configKey] = item.configValue; });
  } catch {
    paramsFailed.value = true;
  } finally {
    paramsLoading.value = false;
  }
}

async function loadDictionary(): Promise<void> {
  dictionaryLoading.value = true;
  dictionaryFailed.value = false;
  try {
    const response = await apiClient.get('/system/dictionary', { params: { include_inactive: true } });
    dictionaryItems.value = response.data.data.items as DictionaryItem[];
  } catch {
    dictionaryFailed.value = true;
  } finally {
    dictionaryLoading.value = false;
  }
}

async function saveParam(item: Param): Promise<void> {
  if (savingKey.value) return;
  savingKey.value = item.configKey;
  try {
    await apiClient.put(`/system/params/${item.configKey}`, {
      configValue: paramDrafts[item.configKey] ?? '',
    });
    message.success('参数已保存，立即生效');
    await loadParams();
  } catch (error) {
    const text = (error as { response?: { data?: { message?: string } } }).response?.data?.message;
    message.error(text ?? '系统暂时无法处理，请稍后重试');
  } finally {
    savingKey.value = '';
  }
}

function openCreate(): void {
  dictForm.dictType = '';
  dictForm.dictKey = '';
  dictForm.dictLabel = '';
  dictForm.sortOrder = 0;
  Object.keys(fieldErrors).forEach((key) => delete fieldErrors[key]);
  formOpen.value = true;
}

function validateDictionaryForm(): boolean {
  Object.keys(fieldErrors).forEach((key) => delete fieldErrors[key]);
  if (!dictForm.dictType.trim()) fieldErrors.dictType = '请输入字典类型';
  if (!dictForm.dictKey.trim()) fieldErrors.dictKey = '请输入字典键';
  if (!dictForm.dictLabel.trim()) fieldErrors.dictLabel = '请输入字典名称';
  return Object.keys(fieldErrors).length === 0;
}

async function submitDictionary(): Promise<void> {
  if (formSubmitting.value || !validateDictionaryForm()) return;
  formSubmitting.value = true;
  try {
    await apiClient.post('/system/dictionary', {
      dictType: dictForm.dictType.trim(),
      dictKey: dictForm.dictKey.trim(),
      dictLabel: dictForm.dictLabel.trim(),
      sortOrder: dictForm.sortOrder,
    });
    message.success('字典项已新增');
    formOpen.value = false;
    await loadDictionary();
  } catch (error) {
    const data = (error as { response?: { data?: { message?: string; field?: string } } }).response?.data;
    const text = data?.message ?? '系统暂时无法处理，请稍后重试';
    if (data?.field) fieldErrors[snakeToCamelKey(data.field)] = text; else message.error(text);
  } finally {
    formSubmitting.value = false;
  }
}

function openStatus(item: DictionaryItem): void {
  statusTarget.value = item;
  statusNext.value = item.status === 'active' ? 'inactive' : 'active';
  statusDialog.value?.openDialog();
}

async function confirmStatus(): Promise<void> {
  const target = statusTarget.value;
  if (!target || statusSubmitting.value) return;
  statusSubmitting.value = true;
  try {
    await apiClient.put(`/system/dictionary/${target.id}/status`, { status: statusNext.value });
    message.success(statusNext.value === 'inactive' ? '已停用' : '已启用');
    await loadDictionary();
  } catch (error) {
    const text = (error as { response?: { data?: { message?: string } } }).response?.data?.message;
    message.error(text ?? '系统暂时无法处理，请稍后重试');
  } finally {
    statusSubmitting.value = false;
  }
}

onMounted(() => { void Promise.allSettled([loadParams(), loadDictionary()]); });
</script>

<template>
  <div class="settings-page">
    <PageHeader title="参数与字典" />

    <a-card class="settings-section" :bordered="false">
      <template #title>系统参数</template>
      <LoadingState v-if="paramsLoading" />
      <ErrorState v-else-if="paramsFailed" @retry="loadParams" />
      <EmptyState v-else-if="params.length === 0" description="暂无数据" />
      <a-table v-else row-key="configKey" :columns="paramColumns" :data-source="params" :pagination="false" :scroll="{ x: 920 }">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'configKey'"><a-tooltip :title="record.configKey"><span class="single-line code-text">{{ record.configKey }}</span></a-tooltip></template>
          <template v-else-if="column.key === 'configValue'"><a-input v-model:value="paramDrafts[record.configKey]" :aria-label="`${record.configKey} 的参数值`" /></template>
          <template v-else-if="column.key === 'description'"><a-tooltip :title="record.description"><span class="single-line">{{ record.description }}</span></a-tooltip></template>
          <template v-else-if="column.key === 'actions'"><a-button type="primary" size="small" :loading="savingKey === record.configKey" :disabled="savingKey === record.configKey" @click="saveParam(record)">保存</a-button></template>
        </template>
      </a-table>
    </a-card>

    <a-card class="settings-section" :bordered="false">
      <template #title>数据字典</template>
      <template #extra><a-button type="primary" aria-label="新增字典项" @click="openCreate"><template #icon><PlusOutlined /></template>新增</a-button></template>
      <LoadingState v-if="dictionaryLoading" />
      <ErrorState v-else-if="dictionaryFailed" @retry="loadDictionary" />
      <EmptyState v-else-if="dictionaryItems.length === 0" description="暂无数据" />
      <a-table v-else row-key="id" :columns="dictionaryColumns" :data-source="dictionaryItems" :pagination="false" :scroll="{ x: 760 }">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'dictType'"><a-tooltip :title="record.dictType"><span class="single-line">{{ record.dictType }}</span></a-tooltip></template>
          <template v-else-if="column.key === 'dictKey'"><a-tooltip :title="record.dictKey"><span class="single-line code-text">{{ record.dictKey }}</span></a-tooltip></template>
          <template v-else-if="column.key === 'dictLabel'"><a-tooltip :title="record.dictLabel"><span class="single-line">{{ record.dictLabel }}</span></a-tooltip></template>
          <template v-else-if="column.key === 'status'"><StatusTag kind="soft" :status="record.status === 'active' ? '在用' : '停用'" /></template>
          <template v-else-if="column.key === 'actions'"><a-tooltip :title="record.status === 'active' ? '停用' : '启用'"><a-button type="text" class="icon-action" :aria-label="record.status === 'active' ? '停用字典项' : '启用字典项'" @click="openStatus(record)"><StopOutlined v-if="record.status === 'active'" /><PlayCircleOutlined v-else /></a-button></a-tooltip></template>
        </template>
      </a-table>
    </a-card>

    <a-modal v-model:open="formOpen" title="新增字典项" :confirm-loading="formSubmitting" :ok-button-props="{ disabled: formSubmitting }" :mask-closable="false" ok-text="确定" cancel-text="取消" @ok="submitDictionary">
      <div class="settings-form">
        <div class="form-field"><label for="dict-type">字典类型</label><a-input id="dict-type" v-model:value="dictForm.dictType" placeholder="请输入字典类型" /><p v-if="fieldErrors.dictType" class="field-error">{{ fieldErrors.dictType }}</p></div>
        <div class="form-field"><label for="dict-key">字典键</label><a-input id="dict-key" v-model:value="dictForm.dictKey" placeholder="请输入字典键" /><p v-if="fieldErrors.dictKey" class="field-error">{{ fieldErrors.dictKey }}</p></div>
        <div class="form-field"><label for="dict-label">字典名称</label><a-input id="dict-label" v-model:value="dictForm.dictLabel" placeholder="请输入字典名称" /><p v-if="fieldErrors.dictLabel" class="field-error">{{ fieldErrors.dictLabel }}</p></div>
        <div class="form-field"><label for="dict-sort">排序</label><a-input-number id="dict-sort" v-model:value="dictForm.sortOrder" :min="0" class="full-control" /></div>
      </div>
    </a-modal>

    <ConfirmDialog ref="statusDialog" :title="statusTitle" :content="statusContent" :danger="statusNext === 'inactive'" @confirm="confirmStatus" />
  </div>
</template>

<style scoped>
.settings-page { display: flex; min-width: 0; flex-direction: column; gap: var(--space-4); }
.settings-section { min-width: 0; overflow: hidden; }
.settings-section :deep(.ant-card-body) { min-width: 0; }
.settings-section :deep(.ant-table-wrapper) { max-width: 100%; overflow: hidden; }
.single-line { display: block; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.code-text { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 13px; }
.icon-action { display: inline-flex; align-items: center; justify-content: center; min-width: 32px; min-height: 32px; }
.settings-form { display: flex; flex-direction: column; gap: 16px; padding-top: 4px; }
.form-field label { display: block; margin-bottom: 7px; color: var(--color-text-primary); font-weight: 550; }
.full-control { width: 100%; }
.field-error { margin-top: 5px; color: var(--color-error, #ff4d4f); font-size: var(--font-size-sm); }
</style>
