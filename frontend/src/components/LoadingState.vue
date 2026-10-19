<script setup lang="ts">
withDefaults(
  defineProps<{
    rows?: number;
  }>(),
  {
    rows: 5,
  },
);
</script>

<template>
  <section class="loading-state" role="status" aria-live="polite">
    <a-skeleton active :paragraph="{ rows }" :title="false" />
    <p class="loading-state-text">加载中...</p>
  </section>
</template>

<style scoped>
.loading-state {
  padding: var(--space-6);
}

.loading-state-text {
  margin-top: var(--space-3);
  color: var(--color-text-secondary);
  text-align: center;
}
</style>
