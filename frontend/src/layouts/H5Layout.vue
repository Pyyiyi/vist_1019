<template>
  <div class="h5-layout">
    <main class="h5-main">
      <slot />
    </main>
    <footer v-if="$slots.footer" class="h5-footer no-print">
      <slot name="footer" />
    </footer>
  </div>
</template>

<style scoped>
.h5-layout {
  width: 100%;
  max-width: 480px;
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(var(--h5-action-height) + env(safe-area-inset-bottom));
  overflow-x: hidden;
  background: var(--color-page-bg);
}

.h5-main {
  min-height: calc(100vh - var(--h5-action-height));
  padding: var(--space-4);
}

.h5-main :deep(.page-card) {
  border-radius: var(--radius-h5-card);
}

.h5-footer {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  max-width: 480px;
  min-height: var(--h5-action-height);
  margin: 0 auto;
  padding: var(--space-1) var(--space-4)
    calc(var(--space-1) + env(safe-area-inset-bottom));
  background: var(--color-surface);
  box-shadow: 0 -1px 4px rgba(0, 0, 0, 0.08);
}

.h5-footer :deep(.ant-btn) {
  min-width: var(--touch-target-min);
  min-height: var(--touch-target-min);
}
</style>
