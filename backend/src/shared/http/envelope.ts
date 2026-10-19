import type { Response } from 'express';

import { MESSAGES } from '../constants/messages.js';

export function success<T>(res: Response, data: T, message = MESSAGES.SUCCESS): Response {
  return res.status(200).json({ code: 0, message, data });
}

export function fail(
  res: Response,
  httpStatus: number,
  code: number,
  message: string,
  field?: string
): Response {
  const body: { code: number; message: string; data: null; field?: string } = {
    code,
    message,
    data: null,
  };

  if (field !== undefined) {
    body.field = field;
  }

  return res.status(httpStatus).json(body);
}

export function paginated<T>(
  res: Response,
  items: T[],
  total: number,
  page: number,
  pageSize: number
): Response {
  return success(res, { items, total, page, page_size: pageSize });
}
