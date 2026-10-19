<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';
import { DeleteOutlined, EditOutlined, PlayCircleOutlined, StopOutlined } from '@ant-design/icons-vue';

import apiClient, { snakeToCamelKey } from '@/api/client';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';

type SoftStatus = 'active' | 'inactive';
type VisitorType = { id: string; code: string; name: string; status: SoftStatus; sortOrder: number };
type BlacklistEntry = { id: string; idNo: string; name: string; reason: string; expireAt: string; status: '有效' | '已过期' | '已删除' };
type TimeRule = { id: string; weekday: number; startTime: string; endTime: string; ruleType: '可预约' | '禁入' };
type Gate = { id: string; code: string; name: string; status: SoftStatus };
type Host = { id: string; name: string; employeeNo: string; department: string; phone: string | null; status: SoftStatus };
type SectionKey = 'visitorTypes' | 'blacklist' | 'timeRules' | 'gates' | 'hosts';
type FormKind = 'visitorType' | 'blacklist' | 'timeRule' | 'gate' | 'host';
type EditableKind = 'visitorType' | 'gate' | 'host';

const loading = reactive<Record<SectionKey, boolean>>({ visitorTypes: true, blacklist: true, timeRules: true, gates: true, hosts: true });
const failed = reactive<Record<SectionKey, boolean>>({ visitorTypes: false, blacklist: false, timeRules: false, gates: false, hosts: false });
const visitorTypes = ref<VisitorType[]>([]);
const blacklist = ref<BlacklistEntry[]>([]);
const timeRules = ref<TimeRule[]>([]);
const gates = ref<Gate[]>([]);
const hosts = ref<Host[]>([]);
const blacklistTotal = ref(0);
const blacklistPage = ref(1);
const blacklistPageSize = ref(20);
const formOpen = ref(false);
const formKind = ref<FormKind>('visitorType');
const formMode = ref<'create' | 'edit'>('create');
const editingId = ref('');
const formSubmitting = ref(false);
const fieldErrors = reactive<Record<string, string>>({});
const form = reactive({ name: '', employeeNo: '', department: '', phone: '', idNo: '', reason: '', expireAt: '', weekday: 1, startTime: '07:00:00', endTime: '18:00:00', ruleType: '可预约' as TimeRule['ruleType'] });
const statusDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);
const statusTarget = ref<{ kind: EditableKind; id: string; name: string; next: SoftStatus } | null>(null);
const statusSubmitting = ref(false);
const deleteDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);
const deleteTarget = ref<{ kind: 'blacklist' | 'timeRule'; id: string; name: string } | null>(null);
const deleteSubmitting = ref(false);

const weekdayOptions = [
  { value: 1, label: '周一' }, { value: 2, label: '周二' }, { value: 3, label: '周三' },
  { value: 4, label: '周四' }, { value: 5, label: '周五' }, { value: 6, label: '周六' }, { value: 7, label: '周日' },
];
const ruleTypeOptions = [{ value: '可预约', label: '可预约' }, { value: '禁入', label: '禁入' }];
const visitorTypeColumns = [
  { title: '名称', dataIndex: 'name', key: 'name', ellipsis: true },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 132, fixed: 'right' as const },
];
const blacklistColumns = [
  { title: '证件号', dataIndex: 'idNo', key: 'idNo', width: 190, ellipsis: true },
  { title: '姓名', dataIndex: 'name', key: 'name', width: 110, ellipsis: true },
  { title: '原因', dataIndex: 'reason', key: 'reason', ellipsis: true },
  { title: '有效期至', dataIndex: 'expireAt', key: 'expireAt', width: 180 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 88, fixed: 'right' as const },
];
const timeRuleColumns = [
  { title: '星期', dataIndex: 'weekday', key: 'weekday', width: 90 },
  { title: '开始时间', dataIndex: 'startTime', key: 'startTime', width: 120 },
  { title: '结束时间', dataIndex: 'endTime', key: 'endTime', width: 120 },
  { title: '规则类型', dataIndex: 'ruleType', key: 'ruleType', width: 110 },
  { title: '操作', key: 'actions', width: 100, fixed: 'right' as const },
];
const gateColumns = [
  { title: '名称', dataIndex: 'name', key: 'name', ellipsis: true },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 132, fixed: 'right' as const },
];
const hostColumns = [
  { title: '工号', dataIndex: 'employeeNo', key: 'employeeNo', width: 130, ellipsis: true },
  { title: '姓名', dataIndex: 'name', key: 'name', width: 120, ellipsis: true },
  { title: '部门', dataIndex: 'department', key: 'department', ellipsis: true },
  { title: '联系电话', dataIndex: 'phone', key: 'phone', width: 150 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 132, fixed: 'right' as const },
];

