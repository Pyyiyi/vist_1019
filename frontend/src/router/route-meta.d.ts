import 'vue-router';

declare module 'vue-router' {
  interface RouteMeta {
    layout?: 'app' | 'h5' | 'blank';
    roles?: string[];
    title?: string;
  }
}
