<script setup lang="ts">
import { computed, ref } from 'vue';

const props = withDefaults(
  defineProps<{
    title: string;
    content: string;
    okText?: string;
    cancelText?: string;
    danger?: boolean;
  }>(),
  {
    okText: '确定',
    cancelText: '取消',
    danger: false,
  },
);

const emit = defineEmits<{
  confirm: [];
  cancel: [];
}>();

const open = ref(false);
const okButtonProps = computed(() => (props.danger ? { danger: true } : {}));

function openDialog(): void {
  open.value = true;
}

function closeDialog(): void {
  open.value = false;
}

function handleConfirm(): void {
  closeDialog();
  emit('confirm');
}

function handleCancel(): void {
  closeDialog();
  emit('cancel');
}

defineExpose({
  openDialog,
  closeDialog,
});
</script>

<template>
  <a-modal
    v-model:open="open"
    :title="title"
    :ok-text="okText"
    :cancel-text="cancelText"
    :ok-button-props="okButtonProps"
    :mask-closable="false"
    @ok="handleConfirm"
    @cancel="handleCancel"
  >
    <p class="confirm-dialog-content">{{ content }}</p>
  </a-modal>
</template>

<style scoped>
.confirm-dialog-content {
  color: var(--color-text-primary);
  line-height: var(--line-height-base);
}
</style>
