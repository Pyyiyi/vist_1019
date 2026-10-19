export const DEFAULT_MAX_FAILURES = 5;
export const DEFAULT_LOCK_MINUTES = 10;

export type FailureState = {
  failedLoginCount: number;
  lockedUntil: Date | null;
  locked: boolean;
};

export function isLockActive(lockedUntil: Date | null, now = new Date()): boolean {
  return lockedUntil !== null && lockedUntil.getTime() > now.getTime();
}

export function nextFailureState(
  currentFailures: number,
  maxFailures = DEFAULT_MAX_FAILURES,
  lockMinutes = DEFAULT_LOCK_MINUTES,
  now = new Date(),
): FailureState {
  const failedLoginCount = Math.max(0, currentFailures) + 1;
  const locked = failedLoginCount >= maxFailures;
  return {
    failedLoginCount,
    lockedUntil: locked
      ? new Date(now.getTime() + lockMinutes * 60_000)
      : null,
    locked,
  };
}

export function isPasswordLongEnough(password: string, minimum = 6): boolean {
  return password.length >= minimum;
}
