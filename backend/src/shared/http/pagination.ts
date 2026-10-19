export type Pagination = { page: number; pageSize: number; offset: number };

function positiveInteger(value: unknown, fallback: number): number {
  if (typeof value !== 'string' && typeof value !== 'number') {
    return fallback;
  }

  if (typeof value === 'string' && value.trim() === '') {
    return fallback;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    return fallback;
  }

  return parsed;
}

export function parsePagination(
  query: Record<string, unknown>,
  defaultPageSize = 20,
  maxPageSize = 100
): Pagination {
  const safeMaxPageSize = positiveInteger(maxPageSize, 100);
  const safeDefaultPageSize = Math.min(
    positiveInteger(defaultPageSize, 20),
    safeMaxPageSize
  );
  const page = positiveInteger(query.page, 1);
  const requestedPageSize = positiveInteger(query.page_size, safeDefaultPageSize);
  const pageSize = Math.min(requestedPageSize, safeMaxPageSize);

  return {
    page,
    pageSize,
    offset: (page - 1) * pageSize,
  };
}
