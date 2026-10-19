export const ACCOUNT_ROLES = ['admin', 'guard', 'host'] as const;
export type AccountRole = (typeof ACCOUNT_ROLES)[number];

export function isAccountRole(value: unknown): value is AccountRole {
  return typeof value === 'string' && (ACCOUNT_ROLES as readonly string[]).includes(value);
}

export function isSelfDeactivation(actorId: string, targetId: string, nextStatus: string): boolean {
  return actorId === targetId && nextStatus === 'inactive';
}

export function wouldRemoveLastAdmin(input: {
  targetRole: string;
  targetStatus: string;
  nextRole?: string;
  nextStatus?: string;
  activeAdminCount: number;
}): boolean {
  const wasActiveAdmin = input.targetRole === 'admin' && input.targetStatus === 'active';
  const remainsActiveAdmin =
    (input.nextRole ?? input.targetRole) === 'admin' &&
    (input.nextStatus ?? input.targetStatus) === 'active';
  return wasActiveAdmin && !remainsActiveAdmin && input.activeAdminCount <= 1;
}

export function normalizeHostBinding(role: string, hostId?: string | null): string | null {
  return role === 'host' ? hostId ?? null : null;
}
