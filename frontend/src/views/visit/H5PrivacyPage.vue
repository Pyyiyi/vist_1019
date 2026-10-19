<script setup lang="ts">
import { LeftOutlined } from '@ant-design/icons-vue';
import { useRouter } from 'vue-router';

const router = useRouter();
</script>

<template>
  <section class="privacy-page">
    <a-button type="text" class="back-button" aria-label="返回" @click="router.back()">
      <template #icon><LeftOutlined /></template>
    </a-button>
    <h1>个人信息说明</h1>
    <p>系统收集您的姓名、手机号、证件号及随行人员信息，仅用于本次来访登记与校园安全管理，并按留存期限处理；超过留存期限后，界面与导出中的证件号显示为脱敏信息。</p>
  </section>
</template>

<style scoped>
.privacy-page { min-height: 100vh; padding: var(--space-5) var(--space-4); }
.privacy-page h1 { margin: var(--space-4) 0; font-size: var(--font-size-xl); }
.privacy-page p { color: var(--color-text-secondary); line-height: 1.8; }
.back-button { width: 44px; height: 44px; }
</style>
