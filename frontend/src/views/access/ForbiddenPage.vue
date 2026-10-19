<script setup lang="ts">
import { useRouter } from 'vue-router';

const router = useRouter();

function backToWorkbench(): void {
  void router.push('/workbench');
}
</script>

<template>
  <main class="forbidden-page">
    <section class="forbidden-card">
      <div class="forbidden-code">403</div>
      <h1>无权访问</h1>
      <p>您没有访问该页面的权限</p>
      <a-button type="primary" size="large" @click="backToWorkbench">
        返回工作台
      </a-button>
    </section>
  </main>
</template>

<style scoped>
.forbidden-page {
  display: grid;
  min-height: 100vh;
  padding: 24px;
  background: var(--color-page-bg);
  place-items: center;
}

.forbidden-card {
  width: min(480px, 100%);
  padding: 48px 40px;
  border-radius: 16px;
  background: var(--color-surface);
  box-shadow: var(--shadow-card);
  text-align: center;
}

.forbidden-code {
  margin-bottom: 8px;
  color: var(--color-primary);
  font-size: 64px;
  font-weight: 750;
  letter-spacing: 4px;
  line-height: 1;
}

.forbidden-card h1 {
  margin: 0 0 12px;
  font-size: 26px;
}

.forbidden-card p {
  margin: 0 0 28px;
  color: var(--color-text-secondary);
  font-size: 15px;
}
</style>
