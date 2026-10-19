import { describe, expect, it } from 'vitest';

import { parsePagination } from '../http/pagination.js';

describe('parsePagination', () => {
  it('uses defaults for missing values', () => {
    expect(parsePagination({})).toEqual({ page: 1, pageSize: 20, offset: 0 });
  });

  it('silently truncates an oversized page size', () => {
    expect(parsePagination({ page: '2', page_size: '101' })).toEqual({
      page: 2,
      pageSize: 100,
      offset: 100,
    });
  });

  it('falls back for non-numeric, blank, and non-positive values', () => {
    expect(parsePagination({ page: 'abc', page_size: 'many' })).toEqual({
      page: 1,
      pageSize: 20,
      offset: 0,
    });
    expect(parsePagination({ page: '', page_size: '' })).toEqual({
      page: 1,
      pageSize: 20,
      offset: 0,
    });
    expect(parsePagination({ page: '0', page_size: '-5' })).toEqual({
      page: 1,
      pageSize: 20,
      offset: 0,
    });
  });

  it('honors custom defaults and maximums', () => {
    expect(parsePagination({}, 50, 75)).toEqual({ page: 1, pageSize: 50, offset: 0 });
    expect(parsePagination({ page: '3', page_size: '90' }, 50, 75)).toEqual({
      page: 3,
      pageSize: 75,
      offset: 150,
    });
  });
});
