import { Router } from 'express';
import QRCode from 'qrcode';

import { MESSAGES } from '../../../shared/constants/messages.js';
import { query } from '../../../shared/db/pool.js';
import { asyncHandler } from '../../../shared/http/asyncHandler.js';
import { success } from '../../../shared/http/envelope.js';
import { AppError } from '../../../shared/http/errors.js';
import { requireAdmin } from '../../../shared/middleware/requirePermission.js';

type EntryUrlRow = { config_value: string };

const router = Router();
async function currentEntryUrl(): Promise<string> {
  const result = await query<EntryUrlRow>(
    "SELECT config_value FROM system_config WHERE config_key = 'entry_url' LIMIT 1",
  );
  const value = result.rows[0]?.config_value;
  if (!value) {
    throw new AppError(500, 50001, MESSAGES.INTERNAL_ERROR);
  }
  return value;
}

router.get(
  '/system/entry-qr',
  requireAdmin,
  asyncHandler(async (_req, res) => {
    const entryUrl = await currentEntryUrl();
    const qrDataUrl = await QRCode.toDataURL(entryUrl, {
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 320,
    });
    return success(res, { entry_url: entryUrl, qr_data_url: qrDataUrl });
  }),
);

router.get(
  '/system/entry-qr.png',
  requireAdmin,
  asyncHandler(async (_req, res) => {
    const entryUrl = await currentEntryUrl();
    const png = await QRCode.toBuffer(entryUrl, {
      type: 'png',
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 640,
    });
    res.type('image/png').send(png);
  }),
);

export default router;
