<script setup lang="ts">
import { ref } from 'vue';
import { CopyOutlined } from '@ant-design/icons-vue';
import { message } from 'ant-design-vue';

const props = withDefaults(
  defineProps<{
    text: string;
    successMessage?: string;
  }>(),
  {
    successMessage: '入口链接已复制',
  },
);

const copying = ref(false);

function fallbackCopy(text: string): void {
  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  document.body.appendChild(textarea);
  textarea.select();
  const copied = document.execCommand('copy');
  document.body.removeChild(textarea);
  if (!copied) {
    throw new Error('copy failed');
  }
}

async function copyText(): Promise<void> {
  if (copying.value) {
    return;
  }

  copying.value = true;
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(props.text);
    } else {
      fallbackCopy(props.text);
    }
    message.success(props.successMessage);
  } catch {
    try {
      fallbackCopy(props.text);
      message.success(props.successMessage);
    } catch {
      message.error('系统暂时无法处理，请稍后重试');
    }
  } finally {
    copying.value = false;
  }
}
</script>

<template>
  <a-button :loading="copying" @click="copyText">
    <template #icon><CopyOutlined /></template>
    {{ copying ? '加载中...' : '复制链接' }}
  </a-button>
</template>
