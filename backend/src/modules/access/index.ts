import type { AuthenticatedUser } from '../../shared/auth/types.js';
import {
  getFirstAdminUser,
  getUserById,
  getUserByHostId,
  type AccessUserDto,
} from './internal/auth.service.js';

export type CurrentUser = AuthenticatedUser;
export type AccessUser = AccessUserDto;
export { getFirstAdminUser, getUserByHostId, getUserById };
