import type { RequestHandler, Response } from 'express';

import { fail, paginated, success } from './envelope.js';

declare global {
  namespace Express {
    interface Response {
      success<T>(data: T, message?: string): Response;
      fail(httpStatus: number, code: number, message: string, field?: string): Response;
      paginated<T>(items: T[], total: number, page: number, pageSize: number): Response;
    }
  }
}

export const responseEnvelope: RequestHandler = (_req, res, next) => {
  res.success = function <T>(data: T, message?: string): Response {
    return success(this, data, message);
  };
  res.fail = function (
    httpStatus: number,
    code: number,
    message: string,
    field?: string
  ): Response {
    return fail(this, httpStatus, code, message, field);
  };
  res.paginated = function <T>(
    items: T[],
    total: number,
    page: number,
    pageSize: number
  ): Response {
    return paginated(this, items, total, page, pageSize);
  };

  next();
};
