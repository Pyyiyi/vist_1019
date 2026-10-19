<script setup lang="ts">
import { InboxOutlined } from '@ant-design/icons-vue';

withDefaults(
  defineProps<{
    description?: string;
    actionText?: string;
  }>(),
  {
    description: '暂无数据',
    actionText: '',
  },
);

defineEmits<{
  action: [];
}>();
</script>

<template>
  <section class="empty-state" role="status">
    <InboxOutlined class="empty-state-icon" aria-hidden="true" />
    <p>{{ description }}</p>
    <a-button v-if="actionText" type="primary" @click="$emit('action')">
      {{ actionText }}
    </a-button>
  </section>
</template>

<style scoped>
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 220px;
  padding: var(--space-8);
  color: var(--color-text-secondary);
  text-align: center;
}

.empty-state-icon {
  margin-bottom: var(--space-4);
  color: #a8abb2;
  font-size: 42px;
}

.empty-state p {
  margin-bottom: var(--space-4);
}
</style>
