<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';

import apiClient from '@/api/client';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';

type UserRow = {
  id: string;
  username: string;
  displayName: string;
  employeeNo: string | null;
  department: string;
  roleCode: string;
  hostId: string | null;
  phone: string | null;
  status: 'active' | 'inactive';
};

type PermissionRow = {
  code: string;
  name: string;
  resource: string;
  action: string;
};

type RoleRow = {
  code: string;
  name: string;
  description: string;
  permissions: PermissionRow[];
};

type UserForm = {
  username: string;
  password: string;
  displayName: string;
  roleCode: 'admin' | 'guard' | 'host';
  hostId: string | undefined;
  department: string;
  phone: string;
};

const loading = ref(true);
const failed = ref(false);
const users = ref<UserRow[]>([]);
const roles = ref<RoleRow[]>([]);
const allHosts = ref<UserRow[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);

const modalOpen = ref(false);
const modalMode = ref<'create' | 'edit'>('create');
const editingId = ref('');
const submitting = ref(false);
const form = reactive<UserForm>({
  username: '',
  password: '',
  displayName: '',
  roleCode: 'guard',
  hostId: undefined,
  department: '',
  phone: '',
});

const statusDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);
const statusTarget = ref<UserRow | null>(null);
const statusNext = ref<'active' | 'inactive'>('inactive');
const resetDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);
const resetTarget = ref<UserRow | null>(null);
const permissionsOpen = ref(false);
const selectedRoleCode = ref('guard');

const roleOptions = [
  { label: '管理员', value: 'admin' },
  { label: '门卫', value: 'guard' },
  { label: '被访教职工', value: 'host' },
];

const roleLabel = (code: string): string =>
  ({ admin: '管理员', guard: '门卫', host: '被访教职工', visitor: '访客' })[code] ?? code;

const hostOptions = computed(() =>
  allHosts.value
    .filter((item) => item.hostId)
    .map((item) => ({
      value: item.hostId as string,
      label: `${item.displayName}（${item.employeeNo ?? item.username}）`,
    })),
);

const columns = [
  { title: '账号', dataIndex: 'username', key: 'username', width: 140 },
  { title: '工号', dataIndex: 'employeeNo', key: 'employeeNo', width: 120 },
  { title: '姓名', dataIndex: 'displayName', key: 'displayName', width: 120 },
  { title: '部门', dataIndex: 'department', key: 'department', width: 140 },
  { title: '角色', dataIndex: 'roleCode', key: 'roleCode', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 300, fixed: 'right' },
];

const permissionColumns = [
  { title: '权限点', dataIndex: 'code', key: 'code' },
  { title: '数据范围', key: 'scope', width: 220 },
];

const selectedRole = computed(
  () => roles.value.find((role) => role.code === selectedRoleCode.value) ?? null,
);

const permissionRows = computed(() => selectedRole.value?.permissions ?? []);
const roleScope = computed(
  () =>
    ({ admin: '全校', guard: '本地当日、现场', host: '本人相关', visitor: '令牌绑定预约' })[
      selectedRoleCode.value
    ] ?? '',
);

const pagination = computed(() => ({
  current: page.value,
  pageSize: pageSize.value,
  total: total.value,
  showSizeChanger: false,
  showTotal: (value: number) => `共 ${value} 条`,
}));

function resetForm(): void {
  form.username = '';
  form.password = '';
  form.displayName = '';
  form.roleCode = 'guard';
  form.hostId = undefined;
  form.department = '';
  form.phone = '';
  editingId.value = '';
}

async function load(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const [userResponse, roleResponse, hostResponse] = await Promise.all([
      apiClient.get('/users', { params: { page: page.value, page_size: pageSize.value } }),
      apiClient.get('/roles'),
      apiClient.get('/users', { params: { page: 1, page_size: 100, role: 'host' } }),
    ]);
    users.value = userResponse.data.data.items as UserRow[];
    total.value = Number(userResponse.data.data.total ?? 0);
    roles.value = roleResponse.data.data as RoleRow[];
    allHosts.value = hostResponse.data.data.items as UserRow[];
  } catch {
    failed.value = true;
  } finally {
    loading.value = false;
  }
}

function openCreate(): void {
  resetForm();
  modalMode.value = 'create';
  modalOpen.value = true;
}

