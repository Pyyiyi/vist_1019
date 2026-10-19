import type { RequestHandler } from 'express';

import { MESSAGES } from '../constants/messages.js';
import { fail } from './envelope.js';

export const notFoundHandler: RequestHandler = (_req, res) => {
  fail(res, 404, 40401, MESSAGES.NOT_FOUND);
};
