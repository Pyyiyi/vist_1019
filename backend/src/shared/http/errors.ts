import { MESSAGES } from '../constants/messages.js';

export class AppError extends Error {
  constructor(
    public httpStatus: number,
    public code: number,
    message: string,
    public field?: string
  ) {
    super(message);
    this.name = 'AppError';
    Error.captureStackTrace(this, AppError);
  }
}

export function badRequest(message: string, field?: string): AppError {
  return new AppError(400, 42201, message, field);
}

export function unauthorized(message = MESSAGES.UNAUTHORIZED): AppError {
  return new AppError(401, 40101, message);
}

export function forbidden(message = MESSAGES.FORBIDDEN, field?: string): AppError {
  return new AppError(403, 40301, message, field);
}

export function notFound(message = MESSAGES.NOT_FOUND): AppError {
  return new AppError(404, 40401, message);
}

export function conflict(message = MESSAGES.CONFLICT): AppError {
  return new AppError(409, 40901, message);
}

export function methodNotAllowed(message = MESSAGES.METHOD_NOT_ALLOWED): AppError {
  return new AppError(405, 40501, message);
}

export function unprocessable(message: string, field: string): AppError {
  return new AppError(422, 42201, message, field);
}
