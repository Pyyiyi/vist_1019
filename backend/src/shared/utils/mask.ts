function repeatedStars(length: number): string {
  return '*'.repeat(Math.max(0, length));
}

export function maskIdNo(value: string | null | undefined): string {
  if (value === null || value === undefined) {
    return '';
  }

  const characters = Array.from(String(value));
  const length = characters.length;

  if (length === 0) {
    return '';
  }
  if (length <= 2) {
    return repeatedStars(length);
  }
  if (length >= 9) {
    return (
      characters.slice(0, 4).join('') +
      repeatedStars(length - 8) +
      characters.slice(length - 4).join('')
    );
  }

  return (
    characters[0] +
    repeatedStars(Math.max(1, length - 2)) +
    characters[length - 1]
  );
}
