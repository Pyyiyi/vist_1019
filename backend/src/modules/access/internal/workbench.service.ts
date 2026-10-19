import type { AuthenticatedUser } from '../../../shared/auth/types.js';
import { query } from '../../../shared/db/pool.js';
import { formatMinute, localDayRange } from '../../../shared/utils/ids.js';

type CountRow = { count: number };
type AppointmentTodoRow = {
  id: string;
  appoint_no: string;
  visitor_name: string | null;
  visit_start: Date | string;
  status: string;
};
type IncidentTodoRow = {
  id: string;
  incident_type: string;
  description: string;
  created_at: Date | string;
  visitor_name: string | null;
};

export type WorkbenchTodo = {
  id: string;
  kind: 'review' | 'verify' | 'incident';
  title: string;
  time: string;
  status: string;
  path: string;
};

export type WorkbenchSummary = {
  role: string;
  todo: {
    pendingReview: number;
    pendingVerify: number;
    pendingIncident: number;
  };
  kpi: {
    todayAppointments: number;
    onCampus: number;
  };
  unreadCount: number;
  todos: WorkbenchTodo[];
};

async function count(sql: string, params: unknown[] = []): Promise<number> {
  const result = await query<CountRow>(sql, params);
  return result.rows[0]?.count ?? 0;
}

function hostAppointmentScope(user: AuthenticatedUser, params: unknown[]): string {
  const actorIndex = params.length + 1;
  params.push(user.id);
  const hostIndex = params.length + 1;
  params.push(user.hostId);
  return `(a.reviewer_id = $${actorIndex} OR a.created_by = $${actorIndex} OR a.host_id = $${hostIndex})`;
}

async function pendingReviewCount(user: AuthenticatedUser): Promise<number> {
  if (user.roleCode === 'admin') {
    return count("SELECT COUNT(*)::int AS count FROM appointments a WHERE a.status = '待审核'");
  }
  if (user.roleCode !== 'host') {
    return 0;
  }
  const params: unknown[] = [];
  const scope = hostAppointmentScope(user, params);
  return count(
    `SELECT COUNT(*)::int AS count FROM appointments a
      WHERE a.status = '待审核' AND ${scope}`,
    params,
  );
}

async function pendingVerifyCount(): Promise<number> {
  const range = localDayRange(new Date());
  return count(
    `SELECT COUNT(*)::int AS count FROM appointments a
      WHERE a.status = '已通过'
        AND a.checkin_at IS NULL
        AND a.visit_start >= $1
        AND a.visit_start <= $2`,
    [range.start, range.end],
  );
}

async function pendingIncidentCount(): Promise<number> {
  return count("SELECT COUNT(*)::int AS count FROM incidents WHERE status = '待处理'");
}

async function todayAppointmentCount(user: AuthenticatedUser): Promise<number> {
  const range = localDayRange(new Date());
  const params: unknown[] = [range.start, range.end];
  let scope = 'TRUE';
  if (user.roleCode === 'host') {
    scope = hostAppointmentScope(user, params);
  }
  return count(
    `SELECT COUNT(*)::int AS count FROM appointments a
      WHERE a.visit_start >= $1 AND a.visit_start <= $2 AND ${scope}`,
    params,
  );
}

async function onCampusCount(): Promise<number> {
  return count(
    "SELECT COUNT(*)::int AS count FROM appointments a WHERE a.status = '已到访(在校中)'",
  );
}

async function unreadCount(userId: string): Promise<number> {
  return count(
    `SELECT COUNT(*)::int AS count FROM notifications
      WHERE recipient_type = 'user' AND recipient_id = $1 AND read_at IS NULL`,
    [userId],
  );
}

async function reviewTodos(user: AuthenticatedUser): Promise<WorkbenchTodo[]> {
  if (user.roleCode !== 'admin' && user.roleCode !== 'host') {
    return [];
  }
  const params: unknown[] = [];
  const scope = user.roleCode === 'host' ? hostAppointmentScope(user, params) : 'TRUE';
  params.push(10);
  const result = await query<AppointmentTodoRow>(
    `SELECT a.id, a.appoint_no, a.visitor_name, a.visit_start, a.status
       FROM appointments a
      WHERE a.status = '待审核' AND ${scope}
      ORDER BY a.visit_start ASC, a.created_at ASC
      LIMIT $${params.length}`,
    params,
  );
  return result.rows.map((row) => ({
    id: row.id,
    kind: 'review',
    title: `访客 ${row.visitor_name ?? row.appoint_no} 等待审核`,
    time: formatMinute(row.visit_start),
    status: row.status,
    path: '/reviews',
  }));
}

async function verifyTodos(): Promise<WorkbenchTodo[]> {
  const range = localDayRange(new Date());
  const result = await query<AppointmentTodoRow>(
    `SELECT a.id, a.appoint_no, a.visitor_name, a.visit_start, a.status
       FROM appointments a
      WHERE a.status = '已通过'
        AND a.checkin_at IS NULL
        AND a.visit_start >= $1
        AND a.visit_start <= $2
      ORDER BY a.visit_start ASC, a.created_at ASC
      LIMIT 10`,
    [range.start, range.end],
  );
  return result.rows.map((row) => ({
    id: row.id,
    kind: 'verify',
    title: `访客 ${row.visitor_name ?? row.appoint_no} 等待核验`,
    time: formatMinute(row.visit_start),
    status: row.status,
    path: '/gate',
  }));
}

async function incidentTodos(): Promise<WorkbenchTodo[]> {
  const result = await query<IncidentTodoRow>(
    `SELECT i.id, i.incident_type, i.description, i.created_at, a.visitor_name
       FROM incidents i
       LEFT JOIN appointments a ON a.id = i.appointment_id
      WHERE i.status = '待处理'
      ORDER BY i.created_at ASC
      LIMIT 10`,
  );
  return result.rows.map((row) => ({
    id: row.id,
    kind: 'incident',
    title: `${row.incident_type}${row.visitor_name ? ` · ${row.visitor_name}` : ''} 待处理`,
    time: formatMinute(row.created_at),
    status: '待处理',
    path: '/gate',
  }));
}

export async function getWorkbenchSummary(
  user: AuthenticatedUser,
): Promise<WorkbenchSummary> {
  const canUseGate = user.roleCode === 'admin' || user.roleCode === 'guard';
  const canReview = user.roleCode === 'admin' || user.roleCode === 'host';

  const [pendingReview, pendingVerify, pendingIncident, todayAppointments, onCampus, unread] =
    await Promise.all([
      pendingReviewCount(user),
      canUseGate ? pendingVerifyCount() : Promise.resolve(0),
      canUseGate ? pendingIncidentCount() : Promise.resolve(0),
      canReview ? todayAppointmentCount(user) : Promise.resolve(0),
      canUseGate ? onCampusCount() : Promise.resolve(0),
      unreadCount(user.id),
    ]);

  const [reviews, verifies, incidents] = await Promise.all([
    reviewTodos(user),
    canUseGate ? verifyTodos() : Promise.resolve([]),
    canUseGate ? incidentTodos() : Promise.resolve([]),
  ]);

  const todos = [...reviews, ...verifies, ...incidents].sort((left, right) =>
    left.time.localeCompare(right.time),
  );

  return {
    role: user.roleCode,
    todo: {
      pendingReview,
      pendingVerify,
      pendingIncident,
    },
    kpi: {
      todayAppointments,
      onCampus,
    },
    unreadCount: unread,
    todos: todos.slice(0, 20),
  };
}
