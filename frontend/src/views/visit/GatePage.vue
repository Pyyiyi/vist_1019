<script setup lang="ts">
import { nextTick, onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';

import apiClient from '@/api/client';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';
import { useAuthStore } from '@/stores/auth';
import { formatMinute, formatRange, durationText, responseField, serverMessage } from './helpers';
import type { AppointmentItem, CompanionItem, GateOption, HostOption, IncidentItem, RelationOption, VisitorTypeOption } from './types';

type VerifyResult = { allowed: boolean; reason: string; message: string; mode?: string; appointment?: AppointmentItem };

const authStore = useAuthStore();
const isAdmin = ref(authStore.role === 'admin');
const loading = ref(true);
const failed = ref(false);
const kpi = reactive({ todayAppointments: 0, pendingVerification: 0, onCampus: 0, pendingIncidents: 0 });
const appointments = ref<AppointmentItem[]>([]);
const incidents = ref<IncidentItem[]>([]);
const incidentsLoading = ref(true);
const incidentsFailed = ref(false);
const verifyCode = ref('');
const gateId = ref<string | undefined>(undefined);
const verifying = ref(false);
const admitting = ref(false);
const verifyResult = ref<VerifyResult | null>(null);
const gates = ref<GateOption[]>([]);
const visitorTypes = ref<VisitorTypeOption[]>([]);
const hosts = ref<HostOption[]>([]);
const relations = ref<RelationOption[]>([]);
const incidentTypes = ref<string[]>([]);
const walkInOpen = ref(false);
const walkInSaving = ref(false);
const companionDraft = ref<CompanionItem[]>([]);
const consentSection = ref<HTMLElement | null>(null);
const consentError = ref('');
const incidentOpen = ref(false);
const incidentSaving = ref(false);
const incidentForm = reactive({ code: '', incidentType: '', description: '' });
const dispositionOpen = ref(false);
const dispositionSaving = ref(false);
const dispositionTarget = ref<IncidentItem | null>(null);
const dispositionForm = reactive({ status: '已处理', dispositionNote: '' });
const walkIn = reactive({ visitorName: '', visitorPhone: '', visitorIdNo: '', visitorTypeId: undefined as string | undefined, hostId: undefined as string | undefined, gateId: undefined as string | undefined, reason: '', plateNo: '', safety: false, privacy: false });

const columns = [
  { title: '访客', dataIndex: 'visitorName', key: 'visitorName', width: 110 },
  { title: '找谁', dataIndex: 'hostName', key: 'hostName', width: 110 },
  { title: '进校时刻', key: 'checkinAt', width: 160 },
  { title: '离校时刻', key: 'checkoutAt', width: 160 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 135 },
  { title: '已在校时长', key: 'duration', width: 130 },
  { title: '操作', key: 'actions', width: 130, fixed: 'right' as const },
];
const incidentColumns = [
  { title: '异常类型', dataIndex: 'incidentType', key: 'incidentType', width: 130 },
  { title: '异常说明', dataIndex: 'description', key: 'description', ellipsis: true },
  { title: '状态', dataIndex: 'status', key: 'status', width: 110 },
  { title: '上报时间', key: 'createdAt', width: 160 },
  { title: '操作', key: 'actions', width: 100, fixed: 'right' as const },
];

async function loadToday(): Promise<void> {
  loading.value = true; failed.value = false;
  try {
    const response = await apiClient.get('/gate/today');
    Object.assign(kpi, response.data.data.kpi ?? {});
    appointments.value = (response.data.data.appointments ?? []) as AppointmentItem[];
  } catch { failed.value = true; appointments.value = []; } finally { loading.value = false; }
}

async function loadIncidents(): Promise<void> {
  incidentsLoading.value = true; incidentsFailed.value = false;
  try {
    const response = await apiClient.get('/gate/incidents', { params: { page: 1, pageSize: 20 } });
    incidents.value = (response.data.data.items ?? []) as IncidentItem[];
  } catch { incidentsFailed.value = true; incidents.value = []; } finally { incidentsLoading.value = false; }
}

async function loadOptions(): Promise<void> {
  try {
    const response = await apiClient.get('/gate/form-options');
    gates.value = response.data.data.gates ?? [];
    incidentTypes.value = response.data.data.incidentTypes ?? [];
    relations.value = response.data.data.relations ?? [];
    visitorTypes.value = response.data.data.visitorTypes ?? [];
    hosts.value = response.data.data.hosts ?? [];
  } catch (error) { message.error(serverMessage(error)); }
}

async function verify(): Promise<void> {
  if (!verifyCode.value.trim()) { message.warning('请输入预约编号或 6 位短码'); return; }
  if (!gateId.value) { message.warning('请选择校门'); return; }
  verifying.value = true; verifyResult.value = null;
  try {
    const response = await apiClient.post('/gate/verify', { code: verifyCode.value.trim(), gateId: gateId.value });
    verifyResult.value = response.data.data as VerifyResult;
  } catch (error) { verifyResult.value = { allowed: false, reason: 'failed', message: serverMessage(error) }; } finally { verifying.value = false; }
}

async function admit(): Promise<void> {
  if (!verifyResult.value?.appointment && !verifyCode.value.trim()) return;
  admitting.value = true;
  try {
    const code = verifyResult.value?.appointment?.appointNo ?? verifyCode.value.trim();
    await apiClient.post('/gate/admit', { code, gateId: gateId.value });
    message.success(verifyResult.value?.mode === 'reenter' ? '已登记再次进校' : '已放行，进校时刻已登记');
    verifyResult.value = null; verifyCode.value = '';
    await loadToday();
  } catch (error) { message.error(serverMessage(error)); } finally { admitting.value = false; }
}

async function depart(row: AppointmentItem): Promise<void> {
  try {
    await apiClient.post('/gate/depart', { code: row.appointNo, gateId: gateId.value ?? row.lastGateId ?? gates.value[0]?.id });
    message.success('已登记离校'); await loadToday();
  } catch (error) { message.error(serverMessage(error)); }
}

async function reenter(row: AppointmentItem): Promise<void> {
  try {
    await apiClient.post('/gate/admit', { code: row.appointNo, gateId: gateId.value ?? row.lastGateId ?? gates.value[0]?.id });
    message.success('已登记再次进校'); await loadToday();
  } catch (error) { message.error(serverMessage(error)); }
}

async function intercept(): Promise<void> {
  const code = verifyResult.value?.appointment?.appointNo ?? verifyCode.value.trim();
  try {
    await apiClient.post('/gate/incidents', { code, incidentType: '黑名单命中', description: verifyResult.value?.message ?? '该访客命中安全名单，禁止放行，已记录异常' });
    message.warning('该访客命中安全名单，禁止放行，已记录异常');
    verifyResult.value = null;
    await Promise.all([loadIncidents(), loadToday()]);
  } catch (error) { message.error(serverMessage(error)); }
}

function resetWalkIn(): void {
  Object.assign(walkIn, { visitorName: '', visitorPhone: '', visitorIdNo: '', visitorTypeId: undefined, hostId: undefined, gateId: gateId.value, reason: '', plateNo: '', safety: false, privacy: false });
  companionDraft.value = []; consentError.value = '';
}

function addCompanion(): void {
  if (companionDraft.value.length >= 10) { message.warning('最多添加 10 名随行人员'); return; }
  companionDraft.value.push({ name: '', relation: '', idNo: '' });
}

function validateWalkIn(): boolean {
  if (!walkIn.visitorName.trim()) { message.warning('请输入访客姓名'); return false; }
  if (!/^1\d{10}$/.test(walkIn.visitorPhone.trim())) { message.warning('请输入正确的 11 位手机号'); return false; }
  if (!walkIn.visitorIdNo.trim()) { message.warning('请输入证件号'); return false; }
  if (!walkIn.visitorTypeId) { message.warning('请选择访客类型'); return false; }
  if (!walkIn.hostId) { message.warning('请选择被访人'); return false; }
  if (!walkIn.gateId) { message.warning('请选择校门'); return false; }
  if (!walkIn.reason.trim() || walkIn.reason.trim().length < 2) { message.warning('请填写来访事由'); return false; }
  return true;
}

async function submitWalkIn(): Promise<void> {
  if (walkInSaving.value || !validateWalkIn()) return;
  walkInSaving.value = true; consentError.value = '';
  try {
    await apiClient.post('/gate/walk-in', {
      visitorName: walkIn.visitorName.trim(), visitorPhone: walkIn.visitorPhone.trim(), visitorIdNo: walkIn.visitorIdNo.trim(),
      visitorTypeId: walkIn.visitorTypeId, hostId: walkIn.hostId, gateId: walkIn.gateId,
      reason: walkIn.reason.trim(), plateNo: walkIn.plateNo.trim() || null,
      companions: companionDraft.value.map((item) => ({ name: item.name.trim(), relation: item.relation, idNo: item.idNo.trim() })),
      consent: { safety: walkIn.safety, privacy: walkIn.privacy },
    });
    message.success('现场登记完成，访客已放行'); walkInOpen.value = false; await loadToday();
  } catch (error) {
    const field = responseField(error);
    if (field === 'consent') {
      consentError.value = serverMessage(error); await nextTick();
      consentSection.value?.scrollIntoView({ behavior: 'smooth', block: 'center' }); consentSection.value?.focus();
    } else { message.error(serverMessage(error)); }
  } finally { walkInSaving.value = false; }
}

function openIncident(): void { Object.assign(incidentForm, { code: '', incidentType: '', description: '' }); incidentOpen.value = true; }

async function submitIncident(): Promise<void> {
  if (!incidentForm.incidentType) { message.warning('请选择异常类型'); return; }
  if (!incidentForm.description.trim()) { message.warning('请描述现场情况'); return; }
  incidentSaving.value = true;
  try {
    await apiClient.post('/gate/incidents', { code: incidentForm.code.trim() || undefined, incidentType: incidentForm.incidentType, description: incidentForm.description.trim() });
    message.success('异常已上报'); incidentOpen.value = false; await Promise.all([loadIncidents(), loadToday()]);
  } catch (error) { message.error(serverMessage(error)); } finally { incidentSaving.value = false; }
}

function openDisposition(row: IncidentItem): void { dispositionTarget.value = row; dispositionForm.status = '已处理'; dispositionForm.dispositionNote = ''; dispositionOpen.value = true; }

async function submitDisposition(): Promise<void> {
  if (!dispositionTarget.value) return;
  if (!dispositionForm.dispositionNote.trim()) { message.warning('请填写处置说明'); return; }
  dispositionSaving.value = true;
  try {
    await apiClient.put(`/gate/incidents/${dispositionTarget.value.id}/disposition`, dispositionForm);
    message.success('异常已处置'); dispositionOpen.value = false; await Promise.all([loadIncidents(), loadToday()]);
  } catch (error) { message.error(serverMessage(error)); } finally { dispositionSaving.value = false; }
}

onMounted(async () => { await Promise.all([loadToday(), loadIncidents(), loadOptions()]); });
</script>

<template>
  <section>
    <PageHeader title="门卫核验放行">
      <template #actions><a-button @click="openIncident">上报异常</a-button><a-button type="primary" @click="resetWalkIn(); walkInOpen = true">无预约 · 现场登记</a-button></template>
    </PageHeader>

    <div class="kpi-grid">
      <button class="page-card kpi-card" @click="loadToday"><span>今日预约</span><strong>{{ kpi.todayAppointments }}</strong></button>
      <button class="page-card kpi-card" @click="loadToday"><span>待核验</span><strong>{{ kpi.pendingVerification }}</strong></button>
      <button class="page-card kpi-card" @click="loadToday"><span>在校访客</span><strong>{{ kpi.onCampus }}</strong></button>
      <button class="page-card kpi-card" @click="loadIncidents"><span>异常待处理</span><strong>{{ kpi.pendingIncidents }}</strong></button>
    </div>

    <div class="page-card verify-card">
      <h2>现场核验</h2>
      <a-form layout="vertical">
        <div class="verify-grid">
          <a-form-item label="预约编号 / 6 位短码"><a-input v-model:value="verifyCode" placeholder="请扫描二维码或输入预约编号、6 位短码" allow-clear @pressEnter="verify" /></a-form-item>
          <a-form-item label="核验校门"><a-select v-model:value="gateId" placeholder="请选择校门" :options="gates.map((item) => ({ label: item.name, value: item.id }))" /></a-form-item>
          <a-form-item><a-button type="primary" :loading="verifying" @click="verify">{{ verifying ? '正在核验...' : '核验' }}</a-button></a-form-item>
        </div>
      </a-form>

      <div v-if="verifyResult" class="result-card" :class="{ blocked: !verifyResult.allowed }">
        <template v-if="verifyResult.allowed">
          <a-alert type="success" show-icon message="核验通过，可以放行" />
          <div v-if="verifyResult.appointment" class="result-details">
            <p><span>姓名</span><strong>{{ verifyResult.appointment.visitorName }}</strong></p>
            <p><span>被访人</span><strong>{{ verifyResult.appointment.hostName }}</strong></p>
            <p><span>到访时段</span><strong>{{ formatRange(verifyResult.appointment.visitStart, verifyResult.appointment.visitEnd) }}</strong></p>
            <p><span>校门</span><strong>{{ gates.find((item) => item.id === gateId)?.name }}</strong></p>
            <p><span>状态</span><StatusTag :status="verifyResult.appointment.status" /></p>
          </div>
          <a-button type="primary" :loading="admitting" @click="admit">{{ verifyResult.mode === 'reenter' ? '再次进校' : '核验并放行' }}</a-button>
        </template>
        <template v-else-if="verifyResult.reason === 'blacklist'">
          <a-alert type="error" show-icon :message="verifyResult.message" />
          <a-button danger :loading="admitting" @click="intercept">拦截放行</a-button>
        </template>
        <template v-else><a-alert type="error" show-icon :message="`核验未通过：${verifyResult.message}`" /></template>
      </div>
    </div>

    <div class="page-card table-card">
      <h2>今日进出</h2>
      <LoadingState v-if="loading" />
      <ErrorState v-else-if="failed" @retry="loadToday" />
      <EmptyState v-else-if="appointments.length === 0" description="今天还没有访客进出记录" />
      <a-table v-else row-key="id" :columns="columns" :data-source="appointments" :pagination="false" :scroll="{ x: 1000 }">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'checkinAt'">{{ formatMinute(record.checkinAt) }}</template>
          <template v-else-if="column.key === 'checkoutAt'">{{ formatMinute(record.checkoutAt) }}</template>
          <template v-else-if="column.key === 'status'"><StatusTag :status="record.status" /></template>
          <template v-else-if="column.key === 'duration'">{{ durationText(record.onCampusMinutes) }}</template>
          <template v-else-if="column.key === 'actions'">
            <a-button v-if="record.status === '已到访(在校中)'" type="link" size="small" @click="depart(record)">离校登记</a-button>
            <a-button v-else-if="record.status === '已离校'" type="link" size="small" @click="reenter(record)">再次进校</a-button>
            <span v-else>—</span>
          </template>
        </template>
      </a-table>
    </div>

    <div class="page-card table-card">
      <div class="section-title-row"><h2>异常记录</h2><a-button @click="openIncident">上报异常</a-button></div>
      <LoadingState v-if="incidentsLoading" />
      <ErrorState v-else-if="incidentsFailed" @retry="loadIncidents" />
      <EmptyState v-else-if="incidents.length === 0" description="暂无异常记录" />
      <a-table v-else row-key="id" :columns="incidentColumns" :data-source="incidents" :pagination="false" :scroll="{ x: 780 }">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'description'"><a-tooltip :title="record.description"><span class="single-line">{{ record.description }}</span></a-tooltip></template>
          <template v-else-if="column.key === 'status'"><StatusTag :status="record.status" kind="incident" /></template>
          <template v-else-if="column.key === 'createdAt'">{{ formatMinute(record.createdAt) }}</template>
          <template v-else-if="column.key === 'actions'">
            <a-button v-if="isAdmin && record.status === '待处理'" type="link" size="small" @click="openDisposition(record)">处置</a-button>
            <span v-else>—</span>
          </template>
        </template>
      </a-table>
    </div>

    <a-modal v-model:open="walkInOpen" title="无预约现场登记" :confirm-loading="walkInSaving" ok-text="登记并放行" cancel-text="取消" width="760px" :mask-closable="false" @ok="submitWalkIn">
      <p class="modal-description">现场登记仅限门卫协助访客完成，提交前需访客确认两份告知</p>
      <a-form layout="vertical">
        <div class="form-grid">
          <a-form-item label="访客姓名"><a-input v-model:value="walkIn.visitorName" placeholder="请输入访客姓名" /></a-form-item>
          <a-form-item label="手机号"><a-input v-model:value="walkIn.visitorPhone" placeholder="请输入 11 位手机号" :maxlength="11" /></a-form-item>
          <a-form-item label="证件号"><a-input v-model:value="walkIn.visitorIdNo" placeholder="请输入身份证号或其他证件号" /></a-form-item>
          <a-form-item label="访客类型"><a-select v-model:value="walkIn.visitorTypeId" placeholder="请选择访客类型" :options="visitorTypes.map((item) => ({ label: item.name, value: item.id }))" /></a-form-item>
          <a-form-item label="被访人"><a-select v-model:value="walkIn.hostId" placeholder="请选择被访教职工" show-search option-filter-prop="label" :options="hosts.map((item) => ({ label: item.name, value: item.id }))" /></a-form-item>
          <a-form-item label="核验校门"><a-select v-model:value="walkIn.gateId" placeholder="请选择校门" :options="gates.map((item) => ({ label: item.name, value: item.id }))" /></a-form-item>
          <a-form-item label="来访事由" class="full-width"><a-textarea v-model:value="walkIn.reason" placeholder="请简要说明来访事由（2–100 字）" :rows="2" /></a-form-item>
          <a-form-item label="车牌号（选填）" class="full-width"><a-input v-model:value="walkIn.plateNo" placeholder="请输入车牌号" /></a-form-item>
        </div>
        <div class="companions-head"><h3>随行人员</h3><a-button @click="addCompanion">添加随行人员</a-button></div>
        <p class="helper">最多添加 10 名随行人员</p>
        <div v-for="(item, index) in companionDraft" :key="index" class="companion-row">
          <a-input v-model:value="item.name" placeholder="请输入随行人员姓名" />
          <a-select v-model:value="item.relation" placeholder="请选择关系" :options="relations.map((item) => ({ label: item.dictLabel, value: item.dictKey }))" />
          <a-input v-model:value="item.idNo" placeholder="请输入随行人员证件号" />
          <a-button danger type="link" @click="companionDraft.splice(index, 1)">移除</a-button>
        </div>
        <section ref="consentSection" class="consent-box" tabindex="-1">
          <h3>安全告知</h3><p>请遵守校园安全管理规定，配合门卫核验，按预约时段进出校园。</p>
          <a-checkbox v-model:checked="walkIn.safety">我已阅读并同意《安全告知》</a-checkbox>
          <h3>个人信息授权告知</h3><p>为完成来访登记与校园安全管理，系统将收集您的姓名、手机号、证件号及随行人员信息，仅用于本次来访管理，并按留存期限处理。</p>
          <a-checkbox v-model:checked="walkIn.privacy">我已阅读并同意《个人信息授权告知》</a-checkbox>
          <a-alert v-if="consentError" type="error" show-icon :message="consentError" class="consent-error" />
        </section>
      </a-form>
    </a-modal>

    <a-modal v-model:open="incidentOpen" title="上报异常" :confirm-loading="incidentSaving" ok-text="提交异常" cancel-text="取消" :mask-closable="false" @ok="submitIncident">
      <a-form layout="vertical">
        <a-form-item label="预约编号 / 短码（选填）"><a-input v-model:value="incidentForm.code" placeholder="请输入预约编号或 6 位短码" /></a-form-item>
        <a-form-item label="异常类型"><a-select v-model:value="incidentForm.incidentType" placeholder="请选择异常类型" :options="incidentTypes.map((item) => ({ label: item, value: item }))" /></a-form-item>
        <a-form-item label="异常说明"><a-textarea v-model:value="incidentForm.description" placeholder="请描述现场情况" :rows="4" /></a-form-item>
      </a-form>
    </a-modal>

    <a-modal v-model:open="dispositionOpen" title="处置异常" :confirm-loading="dispositionSaving" ok-text="确认处置" cancel-text="取消" :mask-closable="false" @ok="submitDisposition">
      <a-form layout="vertical">
        <a-form-item label="处置结果"><a-radio-group v-model:value="dispositionForm.status"><a-radio value="已处理">标记为已处理</a-radio><a-radio value="已忽略">标记为已忽略</a-radio></a-radio-group></a-form-item>
        <a-form-item label="处置说明"><a-textarea v-model:value="dispositionForm.dispositionNote" placeholder="请输入处置说明" :rows="4" /></a-form-item>
      </a-form>
    </a-modal>
  </section>
</template>

<style scoped>
.single-line { display: block; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.kpi-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: var(--space-3); margin-bottom: var(--space-4); }
.kpi-card { display: flex; align-items: center; justify-content: space-between; min-height: 82px; padding: var(--space-4); border: 0; text-align: left; cursor: pointer; }
.kpi-card span { color: var(--color-text-secondary); }
.kpi-card strong { font-size: 28px; }
.verify-card, .table-card { margin-bottom: var(--space-4); padding: var(--space-5); }
.verify-card h2, .table-card h2 { margin-bottom: var(--space-4); font-size: var(--font-size-lg); }
.verify-grid { display: grid; grid-template-columns: 1.5fr 1fr auto; gap: var(--space-3); align-items: end; }
.result-card { display: flex; flex-direction: column; gap: var(--space-4); max-width: 760px; margin-top: var(--space-4); padding: var(--space-4); border: 1px solid var(--color-border); border-radius: var(--radius-card); }
.result-card.blocked { border-color: var(--color-error); }
.result-details { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-2) var(--space-5); }
.result-details p { display: flex; justify-content: space-between; gap: var(--space-3); margin: 0; }
.result-details span { color: var(--color-text-secondary); }
.section-title-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--space-3); }
.modal-description, .helper { color: var(--color-text-secondary); }
.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 var(--space-4); }
.full-width { grid-column: 1 / -1; }
.companions-head { display: flex; align-items: center; justify-content: space-between; }
.companion-row { display: grid; grid-template-columns: 1fr 160px 1fr 64px; gap: var(--space-2); margin-bottom: var(--space-2); }
.consent-box { margin-top: var(--space-4); padding: var(--space-4); border: 1px solid var(--color-border); border-radius: var(--radius-card); outline: none; }
.consent-box h3 { margin: var(--space-3) 0 var(--space-1); }
.consent-box p { color: var(--color-text-secondary); line-height: 1.7; }
.consent-error { margin-top: var(--space-3); }
@media (max-width: 900px) { .kpi-grid, .verify-grid, .form-grid, .companion-row { grid-template-columns: 1fr; } }
</style>
