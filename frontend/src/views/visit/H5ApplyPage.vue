<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';
import dayjs, { type Dayjs } from 'dayjs';
import { useRouter } from 'vue-router';

import apiClient from '@/api/client';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import { responseField, serverMessage } from './helpers';
import type { CompanionItem, VisitFormModel, VisitFormOptions } from './types';

const router = useRouter();
const loading = ref(true);
const failed = ref(false);
const step = ref(0);
const submitting = ref(false);
const completed = ref(false);
const consentError = ref('');
const consentSection = ref<HTMLElement | null>(null);
const formErrors = reactive<Record<string, string>>({});
const startValue = ref<Dayjs | null>(null);
const endValue = ref<Dayjs | null>(null);
const submitted = ref<{ appointNo?: string; shortCode?: string }>({});
const options = ref<VisitFormOptions>({ visitorTypes: [], hosts: [], gates: [], relations: [] });
const form = reactive<VisitFormModel>({
  visitorName: '', visitorPhone: '', visitorIdNo: '', visitorTypeId: undefined, hostId: undefined,
  expectedGateId: undefined, visitStart: null, visitEnd: null, reason: '', plateNo: '', companions: [],
});
const consent = reactive({ safety: false, privacy: false });

const relationOptions = computed(() => options.value.relations.map((item) => ({ label: item.dictLabel, value: item.dictKey })));

function setError(field: string, text: string): false { formErrors[field] = text; return false; }
function validIdNo(value: string): boolean { return /^\d{17}[\dXx]$/.test(value) || /^[A-Za-z0-9]{5,20}$/.test(value); }

function validateStepOne(): boolean {
  Object.keys(formErrors).forEach((key) => delete formErrors[key]);
  if (!form.visitorName.trim()) return setError('visitorName', '请输入访客姓名');
  if (form.visitorName.trim().length > 20) return setError('visitorName', '访客姓名不能超过 20 个字符');
  if (!form.visitorPhone.trim()) return setError('visitorPhone', '请输入手机号');
  if (!/^1\d{10}$/.test(form.visitorPhone.trim())) return setError('visitorPhone', '请输入正确的 11 位手机号');
  if (!form.visitorIdNo.trim()) return setError('visitorIdNo', '请输入证件号');
  if (!validIdNo(form.visitorIdNo.trim())) return setError('visitorIdNo', '请输入正确的 18 位身份证号，或 5–20 位其他证件号');
  if (!form.visitorTypeId) return setError('visitorTypeId', '请选择访客类型');
  if (!form.hostId) return setError('hostId', '请选择被访人');
  if (!startValue.value) return setError('visitStart', '请选择开始时间');
  if (!endValue.value) return setError('visitEnd', '请选择结束时间');
  const start = startValue.value;
  const end = endValue.value;
  if (!end.isAfter(start)) return setError('visitEnd', '结束时间必须晚于开始时间');
  if (!start.isSame(end, 'day')) return setError('visitEnd', '预约必须在同一天内完成');
  const minutes = end.diff(start, 'minute');
  if (minutes < 15) return setError('visitEnd', '到访时段不能少于 15 分钟');
  if (minutes > 240) return setError('visitEnd', '到访时段不能超过 240 分钟');
  if (!start.isAfter(dayjs())) return setError('visitStart', '开始时间必须晚于当前时间');
  if (!form.reason.trim()) return setError('reason', '请填写来访事由');
  if (form.reason.trim().length < 2) return setError('reason', '来访事由至少 2 个字符');
  if (form.reason.trim().length > 100) return setError('reason', '来访事由不能超过 100 个字符');
  for (let index = 0; index < form.companions.length; index += 1) {
    const item = form.companions[index];
    if (!item.name.trim()) return setError(`companions.${index}.name`, '请输入随行人员姓名');
    if (!item.relation) return setError(`companions.${index}.relation`, '请选择与主访客的关系');
    if (!item.idNo.trim() || !validIdNo(item.idNo.trim())) return setError(`companions.${index}.idNo`, '请输入正确的随行人员证件号');
  }
  return true;
}

