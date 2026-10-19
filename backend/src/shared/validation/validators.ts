import type { Request, RequestHandler } from 'express';
import { validationResult, type ValidationChain } from 'express-validator';

import { unprocessable } from '../http/errors.js';

const ID_CARD_PATTERN = /^\d{17}[\dXx]$/;
const ID_CARD_WEIGHTS = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
const ID_CARD_CHECKSUMS = ['1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2'];

async function runRules(req: Request, rules: ValidationChain[]): Promise<void> {
  for (const rule of rules) {
    await rule.run(req);
  }
}

function validationError(req: Request): ReturnType<typeof unprocessable> | null {
  const result = validationResult(req);
  if (result.isEmpty()) {
    return null;
  }

  const first = result.array({ onlyFirstError: true })[0] as
    | { msg?: unknown; path?: string; param?: string }
    | undefined;
  const message = first?.msg === undefined ? '请求参数不正确' : String(first.msg);
  const rawField = first?.path ?? first?.param ?? 'body';
  return unprocessable(message, String(rawField));
}

function validationMiddleware(rules: ValidationChain[]): RequestHandler {
  return (req, _res, next) => {
    void runRules(req, rules)
      .then(() => {
        const error = validationError(req);
        if (error) {
          next(error);
          return;
        }
        next();
      })
      .catch(next);
  };
}

export function validateBody(rules: ValidationChain[]): RequestHandler {
  return validationMiddleware(rules);
}

export function validateQuery(rules: ValidationChain[]): RequestHandler {
  return validationMiddleware(rules);
}

export function normalizeIdNo(value: string): string {
  return value.replace(/\s+/g, '').toUpperCase();
}

export function isValidIdCard(value: string): boolean {
  const normalized = normalizeIdNo(value);
  if (!ID_CARD_PATTERN.test(normalized)) {
    return false;
  }

  const total = ID_CARD_WEIGHTS.reduce(
    (sum, weight, index) => sum + Number(normalized[index]) * weight,
    0
  );
  return ID_CARD_CHECKSUMS[total % 11] === normalized[17];
}

export function isValidPhone(value: string): boolean {
  return /^1\d{10}$/.test(value.trim());
}

export function isValidOtherId(value: string): boolean {
  return /^[A-Za-z0-9]{5,20}$/.test(value.trim());
}
