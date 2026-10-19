import { body } from 'express-validator';
import { isValidIdCard, isValidOtherId } from '../../../shared/validation/validators.js';
import { COPY } from '../internal/domain/rules.js';

const idNo = () => body('visitor_id_no')
  .isString().withMessage(COPY.ID_REQUIRED)
  .trim().notEmpty().withMessage(COPY.ID_REQUIRED)
  .custom((value: string) => isValidIdCard(value) || isValidOtherId(value)).withMessage(COPY.ID_INVALID);

export const appointmentPayloadRules = [
  body('visitor_name').isString().withMessage(COPY.NAME_REQUIRED).trim().notEmpty().withMessage(COPY.NAME_REQUIRED).isLength({ max: 20 }).withMessage(COPY.NAME_TOO_LONG),
  body('visitor_phone').isString().withMessage(COPY.PHONE_REQUIRED).trim().notEmpty().withMessage(COPY.PHONE_REQUIRED).matches(/^1\d{10}$/).withMessage(COPY.PHONE_INVALID),
  idNo(),
  body('visitor_type_id').isString().withMessage(COPY.TYPE_REQUIRED).trim().notEmpty().withMessage(COPY.TYPE_REQUIRED),
  body('host_id').isString().withMessage(COPY.HOST_REQUIRED).trim().notEmpty().withMessage(COPY.HOST_REQUIRED),
  body('visit_start').isString().withMessage(COPY.START_REQUIRED).notEmpty().withMessage(COPY.START_REQUIRED),
  body('visit_end').isString().withMessage(COPY.END_REQUIRED).notEmpty().withMessage(COPY.END_REQUIRED),
  body('reason').isString().withMessage(COPY.REASON_REQUIRED).trim().notEmpty().withMessage(COPY.REASON_REQUIRED).isLength({ min: 2 }).withMessage(COPY.REASON_SHORT).isLength({ max: 100 }).withMessage(COPY.REASON_LONG),
  body('companions').optional().isArray({ max: 10 }).withMessage(COPY.COMPANION_LIMIT),
];

export const walkInRules = [appointmentPayloadRules[0], appointmentPayloadRules[1], appointmentPayloadRules[2], appointmentPayloadRules[3], appointmentPayloadRules[4], appointmentPayloadRules[7], appointmentPayloadRules[8]];

export const rescheduleRules = [
  body('visit_start').isString().withMessage(COPY.START_REQUIRED).notEmpty().withMessage(COPY.START_REQUIRED),
  body('visit_end').isString().withMessage(COPY.END_REQUIRED).notEmpty().withMessage(COPY.END_REQUIRED),
];

export const rejectRules = [
  body('reason').isString().withMessage('请填写拒绝原因').trim().notEmpty().withMessage('请填写拒绝原因').isLength({ min: 2 }).withMessage('拒绝原因至少 2 个字符').isLength({ max: 100 }).withMessage('拒绝原因不能超过 100 个字符'),
];

export const codeRules = [
  body('code').isString().withMessage('请输入预约编号或 6 位短码').trim().notEmpty().withMessage('请输入预约编号或 6 位短码'),
  body('gate_id').isString().withMessage('请选择校门').trim().notEmpty().withMessage('请选择校门'),
];

export const incidentRules = [
  body('incident_type').isString().withMessage('请选择异常类型').notEmpty().withMessage('请选择异常类型'),
  body('description').isString().withMessage('请描述现场情况').trim().notEmpty().withMessage('请描述现场情况'),
];
