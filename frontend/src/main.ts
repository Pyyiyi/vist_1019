import { createApp } from 'vue';
import { createPinia } from 'pinia';
import Antd from 'ant-design-vue';
import dayjs from 'dayjs';
import 'dayjs/locale/zh-cn';
import 'ant-design-vue/dist/reset.css';
import '@/styles/reset.css';
import '@/styles/tokens.css';
import '@/styles/print.css';
import App from './App.vue';

dayjs.locale('zh-cn');

const app = createApp(App);

app.use(createPinia());
app.use(Antd);
app.mount('#app');
