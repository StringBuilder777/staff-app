/**
 * Strict TypeScript types for Staff Supabase Edge Functions.
 * TypeScript estricto, sin `any`.
 */

export type UserRole = 'staff' | 'admin' | string;

export type AccessType = 'checkin' | 'desayuno' | 'comida';

export const VALID_ACCESS_TYPES: readonly AccessType[] = ['checkin', 'desayuno', 'comida'] as const;

export function isValidAccessType(value: unknown): value is AccessType {
  return typeof value === 'string' && (VALID_ACCESS_TYPES as readonly string[]).includes(value);
}

export interface UserProfile {
  id: string;
  rol: UserRole;
  [key: string]: unknown;
}

export interface AuthValidationSuccess {
  authorized: true;
  userId: string;
  perfil: UserProfile;
}

export interface AuthValidationFailure {
  authorized: false;
  statusCode: 401 | 403;
  error: string;
}

export type AuthValidationResult = AuthValidationSuccess | AuthValidationFailure;

export interface OperationalEquipo {
  id: string;
  nombre: string;
  qr_token: string | null;
}

export interface OperationalIntegrante {
  id: string;
  nombre: string;
  apellidos: string | null;
  equipo_id: string | null;
  nfc_token: string | null;
  nfc_activa: boolean;
  nfc_emitida_en: string | null;
  nfc_ultimo_leido_en: string | null;
  checkin_en: string | null;
  desayuno_en: string | null;
  comida_en: string | null;
}

export interface TeamFromQrRequest {
  qrToken: string;
}

export interface TeamFromQrResponse {
  equipo: OperationalEquipo;
  integrantes: OperationalIntegrante[];
}

export interface IssueNfcRequest {
  integranteId: string;
}

export interface IssueNfcResponse {
  integranteId: string;
  nfcToken: string;
  payload: string; // Exactly `staffapp:nfc:<nfcToken>`
}

export interface ScanNfcRequest {
  nfcToken: string;
  accessType: AccessType;
}

export interface ScanNfcAcceptedResponse {
  status: 'accepted';
  accessType: AccessType;
  registeredAt: string;
  participante: OperationalIntegrante;
  equipo: OperationalEquipo | null;
}

export interface ScanNfcDuplicateResponse {
  status: 'duplicate';
  error: string;
  accessType: AccessType;
  previouslyRegisteredAt: string;
  participante: OperationalIntegrante;
  equipo: OperationalEquipo | null;
}

export interface ApiErrorResponse {
  error: string;
  details?: unknown;
}
