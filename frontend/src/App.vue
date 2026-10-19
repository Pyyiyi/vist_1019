<script setup lang="ts">
import zhCN from 'ant-design-vue/es/locale/zh_CN';
import AppLayout from '@/layouts/AppLayout.vue';
import H5Layout from '@/layouts/H5Layout.vue';
import PageHeader from '@/components/PageHeader.vue';

const isH5 =
  typeof window !== 'undefined' && window.location.pathname.startsWith('/h5');
</script>

<template>
  <a-config-provider :locale="zhCN" :auto-insert-space-in-button="false">
    <H5Layout v-if="isH5">
      <PageHeader title="校园访客系统" />
    </H5Layout>
    <AppLayout v-else>
      <PageHeader title="校园访客系统" />
    </AppLayout>
  </a-config-provider>
</template>
