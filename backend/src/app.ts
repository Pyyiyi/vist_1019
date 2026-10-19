import express from 'express';

const app = express();

app.use(express.json());

app.get('/api/v1/health', (_request, response) => {
  response.json({ code: 0, message: '操作成功', data: { status: 'ok' } });
});

export default app;
