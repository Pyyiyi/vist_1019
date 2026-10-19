export type LedgerItem = {
  appointmentId: string;
  appointNo: string;
  visitorName: string | null;
  visitorType: string;
  visitorPhone: string | null;
  visitorIdNoMasked: string;
  hostName: string;
  visitStart: string;
  visitEnd: string;
  checkinAt: string | null;
  checkoutAt: string | null;
  status: string;
  reason: string;
};

export type VisitBucket = {
  period: string;
  type: string;
  count: number;
};

export type IncidentTypeCount = {
  type: string;
  count: number;
};
