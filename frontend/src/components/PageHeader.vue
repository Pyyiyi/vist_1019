<script setup lang="ts">
export type BreadcrumbItem = {
  title: string;
  path?: string;
};

withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    breadcrumbs?: BreadcrumbItem[];
  }>(),
  {
    subtitle: '',
    breadcrumbs: () => [],
  },
);
</script>

<template>
  <header class="page-header">
    <a-breadcrumb v-if="breadcrumbs.length > 0" class="page-header-breadcrumbs">
      <a-breadcrumb-item v-for="crumb in breadcrumbs" :key="crumb.title">
        <a v-if="crumb.path" :href="crumb.path">{{ crumb.title }}</a>
        <span v-else>{{ crumb.title }}</span>
      </a-breadcrumb-item>
    </a-breadcrumb>

    <div class="page-header-main">
      <div class="page-header-copy">
        <h1>{{ title }}</h1>
        <p v-if="subtitle">{{ subtitle }}</p>
      </div>
      <div v-if="$slots.actions" class="page-header-actions">
        <slot name="actions" />
      </div>
    </div>
  </header>
</template>

<style scoped>
.page-header {
  margin-bottom: var(--space-6);
}

.page-header-breadcrumbs {
  margin-bottom: var(--space-3);
}

.page-header-main {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-4);
}

.page-header h1 {
  color: var(--color-text-primary);
  font-size: var(--font-size-2xl);
  font-weight: 600;
  line-height: 1.35;
}

.page-header p {
  margin-top: var(--space-1);
  color: var(--color-text-secondary);
  font-size: var(--font-size-base);
}

.page-header-actions {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: var(--space-2);
}
</style>
