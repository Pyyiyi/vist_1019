import { Router } from 'express';

import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { paginated, success } from '../../../shared/http/envelope.js';
import { unprocessable } from '../../../shared/http/errors.js';
import { requirePermission } from '../../../shared/middleware/requirePermission.js';
import { buildCsv, buildXlsx, exportFileName, type ExportFormat } from '../internal/export.service.js';
import { listLedger, listLedgerForExport, listOnCampus, type LedgerItem } from '../internal/ledger.service.js';

const router = Router();

function apiLedgerItem(item: LedgerItem): Record<string, unknown> {
  return {
    appointment_id: item.appointmentId,
    appoint_no: item.appointNo,
    visitor_name: item.visitorName,
    visitor_type: item.visitorType,
    visitor_phone: item.visitorPhone,
    visitor_id_no_masked: item.visitorIdNoMasked,
    host_name: item.hostName,
    visit_start: item.visitStart,
    visit_end: item.visitEnd,
    checkin_at: item.checkinAt,
    checkout_at: item.checkoutAt,
    status: item.status,
    reason: item.reason,
  };
}

function requestedFormat(value: unknown): ExportFormat {
  if (value === 'csv' || value === 'xlsx') {
    return value;
  }
  throw unprocessable('导出格式不正确', 'format');
}

router.get(
  '/logs/on-campus',
  requirePermission('report:ledger:read'),
  asyncHandler(async (req, res) => {
    const items = await listOnCampus(req.currentUser!);
    return success(res, { items: items.map(apiLedgerItem) });
  }),
);

router.get(
  '/logs/export',
  requirePermission('report:ledger:export'),
  asyncHandler(async (req, res) => {
    const format = requestedFormat(req.query.format);
    const items = await listLedgerForExport(req.query, req.currentUser!);
    const fileName = exportFileName(format);
    const stamp = fileName.match(/_(\d{8}_\d{6})\./)?.[1] ?? 'export';
    const asciiName = `visitor-ledger_${stamp}.${format}`;
    const body = format === 'csv' ? buildCsv(items) : await buildXlsx(items);

    res.setHeader(
      'Content-Type',
      format === 'csv'
        ? 'text/csv; charset=utf-8'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${asciiName}"; filename*=UTF-8''${encodeURIComponent(fileName)}`,
    );
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
    return res.status(200).send(body);
  }),
);

router.get(
  '/logs',
  requirePermission('report:ledger:read'),
  asyncHandler(async (req, res) => {
    const result = await listLedger(req.query, req.currentUser!);
    return paginated(
      res,
      result.items.map(apiLedgerItem),
      result.total,
      result.page,
      result.pageSize,
    );
  }),
);

export default router;
