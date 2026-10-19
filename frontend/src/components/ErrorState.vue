<script setup lang="ts">
import { CloseCircleOutlined } from '@ant-design/icons-vue';

withDefaults(
  defineProps<{
    message?: string;
  }>(),
  {
    message: '数据加载失败，请点击重试',
  },
);

defineEmits<{
  retry: [];
}>();
</script>

<template>
  <section class="error-state" role="alert">
    <CloseCircleOutlined class="error-state-icon" aria-hidden="true" />
    <p>{{ message }}</p>
    <a-button type="primary" @click="$emit('retry')">重试</a-button>
  </section>
</template>

<style scoped>
.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 220px;
  padding: var(--space-8);
  color: var(--color-text-secondary);
  text-align: center;
}

.error-state-icon {
  margin-bottom: var(--space-4);
  color: var(--color-error);
  font-size: 42px;
}

.error-state p {
  margin-bottom: var(--space-4);
}
</style>
