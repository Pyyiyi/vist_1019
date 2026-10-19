import { logger } from '../../shared/logger.js';
import { registerJob } from '../../shared/jobs/scheduler.js';
import { cleanupAuditLogs } from './internal/audit.service.js';

export {
  SENSITIVE_AUDIT_ACTIONS,
  cleanupAuditLogs,
  listAuditLogs,
  mapAuditLog,
  parseAuditFilters,
} from './internal/audit.service.js';
export {
  eraseAppointmentPrivacy,
  getPrivacyRetention,
  getVisitorPrivacyCopy,
  listPrivacyCases,
  parseEraseReason,
  parseRetentionDays,
  updatePrivacyRetention,
} from './internal/privacy.service.js';

export type AppointmentSummaryDto = {
  id: string;
  appointNo: string;
  visitorName: string | null;
  status: string;
  visitStart: string;
  visitEnd: string;
  hostId: string;
  reviewerId: string | null;
};

registerJob({
  name: 'audit-cleanup',
  cron: '10 3 * * *',
  runOnStart: false,
  handler: async () => {
    const deleted = await cleanupAuditLogs(new Date(), 365);
    logger.info('审计日志清理完成', { deleted, retention_days: 365 });
  },
});
