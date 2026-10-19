<script setup lang="ts">
import { reactive, ref } from 'vue';
import { message } from 'ant-design-vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from '@/stores/auth';

type ApiError = {
  response?: { data?: { message?: string; field?: string } };
};

const router = useRouter();
const authStore = useAuthStore();
const open = ref(false);
const submitting = ref(false);
const form = reactive({ oldPassword: '', newPassword: '' });
const errors = reactive<{ oldPassword?: string; newPassword?: string }>({});

function openDialog(): void {
  form.oldPassword = '';
  form.newPassword = '';
  errors.oldPassword = undefined;
  errors.newPassword = undefined;
  open.value = true;
}

function closeDialog(): void {
  if (submitting.value) return;
  open.value = false;
}

function apiError(error: unknown): ApiError['response'] {
  return (error as ApiError).response;
}

async function submit(): Promise<void> {
  if (submitting.value) return;
  errors.oldPassword = form.oldPassword ? undefined : '请输入原密码';
  errors.newPassword =
    form.newPassword.length >= 6 ? undefined : '密码长度不能少于 6 位';
  if (errors.oldPassword || errors.newPassword) return;

  submitting.value = true;
  try {
    await authStore.changePassword(form.oldPassword, form.newPassword);
    message.success('密码修改成功，请使用新密码登录');
    open.value = false;
    try {
      await authStore.logout();
    } catch {
    } finally {
      await router.replace('/login');
    }
  } catch (error) {
    const data = apiError(error)?.data;
    if (data?.field === 'old_password') {
      errors.oldPassword = data.message ?? '原密码不正确';
    } else if (data?.field === 'new_password' || data?.field === 'password') {
      errors.newPassword = data.message ?? '密码长度不能少于 6 位';
    } else {
      message.error(data?.message ?? '系统暂时无法处理，请稍后重试');
    }
  } finally {
    submitting.value = false;
  }
}

defineExpose({ openDialog, closeDialog });
</script>

<template>
  <a-modal
    :open="open"
    title="修改密码"
    :confirm-loading="submitting"
    :ok-button-props="{ disabled: submitting }"
    :mask-closable="false"
    ok-text="确定"
    cancel-text="取消"
    @ok="submit"
    @cancel="closeDialog"
  >
    <div class="password-form">
      <div class="form-field">
        <label for="change-old-password">原密码</label>
        <a-input-password
          id="change-old-password"
          v-model:value="form.oldPassword"
          autocomplete="current-password"
          :status="errors.oldPassword ? 'error' : undefined"
          @press-enter="submit"
        />
        <p v-if="errors.oldPassword" class="field-error" role="alert">
          {{ errors.oldPassword }}
        </p>
      </div>

      <div class="form-field">
        <label for="change-new-password">新密码</label>
        <a-input-password
          id="change-new-password"
          v-model:value="form.newPassword"
          autocomplete="new-password"
          :status="errors.newPassword ? 'error' : undefined"
          @press-enter="submit"
        />
        <p class="field-hint">密码至少 6 位</p>
        <p v-if="errors.newPassword" class="field-error" role="alert">
          {{ errors.newPassword }}
        </p>
      </div>
    </div>
  </a-modal>
</template>

<style scoped>
.password-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding-top: 4px;
}

.form-field label {
  display: block;
  margin-bottom: 8px;
  color: var(--color-text-primary);
  font-weight: 550;
}

.field-hint {
  margin-top: 6px;
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

.field-error {
  margin-top: 6px;
  color: var(--color-error);
  font-size: var(--font-size-sm);
}
</style>
