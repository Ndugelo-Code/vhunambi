/**
 * Sovereign & Supabase Free-Tier Password Strength Policy (`MIN_SOVEREIGN_PASSWORD_LENGTH = 8`).
 *
 * Aligns local/edge registration (`vhunambi_db.ts` and `edge_persistence_bridge.ts`)
 * with Supabase Auth Email provider requirements (8+ chars, lowercase, uppercase,
 * digit, and symbol) plus a deterministic common-breached password guard.
 */

export const MIN_SOVEREIGN_PASSWORD_LENGTH = 8;

const COMMON_BREACHED_BASES = new Set<string>([
  'password',
  'passw0rd',
  'p@ssword',
  'p@ssw0rd',
  '12345678',
  '123456789',
  '1234567890',
  'qwerty',
  'qwertyui',
  'qwerty123',
  'admin',
  'administrator',
  'letmein',
  'welcome',
  'iloveyou',
  'monkey',
  'dragon',
  'master',
  'sunshine',
  'trustno1',
]);

export interface SovereignPasswordEvaluation {
  readonly isValid: boolean;
  readonly hasMinLength: boolean;
  readonly hasNoEdgeWhitespace: boolean;
  readonly hasLowercase: boolean;
  readonly hasUppercase: boolean;
  readonly hasDigit: boolean;
  readonly hasSymbol: boolean;
  readonly notCommonWeak: boolean;
  readonly failureMessage: string | null;
}

export function evaluateSovereignPassword(
  password: string | undefined | null,
): SovereignPasswordEvaluation {
  const raw = typeof password === 'string' ? password : '';
  const hasMinLength = raw.length >= MIN_SOVEREIGN_PASSWORD_LENGTH;
  const hasNoEdgeWhitespace =
    raw.length > 0 && raw.trim().length === raw.length;
  const hasLowercase = /[a-z]/.test(raw);
  const hasUppercase = /[A-Z]/.test(raw);
  const hasDigit = /[0-9]/.test(raw);
  const hasSymbol = /[^A-Za-z0-9\s]/.test(raw);

  const normalizedLower = raw.toLowerCase();
  const strippedBase = normalizedLower.replace(
    /[0-9!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?~`]+$/g,
    '',
  );
  const isSequentialPrefix = /^(?:123456|abcdef|qwerty)/i.test(raw);
  const notCommonWeak =
    raw.length > 0 &&
    !COMMON_BREACHED_BASES.has(normalizedLower) &&
    !COMMON_BREACHED_BASES.has(strippedBase) &&
    !isSequentialPrefix;

  let failureMessage: string | null = null;
  if (!hasMinLength) {
    failureMessage = `WEAK_PASSWORD: Password must be at least ${MIN_SOVEREIGN_PASSWORD_LENGTH} characters long.`;
  } else if (!hasNoEdgeWhitespace) {
    failureMessage =
      'WEAK_PASSWORD: Password cannot start or end with whitespace.';
  } else if (!hasLowercase || !hasUppercase || !hasDigit || !hasSymbol) {
    failureMessage =
      'WEAK_PASSWORD: Password must include uppercase, lowercase, a digit, and a symbol (e.g. !@#$%).';
  } else if (!notCommonWeak) {
    failureMessage =
      'WEAK_PASSWORD: Password is too common or easily guessed. Choose a unique passphrase.';
  }

  return {
    isValid: failureMessage === null,
    hasMinLength,
    hasNoEdgeWhitespace,
    hasLowercase,
    hasUppercase,
    hasDigit,
    hasSymbol,
    notCommonWeak,
    failureMessage,
  };
}

export function validateSovereignPassword(
  password: string | undefined | null,
): void {
  const evaluation = evaluateSovereignPassword(password);
  if (!evaluation.isValid && evaluation.failureMessage) {
    throw new Error(evaluation.failureMessage);
  }
}
