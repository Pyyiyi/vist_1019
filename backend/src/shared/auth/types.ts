export interface AuthenticatedUser {
  id: string;
  username: string;
  displayName: string;
  roleCode: string;
  hostId: string | null;
}

declare module 'express-session' {
  interface SessionData {
    userId?: string;
    user?: AuthenticatedUser;
  }
}

declare global {
  namespace Express {
    interface Request {
      currentUser?: AuthenticatedUser;
      visitorAppointmentId?: string;
      visitorToken?: string;
    }
  }
}

export {};
