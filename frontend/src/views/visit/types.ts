export type VisitorTypeOption = { id: string; name: string; code?: string };
export type HostOption = { id: string; name: string; department?: string };
export type GateOption = { id: string; name: string; code?: string };
export type RelationOption = { id: string; dictKey: string; dictLabel: string };

export type VisitFormOptions = {
  visitorTypes: VisitorTypeOption[];
  hosts: HostOption[];
  gates: GateOption[];
  relations: RelationOption[];
};

export type CompanionItem = { id?: string; name: string; relation: string; idNo: string; sortOrder?: number };

export type AppointmentItem = {
  id: string;
  appointNo: string;
  visitorTypeId: string;
  visitorTypeName?: string;
  visitorName: string | null;
  visitorPhone: string | null;
  visitorIdNo: string | null;
  hostId: string;
  hostName?: string;
  reviewerId: string | null;
  expectedGateId: string | null;
  gateName?: string | null;
  visitStart: string;
  visitEnd: string;
  reason: string;
  plateNo: string | null;
  status: string;
  peopleCount: number;
  blackHit: boolean;
  rescheduleProposedAt: string | null;
  rescheduleDeadline?: string | null;
  rejectReason: string | null;
  cancelReason: string | null;
  checkinAt: string | null;
  checkoutAt: string | null;
  createdAt: string;
  companions?: CompanionItem[];
  history?: Array<{ id: string; fromStatus: string | null; toStatus: string; changedBy: string | null; changeReason: string; occurredAt: string }>;
  credential?: { shortCode: string; usageStatus: string; usedAt: string | null } | null;
  messages?: Array<{ id: string; title: string; content: string; createdAt: string; isSecurity: boolean }>;
  shortCode?: string | null;
  lastGateId?: string | null;
  lastGateName?: string | null;
  lastRecordType?: string | null;
  lastPassageAt?: string | null;
  onCampusMinutes?: number | null;
};

export type IncidentItem = {
  id: string;
  appointmentId: string | null;
  incidentType: string;
  status: string;
  description: string;
  reportedBy: string;
  handledBy: string | null;
  dispositionNote: string | null;
  handledAt: string | null;
  createdAt: string;
};

export type VisitFormModel = {
  visitorName: string;
  visitorPhone: string;
  visitorIdNo: string;
  visitorTypeId: string | undefined;
  hostId: string | undefined;
  expectedGateId: string | undefined;
  visitStart: string | null;
  visitEnd: string | null;
  reason: string;
  plateNo: string;
  companions: CompanionItem[];
};
