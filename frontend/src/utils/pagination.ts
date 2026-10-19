import { cloneVNode, type VNode } from 'vue';

type PaginationItemType = 'page' | 'prev' | 'next' | 'jump-prev' | 'jump-next';
type PaginationItem = {
  page: number;
  type: PaginationItemType;
  originalElement: VNode;
};

const LABELS: Partial<Record<PaginationItemType, string>> = {
  prev: '上一页',
  next: '下一页',
  'jump-prev': '向前跳转 5 页',
  'jump-next': '向后跳转 5 页',
};

export function accessiblePaginationItem(item: PaginationItem): VNode {
  const label = LABELS[item.type];
  return label
    ? cloneVNode(item.originalElement, { 'aria-label': label })
    : item.originalElement;
}
