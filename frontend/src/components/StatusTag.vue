<script setup lang="ts">
import { computed } from 'vue';

export type StatusKind = 'appointment' | 'incident' | 'soft';

const props = withDefaults(
  defineProps<{
    status: string;
    kind?: StatusKind;
  }>(),
  {
    kind: 'appointment',
  },
);

const appointmentColors: Record<string, string> = {
  待审核: 'gold',
  已通过: 'green',
  已拒绝: 'red',
  已改期: 'purple',
  已过期: 'default',
  '已到访(在校中)': 'blue',
  已离校: 'cyan',
  已取消: 'default',
};

const incidentColors: Record<string, string> = {
  待处理: 'gold',
  已处理: 'green',
  已忽略: 'default',
};

const softColors: Record<string, string> = {
  在用: 'green',
  停用: 'default',
};

const colorMaps: Record<StatusKind, Record<string, string>> = {
  appointment: appointmentColors,
  incident: incidentColors,
  soft: softColors,
};

const color = computed(() => colorMaps[props.kind][props.status] ?? 'default');
</script>

<template>
  <a-tag :color="color">{{ status }}</a-tag>
</template>
