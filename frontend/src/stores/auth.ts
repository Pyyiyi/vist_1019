import { computed, ref } from 'vue';
import { defineStore } from 'pinia';
import apiClient from '@/api/client';

export type AuthUser = {
  id: string;
  username: string;
  displayName: string;
  roleCode: 'admin' | 'guard' | 'host';
  hostId: string | null;
};

type UserEnvelope = {
  data?: AuthUser | { user?: AuthUser };
  user?: AuthUser;
};

function extractUser(payload: UserEnvelope): AuthUser | null {
  const data = payload?.data ?? payload;
  if (data && typeof data === 'object' && 'user' in data) {
    return (data as { user?: AuthUser }).user ?? null;
  }
  return (data as AuthUser | undefined) ?? null;
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<AuthUser | null>(null);

  const role = computed(() => user.value?.roleCode ?? null);
  const isLoggedIn = computed(() => user.value !== null);

  function setUser(nextUser: AuthUser | null): void {
    user.value = nextUser;
  }

  function clearSession(): void {
    user.value = null;
  }

  async function login(username: string, password: string): Promise<void> {
    const response = await apiClient.post('/auth/login', { username, password });
    const nextUser = extractUser(response.data.data);
    if (!nextUser) {
      throw new Error('登录响应缺少用户信息');
    }
    setUser(nextUser);
  }

  async function logout(): Promise<void> {
    try {
      await apiClient.post('/auth/logout');
    } finally {
      clearSession();
    }
  }

  async function fetchMe(): Promise<void> {
    const response = await apiClient.get('/auth/me');
    const nextUser = extractUser(response.data.data);
    if (!nextUser) {
      clearSession();
      return;
    }
    setUser(nextUser);
  }

  async function changePassword(
    oldPassword: string,
    newPassword: string,
  ): Promise<void> {
    await apiClient.put('/auth/password', { oldPassword, newPassword });
  }

  return {
    user,
    role,
    isLoggedIn,
    login,
    logout,
    fetchMe,
    changePassword,
    setUser,
    clearSession,
  };
});
