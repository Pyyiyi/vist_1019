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
  'master:visitor-type:manage',
  'master:blacklist:manage',
  'master:time-rule:manage',
  'master:gate:manage',
  'master:host:manage',
  'master:reviewer-rule:manage',
  'notify:notification:read',
  'notify:channel:manage',
  'system:param:manage',
  'system:dictionary:manage',
  'compliance:audit:read',
  'compliance:privacy:manage',
] as const;

export type PermissionCode = (typeof PERMISSIONS)[number];
export type RoleCode = 'admin' | 'guard' | 'host' | 'visitor';

const PERMISSION_FORMAT = /^[a-z][a-z0-9-]*(?::[a-z][a-z0-9-]*){2,}$/;

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
