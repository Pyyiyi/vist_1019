<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { message } from 'ant-design-vue';
import dayjs, { type Dayjs } from 'dayjs';

import apiClient from '@/api/client';
import type { CompanionItem, VisitFormModel, VisitFormOptions } from './types';
import { responseField, serverMessage } from './helpers';

const props = defineProps<{ open: boolean; options: VisitFormOptions }>();
const emit = defineEmits<{ 'update:open': [value: boolean]; submitted: [] }>();

const submitting = ref(false);
const submitted = ref(false);
const blackWarning = ref(false);
const fieldErrors = reactive<Record<string, string>>({});
const startValue = ref<Dayjs | null>(null);
const endValue = ref<Dayjs | null>(null);

const form = reactive<VisitFormModel>({
  visitorName: '',
  visitorPhone: '',
  visitorIdNo: '',
  visitorTypeId: undefined,
  hostId: undefined,
  expectedGateId: undefined,
  visitStart: null,
  visitEnd: null,
  reason: '',
  plateNo: '',
  companions: [],
});

const relationOptions = computed(() => props.options.relations.map((item) => ({ label: item.dictLabel, value: item.dictKey })));
const canAddCompanion = computed(() => form.companions.length < 10);

function reset(): void {
  Object.assign(form, {
    visitorName: '', visitorPhone: '', visitorIdNo: '', visitorTypeId: undefined, hostId: undefined,
    expectedGateId: undefined, visitStart: null, visitEnd: null, reason: '', plateNo: '', companions: [],
  });
  startValue.value = null;
  endValue.value = null;
  blackWarning.value = false;
  submitted.value = false;
  Object.keys(fieldErrors).forEach((key) => delete fieldErrors[key]);
}

watch(() => props.open, (open) => { if (open) reset(); });

function addCompanion(): void {
  if (!canAddCompanion.value) {
    message.warning('最多添加 10 名随行人员');
    return;
  }
  form.companions.push({ name: '', relation: '', idNo: '' });
}

function removeCompanion(index: number): void {
  form.companions.splice(index, 1);
}

function setError(field: string, text: string): false {
  fieldErrors[field] = text;
  return false;
}

function validIdNo(value: string): boolean {
  return /^\d{17}[\dXx]$/.test(value) || /^[A-Za-z0-9]{5,20}$/.test(value);
}

function validate(): boolean {
  Object.keys(fieldErrors).forEach((key) => delete fieldErrors[key]);
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
  if (form.companions.length > 10) return setError('companions', '最多添加 10 名随行人员');
  for (let index = 0; index < form.companions.length; index += 1) {
    const item = form.companions[index];
    if (!item.name.trim()) return setError(`companions.${index}.name`, '请输入随行人员姓名');
    if (!item.relation) return setError(`companions.${index}.relation`, '请选择与主访客的关系');
    if (!item.idNo.trim() || !validIdNo(item.idNo.trim())) return setError(`companions.${index}.idNo`, '请输入正确的随行人员证件号');
  }
  return true;
}

function makeCompanions(): CompanionItem[] {
  return form.companions.map((item) => ({ name: item.name.trim(), relation: item.relation, idNo: item.idNo.trim() }));
}

