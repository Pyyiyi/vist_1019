import axios, {
  type AxiosError,
  type AxiosInstance,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE ?? '/api/v1';
const CSRF_COOKIE = 'vs.csrf';
const CSRF_HEADER = 'X-CSRF-Token';

let cachedCsrfToken = '';

type JsonRecord = Record<string, unknown>;

function isPlainObject(value: unknown): value is JsonRecord {
  if (value === null || typeof value !== 'object') {
    return false;
  }

  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function isBinaryBody(value: unknown): boolean {
  if (typeof FormData !== 'undefined' && value instanceof FormData) {
    return true;
  }
  if (typeof Blob !== 'undefined' && value instanceof Blob) {
    return true;
  }
  if (typeof File !== 'undefined' && value instanceof File) {
    return true;
  }
  if (value instanceof Date) {
    return true;
  }
  return (
    typeof URLSearchParams !== 'undefined' && value instanceof URLSearchParams
  );
}

export function camelToSnakeKey(key: string): string {
  return key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
}

export function snakeToCamelKey(key: string): string {
  return key.replace(/_([a-z0-9])/g, (_, letter: string) => letter.toUpperCase());
}

export function mapObjectKeys<T>(value: T, mapper: (key: string) => string): T {
  if (Array.isArray(value)) {
    return value.map((item) => mapObjectKeys(item, mapper)) as T;
  }

  if (!isPlainObject(value)) {
    return value;
  }

  return Object.fromEntries(
    Object.entries(value).map(([key, entry]) => [
      mapper(key),
      mapObjectKeys(entry, mapper),
    ]),
  ) as T;
}

export function toSnakeCase<T>(value: T): T {
  return mapObjectKeys(value, camelToSnakeKey);
}

export function toCamelCase<T>(value: T): T {
  return mapObjectKeys(value, snakeToCamelKey);
}

function setHeader(
  headers: InternalAxiosRequestConfig['headers'],
  name: string,
  value: string,
): void {
  if (typeof headers.set === 'function') {
    headers.set(name, value);
    return;
  }
  (headers as unknown as Record<string, string>)[name] = value;
}

function readCsrfCookie(): string {
  if (typeof document === 'undefined') {
    return '';
  }

  const prefix = `${CSRF_COOKIE}=`;
  const cookie = document.cookie
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(prefix));

  return cookie ? decodeURIComponent(cookie.slice(prefix.length)) : '';
}

export function resetCsrfToken(): void {
  cachedCsrfToken = '';
}

export async function getCsrfToken(force = false): Promise<string> {
  if (force) {
    cachedCsrfToken = '';
  }

  const cookieToken = readCsrfCookie();
  if (cookieToken) {
    cachedCsrfToken = cookieToken;
    return cookieToken;
  }

  if (cachedCsrfToken) {
    return cachedCsrfToken;
  }

  const response = await axios.get(`${API_BASE}/auth/csrf`, {
    withCredentials: true,
  });
  const token =
    response.data?.data?.csrf_token ?? response.data?.data?.csrfToken ?? '';

  if (typeof token === 'string') {
    cachedCsrfToken = token;
  }
  return cachedCsrfToken;
}

function requiresCsrf(method?: string): boolean {
  return !['get', 'head', 'options'].includes((method ?? 'get').toLowerCase());
}

export const requestInterceptor = async (
  config: InternalAxiosRequestConfig,
): Promise<InternalAxiosRequestConfig> => {
  if (config.data !== undefined && !isBinaryBody(config.data)) {
    config.data = toSnakeCase(config.data);
  }
  if (config.params !== undefined && !isBinaryBody(config.params)) {
    config.params = toSnakeCase(config.params);
  }

  if (requiresCsrf(config.method)) {
    const token = await getCsrfToken();
    if (token) {
      setHeader(config.headers, CSRF_HEADER, token);
    }
  }

  return config;
};

export const responseInterceptor = (response: AxiosResponse): AxiosResponse => {
  if (isPlainObject(response.data) && 'data' in response.data) {
    response.data.data = toCamelCase(response.data.data);
  }
  return response;
};

export async function handleUnauthorized(): Promise<void> {
  try {
    const { useAuthStore } = await import('@/stores/auth');
    useAuthStore().clearSession();
  } catch {
    // The store may not be active yet during application startup.
  }

  if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
    window.location.assign('/login');
  }
}

export const responseErrorInterceptor = async (error: AxiosError) => {
  if (error.response?.status === 401) {
    await handleUnauthorized();
  }
  return Promise.reject(error);
};

const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE,
  withCredentials: true,
});

apiClient.interceptors.request.use(requestInterceptor);
apiClient.interceptors.response.use(responseInterceptor, responseErrorInterceptor);

export default apiClient;