function openEdit(user: UserRow): void {
  resetForm();
  modalMode.value = 'edit';
  editingId.value = user.id;
  form.username = user.username;
  form.displayName = user.displayName;
  form.roleCode = user.roleCode as UserForm['roleCode'];
  form.hostId = user.hostId ?? undefined;
  form.department = user.department;
  form.phone = user.phone ?? '';
  modalOpen.value = true;
}

async function submitUser(): Promise<void> {
  if (submitting.value) return;
  if (!form.displayName.trim()) {
    message.error('请输入姓名');
    return;
  }
  if (modalMode.value === 'create' && !form.username.trim()) {
    message.error('请输入账号');
    return;
  }
  if (modalMode.value === 'create' && form.password.length < 6) {
    message.error('密码长度不能少于 6 位');
    return;
  }
  if (form.roleCode === 'host' && !form.hostId) {
    message.error('请选择绑定教职工');
    return;
  }

  submitting.value = true;
  try {
    const payload = {
      username: form.username.trim(),
      password: form.password,
      display_name: form.displayName.trim(),
      role_code: form.roleCode,
      host_id: form.roleCode === 'host' ? form.hostId : null,
      department: form.department.trim(),
      phone: form.phone.trim(),
    };
    if (modalMode.value === 'create') {
      await apiClient.post('/users', payload);
    } else {
      await apiClient.put(`/users/${editingId.value}`, payload);
    }
    message.success('保存成功');
    modalOpen.value = false;
    await load();
  } catch (error) {
    const text = (error as { response?: { data?: { message?: string } } }).response?.data?.message;
    message.error(text ?? '系统暂时无法处理，请稍后重试');
  } finally {
    submitting.value = false;
  }
}

function openStatusDialog(user: UserRow): void {
  statusTarget.value = user;
  statusNext.value = user.status === 'active' ? 'inactive' : 'active';
  statusDialog.value?.openDialog();
}

async function confirmStatus(): Promise<void> {
  const target = statusTarget.value;
  if (!target) return;
  try {
    await apiClient.put(`/users/${target.id}/status`, { status: statusNext.value });
    message.success(statusNext.value === 'inactive' ? '账号已停用' : '账号已启用');
    await load();
  } catch (error) {
    const text = (error as { response?: { data?: { message?: string } } }).response?.data?.message;
    message.error(text ?? '系统暂时无法处理，请稍后重试');
  }
}

function openResetDialog(user: UserRow): void {
  resetTarget.value = user;
  resetDialog.value?.openDialog();
}

async function confirmReset(): Promise<void> {
  const target = resetTarget.value;
  if (!target) return;
  try {
    await apiClient.put(`/users/${target.id}/password`, { password: 'abc@123' });
    message.success('密码已重置，请告知使用人');
  } catch (error) {
    const text = (error as { response?: { data?: { message?: string } } }).response?.data?.message;
    message.error(text ?? '系统暂时无法处理，请稍后重试');
  }
}

function openPermissions(): void {
  if (!roles.value.some((role) => role.code === selectedRoleCode.value)) {
    selectedRoleCode.value = roles.value[0]?.code ?? 'guard';
  }
  permissionsOpen.value = true;
}

function onPageChange(next: { current?: number }): void {
  page.value = next.current ?? 1;
  void load();
}

onMounted(load);
</script>