async function submit(): Promise<void> {
  if (submitting.value || submitted.value) return;
  if (!validate()) return;
  submitting.value = true;
  try {
    const response = await apiClient.post('/appointments', {
      visitorName: form.visitorName.trim(),
      visitorPhone: form.visitorPhone.trim(),
      visitorIdNo: form.visitorIdNo.trim(),
      visitorTypeId: form.visitorTypeId,
      hostId: form.hostId,
      expectedGateId: form.expectedGateId || null,
      visitStart: startValue.value!.toISOString(),
      visitEnd: endValue.value!.toISOString(),
      reason: form.reason.trim(),
      plateNo: form.plateNo.trim() || null,
      companions: makeCompanions(),
    });
    const data = response.data.data ?? {};
    blackWarning.value = Boolean(data.blackHit);
    message.success('预约已提交，请等待被访人审核');
    emit('submitted');
    submitted.value = true;
    if (!blackWarning.value) emit('update:open', false);
  } catch (error) {
    const field = responseField(error);
    const map: Record<string, string> = { visitor_name: 'visitorName', visitor_phone: 'visitorPhone', visitor_id_no: 'visitorIdNo', visitor_type_id: 'visitorTypeId', host_id: 'hostId', visit_start: 'visitStart', visit_end: 'visitEnd', reason: 'reason', companions: 'companions' };
    const text = serverMessage(error);
    message.error(text);
    if (field && map[field]) fieldErrors[map[field]] = text;
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <a-modal
    :open="open"
    title="新增预约"
    width="840px"
    :mask-closable="false"
    :footer="null"
    @cancel="emit('update:open', false)"
  >
    <a-alert v-if="blackWarning" type="warning" show-icon :message="'该证件号曾命中安全名单，本次申请已记录并将重点核验'" class="blacklist-warning" />
    <a-form layout="vertical" class="appointment-form">
      <div class="form-grid">
        <a-form-item label="访客姓名" :validate-status="fieldErrors.visitorName ? 'error' : undefined" :help="fieldErrors.visitorName">
          <a-input v-model:value="form.visitorName" placeholder="请输入访客姓名" />
        </a-form-item>
        <a-form-item label="手机号" :validate-status="fieldErrors.visitorPhone ? 'error' : undefined" :help="fieldErrors.visitorPhone">
          <a-input v-model:value="form.visitorPhone" placeholder="请输入 11 位手机号" :maxlength="11" />
        </a-form-item>
        <a-form-item label="证件号" :validate-status="fieldErrors.visitorIdNo ? 'error' : undefined" :help="fieldErrors.visitorIdNo">
          <a-input v-model:value="form.visitorIdNo" placeholder="请输入身份证号或其他证件号" />
        </a-form-item>
        <a-form-item label="访客类型" :validate-status="fieldErrors.visitorTypeId ? 'error' : undefined" :help="fieldErrors.visitorTypeId">
          <a-select v-model:value="form.visitorTypeId" placeholder="请选择访客类型" :options="options.visitorTypes.map((item) => ({ label: item.name, value: item.id }))" />
        </a-form-item>
        <a-form-item label="被访人" :validate-status="fieldErrors.hostId ? 'error' : undefined" :help="fieldErrors.hostId">
          <a-select v-model:value="form.hostId" placeholder="请选择被访教职工" show-search option-filter-prop="label" :options="options.hosts.map((item) => ({ label: `${item.name}${item.department ? ' · ' + item.department : ''}`, value: item.id }))" />
        </a-form-item>
        <a-form-item label="预计入校校门（选填）">
          <a-select v-model:value="form.expectedGateId" allow-clear placeholder="请选择校门" :options="options.gates.map((item) => ({ label: item.name, value: item.id }))" />
        </a-form-item>
        <a-form-item label="开始时间" :validate-status="fieldErrors.visitStart ? 'error' : undefined" :help="fieldErrors.visitStart">
          <a-date-picker v-model:value="startValue" show-time format="YYYY-MM-DD HH:mm" placeholder="请选择开始时间" style="width: 100%" />
        </a-form-item>
        <a-form-item label="结束时间" :validate-status="fieldErrors.visitEnd ? 'error' : undefined" :help="fieldErrors.visitEnd">
          <a-date-picker v-model:value="endValue" show-time format="YYYY-MM-DD HH:mm" placeholder="请选择结束时间" style="width: 100%" />
        </a-form-item>
        <a-form-item label="来访事由" class="full-width" :validate-status="fieldErrors.reason ? 'error' : undefined" :help="fieldErrors.reason">
          <a-textarea v-model:value="form.reason" placeholder="请简要说明来访事由（2–100 字）" :rows="3" />
        </a-form-item>
        <a-form-item label="车牌号（选填）" class="full-width">
          <a-input v-model:value="form.plateNo" placeholder="请输入车牌号" />
        </a-form-item>
      </div>

      <section class="companions-section">
        <div class="companions-head">
          <h3>随行人员</h3>
          <a-button :disabled="!canAddCompanion || submitted" @click="addCompanion">添加随行人员</a-button>
        </div>
        <p class="companion-help">最多添加 10 名随行人员</p>
        <div v-for="(item, index) in form.companions" :key="index" class="companion-row">
          <a-input v-model:value="item.name" placeholder="请输入随行人员姓名" />
          <a-select v-model:value="item.relation" placeholder="请选择关系" :options="relationOptions" />
          <a-input v-model:value="item.idNo" placeholder="请输入随行人员证件号" />
          <a-button danger type="link" @click="removeCompanion(index)">移除</a-button>
          <p v-if="fieldErrors[`companions.${index}.name`]" class="field-error">{{ fieldErrors[`companions.${index}.name`] }}</p>
          <p v-if="fieldErrors[`companions.${index}.relation`]" class="field-error">{{ fieldErrors[`companions.${index}.relation`] }}</p>
          <p v-if="fieldErrors[`companions.${index}.idNo`]" class="field-error">{{ fieldErrors[`companions.${index}.idNo`] }}</p>
        </div>
        <p v-if="fieldErrors.companions" class="field-error">{{ fieldErrors.companions }}</p>
      </section>
    </a-form>
    <div class="modal-footer">
      <a-button @click="emit('update:open', false)">取消</a-button>
      <a-button type="primary" :loading="submitting" :disabled="submitted || submitting" @click="submit">
        {{ submitting ? '正在提交...' : '提交预约' }}
      </a-button>
    </div>
  </a-modal>
</template>

<style scoped>
.blacklist-warning { margin-bottom: var(--space-4); }
.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 var(--space-4); }
.full-width { grid-column: 1 / -1; }
.companions-section { padding-top: var(--space-3); border-top: 1px solid var(--color-border); }
.companions-head { display: flex; align-items: center; justify-content: space-between; }
.companion-help { margin: 4px 0 12px; color: var(--color-text-secondary); font-size: var(--font-size-sm); }
.companion-row { display: grid; grid-template-columns: 1fr 160px 1fr 64px; gap: var(--space-2); margin-bottom: var(--space-3); }
.field-error { grid-column: 1 / -1; margin: -4px 0 0; color: var(--color-error); font-size: var(--font-size-xs); }
.modal-footer { display: flex; justify-content: flex-end; gap: var(--space-2); margin-top: var(--space-5); }
@media (max-width: 760px) { .form-grid { grid-template-columns: 1fr; } .companion-row { grid-template-columns: 1fr; } }
</style>
