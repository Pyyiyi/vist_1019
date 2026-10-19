<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import zhCN from 'ant-design-vue/es/locale/zh_CN';

import AppLayout from '@/layouts/AppLayout.vue';
import H5Layout from '@/layouts/H5Layout.vue';
import { accessiblePaginationItem } from '@/utils/pagination';

const paginationConfig = { itemRender: accessiblePaginationItem };

const route = useRoute();
const layout = computed(() => route.meta.layout ?? 'app');
</script>

<template>
  <a-config-provider :locale="zhCN" :auto-insert-space-in-button="false" :pagination="paginationConfig">
    <a-app>
      <H5Layout v-if="layout === 'h5'">
        <router-view />
      </H5Layout>
      <AppLayout v-else-if="layout === 'app'">
        <router-view />
      </AppLayout>
      <router-view v-else />
    </a-app>
  </a-config-provider>
</template>