function next(): void {
  if (step.value === 0 && !validateStepOne()) return;
  step.value = Math.min(2, step.value + 1);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function previous(): void { step.value = Math.max(0, step.value - 1); window.scrollTo({ top: 0, behavior: 'smooth' }); }

function addCompanion(): void {
  if (form.companions.length >= 10) { message.warning('最多添加 10 名随行人员'); return; }
  form.companions.push({ name: '', relation: '', idNo: '' });
}

function payload(): Record<string, unknown> {
  return {
    visitorName: form.visitorName.trim(), visitorPhone: form.visitorPhone.trim(), visitorIdNo: form.visitorIdNo.trim(),
    visitorTypeId: form.visitorTypeId, hostId: form.hostId,
    visitStart: startValue.value!.toISOString(), visitEnd: endValue.value!.toISOString(),
    reason: form.reason.trim(), plateNo: form.plateNo.trim() || null,
    companions: form.companions.map((item) => ({ name: item.name.trim(), relation: item.relation, idNo: item.idNo.trim() })),
    consent: { safety: consent.safety, privacy: consent.privacy },
  };
}

async function submit(): Promise<void> {
  if (submitting.value) return;
  submitting.value = true; consentError.value = '';
  try {
    const response = await apiClient.post('/visitor/appointments', payload());
    submitted.value = { appointNo: response.data.data.appointNo, shortCode: response.data.data.shortCode };
    completed.value = true;
  } catch (error) {
    if (responseField(error) === 'consent') {
      consentError.value = serverMessage(error);
      step.value = 1;
      await nextTick();
      consentSection.value?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      consentSection.value?.focus();
    } else {
      message.error(serverMessage(error));
    }
  } finally { submitting.value = false; }
}

async function loadOptions(): Promise<void> {
  loading.value = true; failed.value = false;
  try {
    const response = await apiClient.get('/visitor/form-options');
    options.value = response.data.data as VisitFormOptions;
  } catch { failed.value = true; } finally { loading.value = false; }
}

onMounted(loadOptions);
</script>

<template>
  <section class="h5-apply-page">
    <header class="h5-title-card">
      <p class="eyebrow">校园访客</p>
      <h1>来访申请</h1>
    </header>

    <LoadingState v-if="loading" />
    <ErrorState v-else-if="failed" @retry="loadOptions" />
    <template v-else>
      <a-steps :current="step" size="small" class="steps" :items="[{ title: '填写信息' }, { title: '阅读告知' }, { title: '提交' }]" />

      <template v-if="!completed">
        <section v-show="step === 0" class="page-card h5-card">
          <a-form layout="vertical">
            <a-form-item label="访客姓名" :help="formErrors.visitorName" :validate-status="formErrors.visitorName ? 'error' : undefined"><a-input v-model:value="form.visitorName" placeholder="请输入访客姓名" /></a-form-item>
            <a-form-item label="手机号" :help="formErrors.visitorPhone" :validate-status="formErrors.visitorPhone ? 'error' : undefined"><a-input v-model:value="form.visitorPhone" placeholder="请输入 11 位手机号" :maxlength="11" inputmode="numeric" /></a-form-item>
            <a-form-item label="证件号" :help="formErrors.visitorIdNo" :validate-status="formErrors.visitorIdNo ? 'error' : undefined"><a-input v-model:value="form.visitorIdNo" placeholder="请输入身份证号或其他证件号" /></a-form-item>
            <a-form-item label="访客类型" :help="formErrors.visitorTypeId" :validate-status="formErrors.visitorTypeId ? 'error' : undefined"><a-select v-model:value="form.visitorTypeId" placeholder="请选择访客类型" :options="options.visitorTypes.map((item) => ({ label: item.name, value: item.id }))" /></a-form-item>
            <a-form-item label="被访人" :help="formErrors.hostId" :validate-status="formErrors.hostId ? 'error' : undefined"><a-select v-model:value="form.hostId" placeholder="请选择被访教职工" show-search option-filter-prop="label" :options="options.hosts.map((item) => ({ label: `${item.name}${item.department ? ' · ' + item.department : ''}`, value: item.id }))" /></a-form-item>
            <a-form-item label="开始时间" :help="formErrors.visitStart" :validate-status="formErrors.visitStart ? 'error' : undefined"><a-date-picker v-model:value="startValue" show-time format="YYYY-MM-DD HH:mm" placeholder="请选择开始时间" style="width: 100%" /></a-form-item>
            <a-form-item label="结束时间" :help="formErrors.visitEnd" :validate-status="formErrors.visitEnd ? 'error' : undefined"><a-date-picker v-model:value="endValue" show-time format="YYYY-MM-DD HH:mm" placeholder="请选择结束时间" style="width: 100%" /></a-form-item>
            <a-form-item label="来访事由" :help="formErrors.reason" :validate-status="formErrors.reason ? 'error' : undefined"><a-textarea v-model:value="form.reason" placeholder="请简要说明来访事由（2–100 字）" :rows="3" /></a-form-item>
            <a-form-item label="车牌号（选填）"><a-input v-model:value="form.plateNo" placeholder="请输入车牌号" /></a-form-item>
          </a-form>
          <div class="companions-head"><h3>随行人员</h3><a-button @click="addCompanion">添加随行人员</a-button></div>
          <p class="helper">最多添加 10 名随行人员</p>
          <div v-for="(item, index) in form.companions" :key="index" class="companion-card">
            <a-input v-model:value="item.name" placeholder="请输入随行人员姓名" />
            <a-select v-model:value="item.relation" placeholder="请选择关系" :options="relationOptions" />
            <a-input v-model:value="item.idNo" placeholder="请输入随行人员证件号" />
            <a-button danger type="link" @click="form.companions.splice(index, 1)">移除</a-button>
            <p v-if="formErrors[`companions.${index}.name`]" class="field-error">{{ formErrors[`companions.${index}.name`] }}</p>
            <p v-if="formErrors[`companions.${index}.relation`]" class="field-error">{{ formErrors[`companions.${index}.relation`] }}</p>
            <p v-if="formErrors[`companions.${index}.idNo`]" class="field-error">{{ formErrors[`companions.${index}.idNo`] }}</p>
          </div>
        </section>

        <section v-show="step === 1" ref="consentSection" class="page-card h5-card consent-card" tabindex="-1">
          <h2>安全告知</h2>
          <p>请遵守校园安全管理规定，配合门卫核验，按预约时段进出校园。</p>
          <a-checkbox v-model:checked="consent.safety" class="consent-check">我已阅读并同意《安全告知》</a-checkbox>
          <a-divider />
          <h2>个人信息授权告知</h2>
          <p>为完成来访登记与校园安全管理，系统将收集您的姓名、手机号、证件号及随行人员信息，仅用于本次来访管理，并按留存期限处理。</p>
          <a-checkbox v-model:checked="consent.privacy" class="consent-check">我已阅读并同意《个人信息授权告知》</a-checkbox>
          <a-alert v-if="consentError" type="error" show-icon :message="consentError" class="consent-alert" />
        </section>

        <section v-show="step === 2" class="page-card h5-card summary-card">
          <h2>申请信息</h2>
          <dl>
            <dt>访客姓名</dt><dd>{{ form.visitorName }}</dd>
            <dt>手机号</dt><dd>{{ form.visitorPhone }}</dd>
            <dt>证件号</dt><dd>{{ form.visitorIdNo }}</dd>
            <dt>被访人</dt><dd>{{ options.hosts.find((item) => item.id === form.hostId)?.name }}</dd>
            <dt>到访时段</dt><dd>{{ startValue?.format('YYYY-MM-DD HH:mm') }}–{{ endValue?.format('HH:mm') }}</dd>
            <dt>来访事由</dt><dd>{{ form.reason }}</dd>
            <dt>随行人员</dt><dd>{{ form.companions.length }} 人</dd>
          </dl>
          <a-alert type="info" show-icon message="请确认以上信息无误后再提交申请" />
        </section>

        <div class="h5-action-bar">
          <a-button v-if="step > 0" @click="previous">上一步</a-button>
          <a-button v-if="step < 2" type="primary" @click="next">下一步</a-button>
          <a-button v-else type="primary" :loading="submitting" :disabled="submitting" @click="submit">{{ submitting ? '正在提交...' : '提交申请' }}</a-button>
        </div>
      </template>

      <section v-else class="page-card h5-card success-card">
        <h2>申请已提交</h2>
        <p>被访人审核通过后，您可凭本页凭证进校。</p>
        <a-button type="primary" block @click="router.push('/h5/my')">查看我的申请</a-button>
      </section>
    </template>
  </section>
</template>

<style scoped>
.h5-apply-page { width: 100%; max-width: 100%; overflow-x: hidden; }
.h5-title-card { margin: -4px -4px 12px; padding: 20px 16px; color: #fff; background: linear-gradient(135deg, #1677ff, #4096ff); border-radius: 0 0 16px 16px; }
.h5-title-card h1 { margin: 4px 0 0; color: #fff; font-size: 24px; }
.eyebrow { margin: 0; opacity: 0.82; }
.steps { margin: 4px 0 14px; }
.h5-card { margin-bottom: 16px; padding: 16px; }
.h5-card h2 { margin-bottom: 8px; font-size: 18px; }
.h5-card p { color: var(--color-text-secondary); line-height: 1.7; }
.h5-card :deep(.ant-form-item-label > label) { font-weight: 500; }
.h5-card :deep(.ant-input), .h5-card :deep(.ant-select-selector), .h5-card :deep(.ant-picker), .h5-card :deep(.ant-btn) { min-height: 44px; }
.companions-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.companions-head h3 { margin: 0; }
.helper { margin: 8px 0; }
.companion-card { display: grid; gap: 8px; margin-bottom: 12px; padding: 12px; border: 1px solid var(--color-border); border-radius: 10px; }
.field-error { margin: -2px 0 0; color: var(--color-error); font-size: 12px; }
.consent-card { outline: none; }
.consent-check { display: flex; min-height: 44px; align-items: center; line-height: 1.5; }
.consent-alert { margin-top: 12px; }
.summary-card dl { display: grid; grid-template-columns: 92px 1fr; gap: 10px; margin: 16px 0; }
.summary-card dt { color: var(--color-text-secondary); }
.summary-card dd { margin: 0; word-break: break-all; }
.h5-action-bar { position: fixed; right: 0; bottom: 0; left: 0; z-index: 20; display: flex; gap: 10px; width: 100%; max-width: 480px; margin: 0 auto; padding: 8px 16px calc(8px + env(safe-area-inset-bottom)); background: var(--color-surface); box-shadow: 0 -1px 4px rgba(0,0,0,.08); }
.h5-action-bar :deep(.ant-btn) { flex: 1; min-height: 44px; }
.success-card { text-align: center; }
.success-card h2 { margin-top: 20px; color: var(--color-success); }
@media (max-width: 360px) { .summary-card dl { grid-template-columns: 78px 1fr; } }
</style>