const blacklistPagination = computed(() => ({ current: blacklistPage.value, pageSize: blacklistPageSize.value, total: blacklistTotal.value, showSizeChanger: true, pageSizeOptions: ['20', '50', '100'], showTotal: (total: number) => `共 ${total} 条` }));
const statusTitle = computed(() => statusTarget.value?.next === 'inactive' ? '确认停用' : '确认启用');
const statusContent = computed(() => statusTarget.value?.next === 'inactive' ? '停用后该数据不再出现在新增下拉中，历史记录保留。可再次启用。是否继续？' : '启用后该数据将重新出现在新增下拉中。是否继续？');
const deleteTitle = computed(() => deleteTarget.value?.kind === 'blacklist' ? '确认删除黑名单条目' : '确认删除时段规则');
const deleteContent = computed(() => deleteTarget.value?.kind === 'blacklist' ? '删除后该证件号不再被拦截，历史异常记录保留。是否继续？' : '删除后该规则立即失效，不可恢复。是否继续？');
const formTitle = computed(() => {
  const names: Record<FormKind, string> = { visitorType: '访客类型', blacklist: '黑名单', timeRule: '时段规则', gate: '校门与通行点', host: '教职工名册' };
  return `${formMode.value === 'create' ? '新增' : '编辑'}${names[formKind.value]}`;
});

