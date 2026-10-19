export const PERMISSIONS = [
  'pt:workbench:read',
  'pt:qr:manage',
  'visit:appointment:create',
  'visit:appointment:read',
  'visit:appointment:update',
  'visit:appointment:cancel',
  'visit:review:read',
  'visit:review:decide',
  'visit:review:reschedule',
  'visit:gate:today:read',
  'visit:gate:verify',
  'visit:gate:admit',
  'visit:gate:depart',
  'visit:gate:walkin',
  'visit:gate:incident:report',
  'visit:gate:incident:dispose',
  'report:ledger:read',
  'report:ledger:export',
  'report:stats:read',
  'access:user:manage',
  'access:role:read',
  'master:visitor_type:read',
  'master:visitor_type:create',
  'master:visitor_type:update',
  'master:visitor_type:status',
  'master:blacklist:read',
  'master:blacklist:create',
  'master:blacklist:delete',
  'master:time_rule:read',
  'master:time_rule:create',
  'master:time_rule:delete',
  'master:gate:read',
  'master:gate:create',
  'master:gate:update',
  'master:gate:status',
  'master:host:read',
  'master:host:create',
  'master:host:update',
  'master:host:status',
  'system:param:read',
  'system:param:update',
  'system:dictionary:read',
  'system:dictionary:create',
  'system:dictionary:status',
  'notify:notification:read',
  'notify:channel:manage',
  'system:param:manage',
  'system:dictionary:manage',
  'compliance:audit:read',
  'compliance:privacy:manage',
] as const;

export type PermissionCode = (typeof PERMISSIONS)[number];
export type RoleCode = 'admin' | 'guard' | 'host' | 'visitor';

const PERMISSION_FORMAT = /^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){2,}$/;

export const ROLE_PERMISSIONS: Readonly<Record<RoleCode, readonly PermissionCode[]>> = {
  admin: PERMISSIONS,
  guard: [
    'pt:workbench:read',
    'visit:gate:today:read',
    'visit:gate:verify',
    'visit:gate:admit',
    'visit:gate:depart',
    'visit:gate:walkin',
    'visit:gate:incident:report',
    'report:ledger:read',
    'notify:notification:read',
  ],
  host: [
    'pt:workbench:read',
    'visit:appointment:create',
    'visit:appointment:read',
    'visit:appointment:update',
    'visit:appointment:cancel',
    'visit:review:read',
    'visit:review:decide',
    'visit:review:reschedule',
    'notify:notification:read',
  ],
  visitor: [],
};

export function hasPermission(roleCode: string, permissionCode: string): boolean {
  if (!PERMISSION_FORMAT.test(permissionCode)) {
    return false;
  }

  if (roleCode === 'admin') {
    return true;
  }

  const permissions = ROLE_PERMISSIONS[roleCode as RoleCode];
  return permissions?.includes(permissionCode as PermissionCode) ?? false;
}
