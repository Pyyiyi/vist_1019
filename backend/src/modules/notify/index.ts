import { registerJob } from '../../shared/jobs/scheduler.js';
import { runOverdueJob, runReminderJob } from './internal/notification.service.js';

export type {
  ChannelActor,
  NotificationChannelDto,
  NotificationDto,
  NotificationListInput,
  PublishNotificationInput,
  UpdateChannelInput,
} from './internal/notification.service.js';
export type { NotificationTemplateType, RenderedTemplate } from './internal/domain/templates.js';
export {
  listNotificationChannels,
  listNotificationsForUser,
  listNotificationsForVisitor,
  markAllReadForUser,
  markReadForUser,
  publishNotification,
  publishSecurityNotification,
  runOverdueJob,
  runReminderJob,
  unreadCountForUser,
  updateNotificationChannels,
} from './internal/notification.service.js';

export {
  isNotificationTemplateType,
  isSecurityTemplate,
  NOTIFICATION_TEMPLATE_TYPES,
  renderTemplate,
  SECURITY_TEMPLATE_TYPES,
} from './internal/domain/templates.js';

registerJob({
  name: 'reminder',
  cron: '* * * * *',
  runOnStart: false,
  handler: runReminderJob,
});

registerJob({
  name: 'overdue',
  cron: '* * * * *',
  runOnStart: false,
  handler: runOverdueJob,
});
