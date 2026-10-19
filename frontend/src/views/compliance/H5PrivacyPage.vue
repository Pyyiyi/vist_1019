<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import dayjs from 'dayjs';

import apiClient from '@/api/client';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';

type PrivacyAppointment = {
  id: string;
  appointNo: string;
  visitorName: string | null;
  visitorPhone: string | null;
  visitorIdNoMasked: string;
  status: string;
  visitStart: string;
  visitEnd: string;
};
type PrivacyCopy = {
  appointment: PrivacyAppointment;
  appointments?: PrivacyAppointment[];
};

const router = useRouter();
const loading = ref(false);
const failed = ref(false);
const expired = ref(false);
const copyData = ref<PrivacyCopy | null>(null);
const appointmentList = computed(() =>
  copyData.value?.appointments?.length
    ? copyData.value.appointments
    : copyData.value?.appointment
      ? [copyData.value.appointment]
      : [],
);

function formatRange(start: string, end: string): string {
  return `${dayjs(start).format('YYYY-MM-DD HH:mm')} - ${dayjs(end).format('HH:mm')}`;
}

async function loadCopy(): Promise<void> {
  loading.value = true;
  failed.value = false;
  expired.value = false;
  try {
    const response = await apiClient.get('/visitor/privacy/copy');
    copyData.value = response.data.data as PrivacyCopy;
  } catch (error) {
    const candidate = error as { response?: { status?: number; data?: { code?: number } } };
    if (candidate.response?.status === 403 || candidate.response?.data?.code === 40303) {
      expired.value = true;
    } else {
      failed.value = true;
    }
    copyData.value = null;
  } finally {
    loading.value = false;
  }
}

function rescan(): void {
  void router.push('/h5/apply');
}
</script>

<template>
  <section class="h5-privacy-page">
    <PageHeader title="个人信息说明" />

    <section class="privacy-intro page-card">
      <p>系统收集您的姓名、手机号、证件号及随行人员信息，仅用于本次来访登记与校园安全管理，并按留存期限处理；超过留存期限后，界面与导出中的证件号显示为脱敏信息。</p>
    </section>

    <LoadingState v-if="loading" />
    <ErrorState v-else-if="failed" @retry="loadCopy" />

    <section v-else-if="expired" class="token-expired page-card">
      <a-result status="warning" title="该申请链接已失效，请重新扫码申请">
        <template #extra>
          <a-button type="primary" class="h5-primary-button" @click="rescan">重新扫码申请</a-button>
        </template>
      </a-result>
    </section>

    <template v-else-if="copyData">
      <section class="copy-card page-card">
        <h2>我的信息副本</h2>
        <dl class="copy-fields">
          <div><dt>姓名</dt><dd>{{ copyData.appointment.visitorName || '—' }}</dd></div>
          <div><dt>手机号</dt><dd>{{ copyData.appointment.visitorPhone || '—' }}</dd></div>
          <div><dt>证件号</dt><dd>{{ copyData.appointment.visitorIdNoMasked || '—' }}</dd></div>
        </dl>
      </section>

      <section class="appointment-copy page-card">
        <h2>预约列表</h2>
        <article v-for="item in appointmentList" :key="item.id" class="copy-appointment">
          <div class="appointment-head"><strong>{{ item.appointNo }}</strong><span>{{ item.status }}</span></div>
          <p>{{ item.visitorName || '—' }} · {{ item.visitorPhone || '—' }}</p>
          <p>{{ formatRange(item.visitStart, item.visitEnd) }}</p>
        </article>
      </section>
    </template>

    <button
      v-if="!expired"
      type="button"
      class="copy-button"
      :class="{ 'page-card': !copyData }"
      :disabled="loading"
      @click="loadCopy"
    >
      {{ loading ? '正在生成信息副本...' : '获取我的信息副本' }}
    </button>
  </section>
</template>

<style scoped>
.h5-privacy-page { display: flex; width: 100%; max-width: 100%; flex-direction: column; gap: var(--space-3); overflow-x: hidden; }
.privacy-intro, .copy-card, .appointment-copy, .token-expired { padding: var(--space-4); }
.privacy-intro p { margin: 0; color: var(--color-text-secondary); line-height: 1.8; }
.copy-card h2, .appointment-copy h2 { margin: 0 0 var(--space-3); font-size: var(--font-size-lg); }
.copy-fields { display: grid; gap: var(--space-3); margin: 0; }
.copy-fields > div { display: grid; grid-template-columns: 72px minmax(0, 1fr); gap: var(--space-3); }
.copy-fields dt { color: var(--color-text-secondary); }
.copy-fields dd { margin: 0; color: var(--color-text-primary); word-break: break-all; }
.copy-appointment { padding: var(--space-3) 0; border-bottom: 1px solid var(--color-border); }
.copy-appointment:last-child { padding-bottom: 0; border-bottom: 0; }
.appointment-head { display: flex; align-items: center; justify-content: space-between; gap: var(--space-2); }
.copy-appointment p { margin: 6px 0 0; color: var(--color-text-secondary); }
.copy-button { display: inline-flex; align-items: center; justify-content: center; width: 100%; min-height: var(--touch-target-min); padding: 0 var(--space-4); border: 0; border-radius: var(--radius-h5-card); color: #fff; font-size: var(--font-size-base); font-weight: 600; background: var(--color-primary); cursor: pointer; }
.copy-button:disabled { opacity: 0.7; cursor: wait; }
.copy-button.page-card { color: var(--color-primary); background: var(--color-surface); }
.token-expired :deep(.ant-result) { padding: var(--space-4) var(--space-2); }
.h5-primary-button { min-width: var(--touch-target-min); min-height: var(--touch-target-min); }
</style>
