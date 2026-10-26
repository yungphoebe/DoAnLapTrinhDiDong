import phrases from './pose-audio/vi/phrases.json' with { type: 'json' };

function numberClips(value, padded = false) {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 0 || n > 999999) return null;
  if (n >= 1000) {
    const remainder = n % 1000;
    return [...numberClips(Math.floor(n / 1000)), 'number-thousand',
      ...(remainder ? numberClips(remainder, remainder < 100) : [])];
  }
  const result = [];
  if (n >= 100 || padded) result.push(`number-${Math.floor(n / 100)}`, 'number-hundred');
  const remainder = n % 100, tens = Math.floor(remainder / 10), units = remainder % 10;
  if (tens) result.push(`number-${tens * 10}`);
  else if (units && (n >= 100 || padded)) result.push('number-linh');
  if (units) result.push(units === 5 && tens ? 'number-lam'
    : units === 1 && tens > 1 ? 'number-mot' : `number-${units}`);
  if (!result.length) result.push('number-0');
  return result;
}

// Only known Vietnamese recordings may be played when a Vietnamese system voice is absent.
export function vietnameseClips(text) {
  const count = text.match(/^(\d+) lần\.$/);
  if (count) { const number = numberClips(count[1]); return number && [...number, 'times']; }
  const summary = text.match(/^Đã kết thúc phiên tập\. Bạn hoàn thành (\d+) lần, trong đó (\d+) lần đạt tư thế\.$/);
  if (summary) {
    const total = numberClips(summary[1]), correct = numberClips(summary[2]);
    return total && correct && ['finished', ...total, 'correct-prefix', ...correct, 'correct-suffix'];
  }
  if (text.startsWith('Không mở được camera:')) return ['camera-error'];
  const entries = Object.entries(phrases).filter(([key]) => !key.startsWith('number-'))
    .sort((a, b) => b[1].length - a[1].length);
  const result = [];
  let rest = text.trim();
  while (rest) {
    const entry = entries.find(([, phrase]) => rest.startsWith(phrase));
    if (!entry) return null;
    result.push(entry[0]);
    rest = rest.slice(entry[1].length).trim();
  }
  return result.length ? result : null;
}
