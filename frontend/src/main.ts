import { createPinia } from 'pinia';
import { createApp } from 'vue';

import 'ant-design-vue/dist/reset.css';

import App from './App.vue';

createApp(App).use(createPinia()).mount('#app');
