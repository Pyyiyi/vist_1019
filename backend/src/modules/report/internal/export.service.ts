import ExcelJS from 'exceljs';

import { formatMinute, formatSecond } from '../../../shared/utils/ids.js';
import type { LedgerItem } from './ledger.service.js';

export type ExportFormat = 'csv' | 'xlsx';

export const LEDGER_EXPORT_COLUMNS = [
  '预约编号',
  '姓名',
  '访客类型',
  '手机号',
  '证件号',
  '被访人',
  '到访时段',
  '进校时刻',
  '离校时刻',
  '状态',
  '事由',
] as const;

function text(value: string | null | undefined): string {
  return value ?? '';
}

function timestamp(value: Date | string | null): string {
  return value ? formatMinute(value) : '';
}

export function visitPeriod(item: LedgerItem): string {
  return `${formatMinute(item.visitStart)} - ${formatMinute(item.visitEnd)}`;
}

export function ledgerExportRow(item: LedgerItem): string[] {
  return [
    item.appointNo,
    text(item.visitorName),
    item.visitorType,
    text(item.visitorPhone),
    item.visitorIdNoMasked,
    item.hostName,
    visitPeriod(item),
    timestamp(item.checkinAt),
    timestamp(item.checkoutAt),
    item.status,
    item.reason,
  ];
}

function csvCell(value: string): string {
  if (/[",\r\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

export function buildCsv(items: LedgerItem[]): string {
  const rows = [
    [...LEDGER_EXPORT_COLUMNS],
    ...items.map(ledgerExportRow),
  ];
  return `\uFEFF${rows.map((row) => row.map(csvCell).join(',')).join('\r\n')}\r\n`;
}

export async function buildXlsx(items: LedgerItem[]): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet('访客台账');
  worksheet.addRow([...LEDGER_EXPORT_COLUMNS]);
  for (const item of items) {
    worksheet.addRow(ledgerExportRow(item));
  }
  worksheet.getRow(1).font = { bold: true };
  worksheet.columns.forEach((column, index) => {
    const width = LEDGER_EXPORT_COLUMNS[index] === '到访时段' ? 36 : 18;
    column.width = width;
  });
  const data = await workbook.xlsx.writeBuffer();
  return Buffer.from(data as ArrayBuffer);
}

export function exportFileName(format: ExportFormat, now: Date = new Date()): string {
  const [datePart, timePart] = formatSecond(now).split(' ');
  const stamp = `${datePart.replace(/-/g, '')}_${timePart.replace(/:/g, '')}`;
  return `访客台账_${stamp}.${format}`;
}
