import ExcelJS from 'exceljs';
import { describe, expect, it } from 'vitest';

import {
  LEDGER_EXPORT_COLUMNS,
  buildCsv,
  buildXlsx,
  exportFileName,
} from '../internal/export.service.js';
import type { LedgerItem } from '../internal/ledger.service.js';

const item: LedgerItem = {
  appointmentId: 'a-1',
  appointNo: 'AP20261012001',
  visitorName: '陈晨',
  visitorType: '公务访客',
  visitorPhone: '13800138000',
  visitorIdNoMasked: '1101**********1233',
  hostName: '李明',
  visitStart: '2026-10-12T10:00:00+08:00',
  visitEnd: '2026-10-12T11:00:00+08:00',
  checkinAt: '2026-10-12T10:03:00+08:00',
  checkoutAt: '2026-10-12T10:50:00+08:00',
  status: '已离校',
  reason: '沟通, 并参观',
};

describe('report export', () => {
  it('CSV 带 UTF-8 BOM 且固定 11 列', () => {
    const csv = buildCsv([item]);
    expect(csv.startsWith('\uFEFF')).toBe(true);
    expect(csv).toContain(LEDGER_EXPORT_COLUMNS.join(','));
    expect(csv).toContain('"沟通, 并参观"');
    expect(csv).toContain('1101**********1233');
    expect(csv).not.toContain('110101199003071233');
  });

  it('CSV 零行仍返回表头', () => {
    const csv = buildCsv([]);
    expect(csv.replace('\uFEFF', '').trim().split('\r\n')).toHaveLength(1);
    expect(csv).toContain('预约编号,姓名,访客类型');
  });

  it('XLSX 为真实 ZIP 且首行 11 列', async () => {
    const buffer = await buildXlsx([item]);
    expect(buffer.subarray(0, 4).toString('hex')).toBe('504b0304');

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer as never);
    const sheet = workbook.getWorksheet('访客台账');
    const headerValues = sheet!.getRow(1).values as unknown[];
    expect(headerValues.slice(1)).toEqual([...LEDGER_EXPORT_COLUMNS]);
    expect(sheet!.getRow(2).getCell(5).value).toBe('1101**********1233');
  });

  it('文件名使用本地 14 位时间戳', () => {
    expect(exportFileName('csv', new Date('2026-10-12T13:14:15+08:00'))).toBe(
      '访客台账_20261012_131415.csv',
    );
    expect(exportFileName('xlsx', new Date('2026-10-12T13:14:15+08:00'))).toBe(
      '访客台账_20261012_131415.xlsx',
    );
  });
});