function beginSection(key: SectionKey): void { loading[key] = true; failed[key] = false; }
function endSection(key: SectionKey): void { loading[key] = false; }
async function loadVisitorTypes(): Promise<void> {
  beginSection('visitorTypes');
  try { const response = await apiClient.get('/master/visitor-types', { params: { include_inactive: true } }); visitorTypes.value = response.data.data.items as VisitorType[]; }
  catch { failed.visitorTypes = true; }
  finally { endSection('visitorTypes'); }
}
async function loadBlacklist(): Promise<void> {
  beginSection('blacklist');
  try { const response = await apiClient.get('/master/blacklist', { params: { page: blacklistPage.value, page_size: blacklistPageSize.value } }); blacklist.value = response.data.data.items as BlacklistEntry[]; blacklistTotal.value = Number(response.data.data.total ?? 0); }
  catch { failed.blacklist = true; }
  finally { endSection('blacklist'); }
}
async function loadTimeRules(): Promise<void> {
  beginSection('timeRules');
  try { const response = await apiClient.get('/master/time-rules'); timeRules.value = response.data.data.items as TimeRule[]; }
  catch { failed.timeRules = true; }
  finally { endSection('timeRules'); }
}
async function loadGates(): Promise<void> {
  beginSection('gates');
  try { const response = await apiClient.get('/master/gates', { params: { include_inactive: true } }); gates.value = response.data.data.items as Gate[]; }
  catch { failed.gates = true; }
  finally { endSection('gates'); }
}
async function loadHosts(): Promise<void> {
  beginSection('hosts');
  try { const response = await apiClient.get('/master/hosts', { params: { include_inactive: true } }); hosts.value = response.data.data.items as Host[]; }
  catch { failed.hosts = true; }
  finally { endSection('hosts'); }
}
function loadAll(): void { void Promise.allSettled([loadVisitorTypes(), loadBlacklist(), loadTimeRules(), loadGates(), loadHosts()]); }
function clearFieldErrors(): void { Object.keys(fieldErrors).forEach((key) => delete fieldErrors[key]); }
function resetForm(): void {
  clearFieldErrors(); form.name = ''; form.employeeNo = ''; form.department = ''; form.phone = ''; form.idNo = ''; form.reason = ''; form.expireAt = ''; form.weekday = 1; form.startTime = '07:00:00'; form.endTime = '18:00:00'; form.ruleType = '可预约'; editingId.value = '';
}
function openCreate(kind: FormKind): void { resetForm(); formKind.value = kind; formMode.value = 'create'; formOpen.value = true; }
function openEdit(kind: EditableKind, row: VisitorType | Host | Gate): void {
  resetForm(); formKind.value = kind; formMode.value = 'edit'; editingId.value = row.id; form.name = row.name;
  if (kind === 'host') { const host = row as Host; form.employeeNo = host.employeeNo; form.department = host.department; form.phone = host.phone ?? ''; }
  formOpen.value = true;
}
function validateForm(): boolean {
  clearFieldErrors();
  if (formKind.value === 'visitorType' || formKind.value === 'gate') { if (!form.name.trim()) { fieldErrors.name = '请输入名称'; return false; } }
  if (formKind.value === 'host') { if (!form.name.trim()) fieldErrors.name = '请输入名称'; if (!form.employeeNo.trim()) fieldErrors.employeeNo = '请输入工号'; if (fieldErrors.name || fieldErrors.employeeNo) return false; }
  if (formKind.value === 'blacklist') { if (!form.idNo.trim()) fieldErrors.idNo = '请输入证件号'; if (!form.reason.trim()) fieldErrors.reason = '请输入原因'; if (!form.expireAt) fieldErrors.expireAt = '请选择有效期'; if (fieldErrors.idNo || fieldErrors.reason || fieldErrors.expireAt) return false; }
  if (formKind.value === 'timeRule') { if (!form.startTime) fieldErrors.startTime = '请选择开始时间'; if (!form.endTime) fieldErrors.endTime = '请选择结束时间'; if (form.startTime >= form.endTime) fieldErrors.startTime = '开始时间必须早于结束时间'; if (fieldErrors.startTime || fieldErrors.endTime) return false; }
  return true;
}
async function submitForm(): Promise<void> {
  if (formSubmitting.value || !validateForm()) return;
  formSubmitting.value = true;
  try {
    if (formKind.value === 'visitorType') { if (formMode.value === 'create') await apiClient.post('/master/visitor-types', { name: form.name.trim() }); else await apiClient.put(`/master/visitor-types/${editingId.value}`, { name: form.name.trim() }); await loadVisitorTypes(); }
    else if (formKind.value === 'gate') { if (formMode.value === 'create') await apiClient.post('/master/gates', { name: form.name.trim() }); else await apiClient.put(`/master/gates/${editingId.value}`, { name: form.name.trim() }); await loadGates(); }
    else if (formKind.value === 'host') { const payload = { name: form.name.trim(), employeeNo: form.employeeNo.trim(), department: form.department.trim(), phone: form.phone.trim() }; if (formMode.value === 'create') await apiClient.post('/master/hosts', payload); else await apiClient.put(`/master/hosts/${editingId.value}`, payload); await loadHosts(); }
    else if (formKind.value === 'blacklist') { await apiClient.post('/master/blacklist', { idNo: form.idNo.trim(), name: form.name.trim(), reason: form.reason.trim(), expireAt: form.expireAt }); blacklistPage.value = 1; await loadBlacklist(); }
    else { await apiClient.post('/master/time-rules', { weekday: form.weekday, startTime: form.startTime, endTime: form.endTime, ruleType: form.ruleType }); await loadTimeRules(); }
    message.success(formMode.value === 'create' ? '新增成功' : '保存成功'); formOpen.value = false;
  } catch (error) {
    const data = (error as { response?: { data?: { message?: string; field?: string } } }).response?.data;
    const text = data?.message ?? '系统暂时无法处理，请稍后重试';
    if (data?.field) fieldErrors[snakeToCamelKey(data.field)] = text; else message.error(text);
  } finally { formSubmitting.value = false; }
}
function openStatus(kind: EditableKind, row: VisitorType | Gate | Host): void {
  statusTarget.value = { kind, id: row.id, name: row.name, next: row.status === 'active' ? 'inactive' : 'active' }; statusDialog.value?.openDialog();
}
async function confirmStatus(): Promise<void> {
  const target = statusTarget.value;
  if (!target || statusSubmitting.value) return;
  statusSubmitting.value = true;
  try {
    const routes = { visitorType: `/master/visitor-types/${target.id}/status`, gate: `/master/gates/${target.id}/status`, host: `/master/hosts/${target.id}/status` };
    await apiClient.put(routes[target.kind], { status: target.next }); message.success(target.next === 'inactive' ? '已停用' : '已启用');
    if (target.kind === 'visitorType') await loadVisitorTypes(); if (target.kind === 'gate') await loadGates(); if (target.kind === 'host') await loadHosts();
  } catch (error) { const text = (error as { response?: { data?: { message?: string } } }).response?.data?.message; message.error(text ?? '系统暂时无法处理，请稍后重试'); }
  finally { statusSubmitting.value = false; }
}
function openDelete(kind: 'blacklist' | 'timeRule', row: BlacklistEntry | TimeRule): void {
  deleteTarget.value = { kind, id: row.id, name: 'idNo' in row ? row.idNo : `周${row.weekday} ${row.startTime}-${row.endTime}` }; deleteDialog.value?.openDialog();
}
async function confirmDelete(): Promise<void> {
  const target = deleteTarget.value;
  if (!target || deleteSubmitting.value) return;
  deleteSubmitting.value = true;
  try {
    if (target.kind === 'blacklist') { await apiClient.delete(`/master/blacklist/${target.id}`); if (blacklist.value.length === 1 && blacklistPage.value > 1) blacklistPage.value -= 1; await loadBlacklist(); }
    else { await apiClient.delete(`/master/time-rules/${target.id}`); await loadTimeRules(); }
    message.success('已删除');
  } catch (error) { const text = (error as { response?: { data?: { message?: string } } }).response?.data?.message; message.error(text ?? '系统暂时无法处理，请稍后重试'); }
  finally { deleteSubmitting.value = false; }
}
function restrictedDelete(): void { message.error('该数据不支持删除，请使用停用功能'); }
function onBlacklistChange(pagination: { current?: number; pageSize?: number }): void { blacklistPage.value = pagination.current ?? 1; blacklistPageSize.value = Math.min(pagination.pageSize ?? 20, 100); void loadBlacklist(); }
function weekdayLabel(weekday: number): string { return weekdayOptions.find((item) => item.value === weekday)?.label ?? String(weekday); }
function formatDateTime(value: string): string {
  if (!value) return '—'; const date = new Date(value); if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat('zh-CN', { timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false }).format(date);
}
onMounted(loadAll);
</script>

