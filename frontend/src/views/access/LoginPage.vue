<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { EyeInvisibleOutlined, EyeOutlined, LockOutlined, UserOutlined } from '@ant-design/icons-vue';
import { message } from 'ant-design-vue';
import { useRoute, useRouter } from 'vue-router';

import { navigation, type NavItem } from '@/nav/navigation';
import { useAuthStore } from '@/stores/auth';

type FieldErrors = { username?: string; password?: string };
type ApiError = {
  response?: { data?: { message?: string; field?: string } };
};

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const form = reactive({ username: '', password: '' });
const errors = reactive<FieldErrors>({});
const submitting = ref(false);
const showPassword = ref(false);
const passwordInputType = computed(() => (showPassword.value ? 'text' : 'password'));
const passwordToggleLabel = computed(() =>
  showPassword.value ? '隐藏密码' : '显示密码',
);

function findNavByPath(path: string): NavItem | null {
  const visit = (items: NavItem[]): NavItem | null => {
    for (const item of items) {
      if (item.path === path) return item;
      if (item.children) {
        const child = visit(item.children);
        if (child) return child;
      }
    }
    return null;
  };
  return visit(navigation);
}

function redirectForRole(role: string): string {
  const redirect = route.query.redirect;
  if (typeof redirect !== 'string' || !redirect.startsWith('/') || redirect.startsWith('//')) {
    return '/workbench';
  }

  const path = redirect.split('?')[0]?.split('#')[0] ?? '';
  if (!path || path === '/login') {
    return '/workbench';
  }
  if (path === '/403' || path === '/workbench') {
    return path;
  }

  const item = findNavByPath(path);
  return item?.roles.includes(role) ? path : '/workbench';
}

function apiMessage(error: unknown): string {
  return (error as ApiError).response?.data?.message ?? '';
}

async function handleSubmit(): Promise<void> {
  if (submitting.value) return;
  errors.username = form.username.trim() ? undefined : '请输入账号';
  errors.password = form.password ? undefined : '请输入密码';
  if (errors.username || errors.password) return;

  submitting.value = true;
  try {
    await authStore.login(form.username.trim(), form.password);
    message.success('登录成功');
    const role = authStore.role ?? 'host';
    await router.replace(redirectForRole(role));
  } catch (error) {
    const text = apiMessage(error);
    if (text) {
      message.error(text);
    } else {
      message.error('系统暂时无法处理，请稍后重试');
    }
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <main class="login-page">
    <section class="login-brand" aria-hidden="true">
      <div class="brand-mark">访</div>
      <h2>校园访客系统</h2>
      <p>安全、有序、可追溯的校园来访管理</p>
    </section>

    <section class="login-panel">
      <header class="login-heading">
        <h1>校园访客系统</h1>
        <p>请使用管理员账号或教职工工号登录</p>
      </header>

      <form class="login-form" @submit.prevent="handleSubmit">
        <div class="form-field">
          <label for="login-username">账号 / 工号</label>
          <a-input
            id="login-username"
            v-model:value="form.username"
            size="large"
            autocomplete="username"
            placeholder="请输入账号或工号"
            :status="errors.username ? 'error' : undefined"
            @press-enter="handleSubmit"
          >
            <template #prefix><UserOutlined aria-hidden="true" /></template>
          </a-input>
          <p v-if="errors.username" class="field-error" role="alert">
            {{ errors.username }}
          </p>
        </div>

        <div class="form-field">
          <label for="login-password">密码</label>
          <a-input
            id="login-password"
            v-model:value="form.password"
            size="large"
            :type="passwordInputType"
            autocomplete="current-password"
            placeholder="请输入密码"
            :status="errors.password ? 'error' : undefined"
            @press-enter="handleSubmit"
          >
            <template #prefix><LockOutlined aria-hidden="true" /></template>
            <template #suffix>
              <a-tooltip :title="passwordToggleLabel">
                <a-button
                  type="text"
                  class="password-toggle"
                  :aria-label="passwordToggleLabel"
                  @mousedown.prevent
                  @click="showPassword = !showPassword"
                >
                  <template #icon>
                    <EyeInvisibleOutlined v-if="showPassword" />
                    <EyeOutlined v-else />
                  </template>
                </a-button>
              </a-tooltip>
            </template>
          </a-input>
          <p v-if="errors.password" class="field-error" role="alert">
            {{ errors.password }}
          </p>
        </div>

        <a-button
          type="primary"
          html-type="submit"
          size="large"
          block
          :loading="submitting"
          :disabled="submitting"
        >
          {{ submitting ? '登录中...' : '登录' }}
        </a-button>
      </form>
    </section>
  </main>
</template>

<style scoped>
.login-page {
  display: grid;
  grid-template-columns: minmax(360px, 1fr) minmax(380px, 520px);
  min-height: 100vh;
  background:
    radial-gradient(circle at 15% 20%, rgba(255, 255, 255, 0.16), transparent 26%),
    linear-gradient(135deg, #0b3a7a 0%, #1677ff 58%, #67a8ff 100%);
}

.login-brand {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 48px;
  color: #ffffff;
}

.brand-mark {
  display: grid;
  width: 92px;
  height: 92px;
  margin-bottom: 28px;
  border: 1px solid rgba(255, 255, 255, 0.45);
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.16);
  font-size: 44px;
  font-weight: 700;
  place-items: center;
  backdrop-filter: blur(8px);
}

.login-brand h2 {
  margin: 0 0 12px;
  font-size: 34px;
  font-weight: 650;
}

.login-brand p {
  margin: 0;
  color: rgba(255, 255, 255, 0.78);
  font-size: 16px;
}

.login-panel {
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 56px;
  background: var(--color-surface);
  box-shadow: -18px 0 50px rgba(0, 0, 0, 0.12);
}

.login-heading {
  margin-bottom: 34px;
}

.login-heading h1 {
  margin: 0 0 10px;
  color: var(--color-text-primary);
  font-size: 28px;
  font-weight: 650;
}

.login-heading p {
  color: var(--color-text-secondary);
  font-size: 15px;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

.form-field label {
  display: block;
  margin-bottom: 8px;
  color: var(--color-text-primary);
  font-weight: 550;
}

.password-toggle {
  display: inline-grid;
  min-width: 32px;
  min-height: 32px;
  place-items: center;
}

.field-error {
  margin-top: 6px;
  color: var(--color-error);
  font-size: var(--font-size-sm);
}

@media (max-width: 860px) {
  .login-page {
    grid-template-columns: 1fr;
  }

  .login-brand {
    min-height: 220px;
    padding: 32px 24px;
  }

  .brand-mark {
    width: 64px;
    height: 64px;
    margin-bottom: 16px;
    font-size: 30px;
  }

  .login-brand h2 {
    font-size: 26px;
  }

  .login-panel {
    padding: 32px 24px 48px;
  }
}
</style>
