import { getConfig as kernelGetConfig, getConfigNumber as kernelGetConfigNumber } from '../../shared/config/configService.js';
import { registerJob } from '../../shared/jobs/scheduler.js';
import * as blacklistRepo from './internal/blacklist.repo.js';
import { checkBlacklist, expireBlacklistEntries } from './internal/blacklist.service.js';
import * as dictionaryRepo from './internal/dictionary.repo.js';
import { timeRuleDecision } from './internal/domain/rules.js';
import * as gatesRepo from './internal/gates.repo.js';
import * as hostsRepo from './internal/hosts.repo.js';
import type {
  DictionaryItemDto,
  GateDto,
  HostDto,
  ReviewerRuleDto,
  VisitorTypeDto,
} from './internal/master.types.js';
import { resolveReviewer, upsertReviewerRules } from './internal/reviewer-rules.service.js';
import * as visitorTypesRepo from './internal/visitor-types.repo.js';

export type {
  DictionaryItemDto,
  GateDto,
  HostDto,
  ReviewerRuleDto,
  VisitorTypeDto,
};
export { timeRuleDecision };

export async function getActiveVisitorTypes(): Promise<VisitorTypeDto[]> {
  return visitorTypesRepo.listVisitorTypes({ status: 'active', includeInactive: false });
}

export async function getActiveHosts(): Promise<HostDto[]> {
  return hostsRepo.listHosts({ status: 'active', includeInactive: false });
}

export async function getActiveGates(): Promise<GateDto[]> {
  return gatesRepo.listGates({ status: 'active', includeInactive: false });
}

export async function getDictionaryItems(dictType: string): Promise<DictionaryItemDto[]> {
  return dictionaryRepo.listDictionary({ dictType, includeInactive: false });
}

export const getConfig = kernelGetConfig;
export const getConfigNumber = kernelGetConfigNumber;
export { checkBlacklist, expireBlacklistEntries, resolveReviewer, upsertReviewerRules };

registerJob({
  name: 'blacklist-expire',
  cron: '10 0 * * *',
  runOnStart: false,
  handler: async () => {
    await expireBlacklistEntries(new Date());
  },
});