<template>
  <div class="master-page">
    <PageHeader title="主数据" />
    <a-card class="master-section" :bordered="false"><template #title>访客类型</template><template #extra><a-button type="primary" @click="openCreate('visitorType')">新增</a-button></template>
      <LoadingState v-if="loading.visitorTypes" /><ErrorState v-else-if="failed.visitorTypes" @retry="loadVisitorTypes" /><EmptyState v-else-if="visitorTypes.length === 0" description="暂无数据" />
      <a-table v-else row-key="id" :columns="visitorTypeColumns" :data-source="visitorTypes" :pagination="false" :scroll="{ x: 560 }">
        <template #bodyCell="{ column, record }"><template v-if="column.key === 'name'"><a-tooltip :title="record.name"><span class="single-line">{{ record.name }}</span></a-tooltip></template><template v-else-if="column.key === 'status'"><StatusTag kind="soft" :status="record.status === 'active' ? '在用' : '停用'" /></template><template v-else-if="column.key === 'actions'"><a-space :size="4"><a-tooltip title="编辑"><a-button type="text" class="icon-action" aria-label="编辑访客类型" @click="openEdit('visitorType', record)"><EditOutlined /></a-button></a-tooltip><a-tooltip :title="record.status === 'active' ? '停用' : '启用'"><a-button type="text" class="icon-action" :aria-label="record.status === 'active' ? '停用访客类型' : '启用访客类型'" @click="openStatus('visitorType', record)"><StopOutlined v-if="record.status === 'active'" /><PlayCircleOutlined v-else /></a-button></a-tooltip><a-tooltip title="删除"><a-button type="text" danger class="icon-action" aria-label="删除访客类型" @click="restrictedDelete"><DeleteOutlined /></a-button></a-tooltip></a-space></template></template>
      </a-table>
    </a-card>
    <a-card class="master-section" :bordered="false"><template #title>黑名单</template><template #extra><a-button type="primary" @click="openCreate('blacklist')">新增</a-button></template>
      <LoadingState v-if="loading.blacklist" /><ErrorState v-else-if="failed.blacklist" @retry="loadBlacklist" /><EmptyState v-else-if="blacklist.length === 0" description="暂无数据" />
      <a-table v-else row-key="id" :columns="blacklistColumns" :data-source="blacklist" :pagination="blacklistPagination" :scroll="{ x: 980 }" @change="onBlacklistChange">
        <template #bodyCell="{ column, record }"><template v-if="column.key === 'idNo'"><a-tooltip :title="record.idNo"><span class="single-line">{{ record.idNo }}</span></a-tooltip></template><template v-else-if="column.key === 'name'"><a-tooltip :title="record.name"><span class="single-line">{{ record.name || '—' }}</span></a-tooltip></template><template v-else-if="column.key === 'reason'"><a-tooltip :title="record.reason"><span class="single-line">{{ record.reason }}</span></a-tooltip></template><template v-else-if="column.key === 'expireAt'">{{ formatDateTime(record.expireAt) }}</template><template v-else-if="column.key === 'status'"><a-tag :color="record.status === '有效' ? 'red' : 'default'">{{ record.status }}</a-tag></template><template v-else-if="column.key === 'actions'"><a-tooltip title="删除"><a-button type="text" danger class="icon-action" aria-label="删除黑名单条目" @click="openDelete('blacklist', record)"><DeleteOutlined /></a-button></a-tooltip></template></template>
      </a-table>
    </a-card>
    <a-card class="master-section" :bordered="false"><template #title>时段规则</template><template #extra><a-button type="primary" @click="openCreate('timeRule')">新增</a-button></template>
      <LoadingState v-if="loading.timeRules" /><ErrorState v-else-if="failed.timeRules" @retry="loadTimeRules" /><EmptyState v-else-if="timeRules.length === 0" description="暂无数据" />
      <a-table v-else row-key="id" :columns="timeRuleColumns" :data-source="timeRules" :pagination="false" :scroll="{ x: 620 }"><template #bodyCell="{ column, record }"><template v-if="column.key === 'weekday'">{{ weekdayLabel(record.weekday) }}</template><template v-else-if="column.key === 'startTime'">{{ record.startTime.slice(0, 5) }}</template><template v-else-if="column.key === 'endTime'">{{ record.endTime.slice(0, 5) }}</template><template v-else-if="column.key === 'ruleType'"><a-tag :color="record.ruleType === '禁入' ? 'red' : 'green'">{{ record.ruleType }}</a-tag></template><template v-else-if="column.key === 'actions'"><a-tooltip title="删除规则"><a-button type="text" danger class="icon-action" aria-label="删除时段规则" @click="openDelete('timeRule', record)"><DeleteOutlined /></a-button></a-tooltip></template></template></a-table>
    </a-card>
    <a-card class="master-section" :bordered="false"><template #title>校门与通行点</template><template #extra><a-button type="primary" @click="openCreate('gate')">新增</a-button></template>
      <LoadingState v-if="loading.gates" /><ErrorState v-else-if="failed.gates" @retry="loadGates" /><EmptyState v-else-if="gates.length === 0" description="暂无数据" />
      <a-table v-else row-key="id" :columns="gateColumns" :data-source="gates" :pagination="false" :scroll="{ x: 560 }"><template #bodyCell="{ column, record }"><template v-if="column.key === 'name'"><a-tooltip :title="record.name"><span class="single-line">{{ record.name }}</span></a-tooltip></template><template v-else-if="column.key === 'status'"><StatusTag kind="soft" :status="record.status === 'active' ? '在用' : '停用'" /></template><template v-else-if="column.key === 'actions'"><a-space :size="4"><a-tooltip title="编辑"><a-button type="text" class="icon-action" aria-label="编辑校门" @click="openEdit('gate', record)"><EditOutlined /></a-button></a-tooltip><a-tooltip :title="record.status === 'active' ? '停用' : '启用'"><a-button type="text" class="icon-action" :aria-label="record.status === 'active' ? '停用校门' : '启用校门'" @click="openStatus('gate', record)"><StopOutlined v-if="record.status === 'active'" /><PlayCircleOutlined v-else /></a-button></a-tooltip><a-tooltip title="删除"><a-button type="text" danger class="icon-action" aria-label="删除校门" @click="restrictedDelete"><DeleteOutlined /></a-button></a-tooltip></a-space></template></template></a-table>
    </a-card>
    <a-card class="master-section" :bordered="false"><template #title>教职工名册</template><template #extra><a-button type="primary" @click="openCreate('host')">新增</a-button></template>
      <LoadingState v-if="loading.hosts" /><ErrorState v-else-if="failed.hosts" @retry="loadHosts" /><EmptyState v-else-if="hosts.length === 0" description="暂无数据" />
      <a-table v-else row-key="id" :columns="hostColumns" :data-source="hosts" :pagination="false" :scroll="{ x: 920 }"><template #bodyCell="{ column, record }"><template v-if="column.key === 'employeeNo'"><a-tooltip :title="record.employeeNo"><span class="single-line">{{ record.employeeNo }}</span></a-tooltip></template><template v-else-if="column.key === 'name'"><a-tooltip :title="record.name"><span class="single-line">{{ record.name }}</span></a-tooltip></template><template v-else-if="column.key === 'department'"><a-tooltip :title="record.department"><span class="single-line">{{ record.department || '—' }}</span></a-tooltip></template><template v-else-if="column.key === 'phone'">{{ record.phone || '—' }}</template><template v-else-if="column.key === 'status'"><StatusTag kind="soft" :status="record.status === 'active' ? '在用' : '停用'" /></template><template v-else-if="column.key === 'actions'"><a-space :size="4"><a-tooltip title="编辑"><a-button type="text" class="icon-action" aria-label="编辑教职工" @click="openEdit('host', record)"><EditOutlined /></a-button></a-tooltip><a-tooltip :title="record.status === 'active' ? '停用' : '启用'"><a-button type="text" class="icon-action" :aria-label="record.status === 'active' ? '停用教职工' : '启用教职工'" @click="openStatus('host', record)"><StopOutlined v-if="record.status === 'active'" /><PlayCircleOutlined v-else /></a-button></a-tooltip><a-tooltip title="删除"><a-button type="text" danger class="icon-action" aria-label="删除教职工" @click="restrictedDelete"><DeleteOutlined /></a-button></a-tooltip></a-space></template></template></a-table>
    </a-card>

    <a-modal v-model:open="formOpen" :title="formTitle" :confirm-loading="formSubmitting" :ok-button-props="{ disabled: formSubmitting }" :mask-closable="false" ok-text="确定" cancel-text="取消" @ok="submitForm">
      <div class="master-form">
        <div v-if="formKind === 'visitorType' || formKind === 'gate' || formKind === 'host'" class="form-field"><label for="master-name">名称</label><a-input id="master-name" v-model:value="form.name" placeholder="请输入名称" /><p v-if="fieldErrors.name" class="field-error">{{ fieldErrors.name }}</p></div>
        <template v-if="formKind === 'host'"><div class="form-field"><label for="master-employee-no">工号</label><a-input id="master-employee-no" v-model:value="form.employeeNo" placeholder="请输入工号" /><p v-if="fieldErrors.employeeNo" class="field-error">{{ fieldErrors.employeeNo }}</p></div><div class="form-field"><label for="master-department">部门</label><a-input id="master-department" v-model:value="form.department" placeholder="请输入部门" /></div><div class="form-field"><label for="master-phone">联系电话</label><a-input id="master-phone" v-model:value="form.phone" placeholder="请输入联系电话" /></div></template>
        <template v-if="formKind === 'blacklist'"><div class="form-field"><label for="blacklist-id-no">证件号</label><a-input id="blacklist-id-no" v-model:value="form.idNo" placeholder="请输入证件号" /><p v-if="fieldErrors.idNo" class="field-error">{{ fieldErrors.idNo }}</p></div><div class="form-field"><label for="blacklist-name">姓名</label><a-input id="blacklist-name" v-model:value="form.name" placeholder="请输入姓名" /></div><div class="form-field"><label for="blacklist-reason">原因</label><a-textarea id="blacklist-reason" v-model:value="form.reason" :rows="3" placeholder="请输入原因" /><p v-if="fieldErrors.reason" class="field-error">{{ fieldErrors.reason }}</p></div><div class="form-field"><label for="blacklist-expire-at">有效期至</label><a-date-picker id="blacklist-expire-at" v-model:value="form.expireAt" show-time value-format="YYYY-MM-DDTHH:mm:ssZ" class="full-control" /><p v-if="fieldErrors.expireAt" class="field-error">{{ fieldErrors.expireAt }}</p></div></template>
        <template v-if="formKind === 'timeRule'"><div class="form-field"><label for="rule-weekday">星期</label><a-select id="rule-weekday" v-model:value="form.weekday" :options="weekdayOptions" /></div><div class="form-field"><label for="rule-start">开始时间</label><a-time-picker id="rule-start" v-model:value="form.startTime" value-format="HH:mm:ss" class="full-control" /><p v-if="fieldErrors.startTime" class="field-error">{{ fieldErrors.startTime }}</p></div><div class="form-field"><label for="rule-end">结束时间</label><a-time-picker id="rule-end" v-model:value="form.endTime" value-format="HH:mm:ss" class="full-control" /><p v-if="fieldErrors.endTime" class="field-error">{{ fieldErrors.endTime }}</p></div><div class="form-field"><label for="rule-type">规则类型</label><a-select id="rule-type" v-model:value="form.ruleType" :options="ruleTypeOptions" /></div></template>
      </div>
    </a-modal>
    <ConfirmDialog ref="statusDialog" :title="statusTitle" :content="statusContent" :danger="statusTarget?.next === 'inactive'" @confirm="confirmStatus" />
    <ConfirmDialog ref="deleteDialog" :title="deleteTitle" :content="deleteContent" danger @confirm="confirmDelete" />
  </div>
</template>

<style scoped>
.master-page { display: flex; min-width: 0; flex-direction: column; gap: var(--space-4); }
.master-section { min-width: 0; overflow: hidden; }
.master-section :deep(.ant-card-body) { min-width: 0; }
.master-section :deep(.ant-table-wrapper) { max-width: 100%; overflow: hidden; }
.single-line { display: block; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.icon-action { display: inline-flex; align-items: center; justify-content: center; min-width: 32px; min-height: 32px; }
.master-form { display: flex; flex-direction: column; gap: 16px; padding-top: 4px; }
.form-field label { display: block; margin-bottom: 7px; color: var(--color-text-primary); font-weight: 550; }
.full-control { width: 100%; }
.field-error { margin-top: 5px; color: var(--color-error, #ff4d4f); font-size: var(--font-size-sm); }
</style>
