import { describe, expect, it } from 'vitest';

import { maskIdNo } from '../utils/mask.js';

describe('maskIdNo', () => {
  it.each([
    ['320101198803034566', '3201**********4566'],
    ['32010119880', '3201***9880'],
    ['3201011988', '3201**1988'],
    ['320101198', '3201*1198'],
    ['32010119', '3******9'],
    ['32010', '3***0'],
  ])('masks %s correctly', (value, expected) => {
    expect(maskIdNo(value)).toBe(expected);
    expect(maskIdNo(value)).not.toBe(value);
  });

  it('masks short and null values without leaking input', () => {
    expect(maskIdNo(null)).toBe('');
    expect(maskIdNo(undefined)).toBe('');
    expect(maskIdNo('')).toBe('');
    expect(maskIdNo('1')).toBe('*');
    expect(maskIdNo('12')).toBe('**');
  });

  it('never returns the complete identifier for any tested length', () => {
    const value = 'A'.repeat(40);
    for (let length = 1; length <= value.length; length += 1) {
      const input = value.slice(0, length);
      expect(maskIdNo(input)).not.toBe(input);
    }
  });
});