<template>
  <div class="users-page">
    <PageHeader title="用户与角色">
      <template #actions>
        <a-button @click="openPermissions">角色权限</a-button>
        <a-button type="primary" @click="openCreate">新增账号</a-button>
      </template>
    </PageHeader>

    <LoadingState v-if="loading" />
    <ErrorState v-else-if="failed" @retry="load" />
    <EmptyState v-else-if="users.length === 0" description="暂无数据" />
    <section v-else class="table-card page-card">
      <a-table
        row-key="id"
        :columns="columns"
        :data-source="users"
        :pagination="pagination"
        :scroll="{ x: 1080 }"
        @change="onPageChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'employeeNo'">
            {{ record.employeeNo || '—' }}
          </template>
          <template v-else-if="column.key === 'department'">
            {{ record.department || '—' }}
          </template>
          <template v-else-if="column.key === 'roleCode'">
            <a-tag :color="record.roleCode === 'admin' ? 'blue' : record.roleCode === 'guard' ? 'cyan' : 'green'">
              {{ roleLabel(record.roleCode) }}
            </a-tag>
          </template>
          <template v-else-if="column.key === 'status'">
            <StatusTag
              kind="soft"
              :status="record.status === 'active' ? '在用' : '停用'"
            />
          </template>
          <template v-else-if="column.key === 'actions'">
            <a-space :size="4" wrap>
              <a-button type="link" size="small" @click="openEdit(record)">编辑</a-button>
              <a-button
                type="link"
                size="small"
                :danger="record.status === 'active'"
                @click="openStatusDialog(record)"
              >
                {{ record.status === 'active' ? '停用' : '启用' }}
              </a-button>
              <a-button type="link" size="small" @click="openResetDialog(record)">
                重置密码
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </section>

    <a-modal
      v-model:open="modalOpen"
      :title="modalMode === 'create' ? '新增账号' : '编辑账号'"
      :confirm-loading="submitting"
      :ok-button-props="{ disabled: submitting }"
      :mask-closable="false"
      ok-text="确定"
      cancel-text="取消"
      @ok="submitUser"
    >
      <div class="account-form">
        <div class="form-field">
          <label for="user-username">账号</label>
          <a-input
            id="user-username"
            v-model:value="form.username"
            :disabled="modalMode === 'edit'"
            placeholder="请输入账号"
          />
        </div>

        <div v-if="modalMode === 'create'" class="form-field">
          <label for="user-password">初始密码</label>
          <a-input-password
            id="user-password"
            v-model:value="form.password"
            placeholder="请输入初始密码"
          />
          <p class="field-hint">初始密码至少 6 位，请告知使用人</p>
        </div>

        <div class="form-field">
          <label for="user-name">姓名</label>
          <a-input id="user-name" v-model:value="form.displayName" placeholder="请输入姓名" />
        </div>

        <div class="form-field">
          <label for="user-role">角色</label>
          <a-select
            id="user-role"
            v-model:value="form.roleCode"
            :options="roleOptions"
            @change="form.hostId = form.roleCode === 'host' ? form.hostId : undefined"
          />
        </div>

        <template v-if="form.roleCode === 'host'">
          <div class="form-field">
            <label for="user-host">绑定教职工</label>
            <a-select
              id="user-host"
              v-model:value="form.hostId"
              :options="hostOptions"
              show-search
              option-filter-prop="label"
              placeholder="请选择教职工"
            />
          </div>
          <div class="form-field">
            <label for="user-department">部门</label>
            <a-input id="user-department" v-model:value="form.department" placeholder="请输入部门" />
          </div>
        </template>

        <div class="form-field">
          <label for="user-phone">联系电话</label>
          <a-input id="user-phone" v-model:value="form.phone" placeholder="请输入联系电话" />
        </div>
      </div>
    </a-modal>

    <ConfirmDialog
      ref="statusDialog"
      title="确认停用账号"
      content="停用后该账号不能登录，历史记录保留。可再次启用。是否继续？"
      :danger="statusNext === 'inactive'"
      @confirm="confirmStatus"
    />

    <ConfirmDialog
      ref="resetDialog"
      title="重置密码"
      content="密码已重置，请告知使用人"
      @confirm="confirmReset"
    />

    <a-modal
      v-model:open="permissionsOpen"
      title="角色权限"
      :footer="null"
      width="720px"
    >
      <p class="permissions-note">管理员拥有全部权限；门卫与被访教职工的权限固定如下</p>
      <a-select
        v-model:value="selectedRoleCode"
        class="permissions-role-select"
        :options="roles.map((role) => ({ value: role.code, label: roleLabel(role.code) }))"
      />
      <a-table
        row-key="code"
        size="small"
        :columns="permissionColumns"
        :data-source="permissionRows"
        :pagination="false"
        :scroll="{ y: 360 }"
      >
        <template #bodyCell="{ column }">
          <template v-if="column.key === 'scope'">{{ roleScope }}</template>
        </template>
      </a-table>
    </a-modal>
  </div>
</template>

<style scoped>
.users-page {
  min-width: 0;
}

.table-card {
  padding: var(--space-4);
  overflow: hidden;
}

.account-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding-top: 4px;
}

.form-field label {
  display: block;
  margin-bottom: 7px;
  color: var(--color-text-primary);
  font-weight: 550;
}

.field-hint {
  margin-top: 5px;
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

.permissions-note {
  margin-bottom: 16px;
  color: var(--color-text-secondary);
}

.permissions-role-select {
  width: 220px;
  margin-bottom: 16px;
}
</style>
