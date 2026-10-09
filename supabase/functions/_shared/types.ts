/**
 * Strict TypeScript types for Staff Supabase Edge Functions.
 * TypeScript estricto, sin `any`.
 */

export type UserRole = 'staff' | 'admin' | string;

// Hackathon final: el viernes check-in y cena; el sábado desayuno, comida y
// check-out.
export type AccessType = 'checkin' | 'cena' | 'desayuno' | 'comida' | 'checkout';

export const VALID_ACCESS_TYPES: readonly AccessType[] = [
  'checkin',
  'cena',
  'desayuno',
  'comida',
  'checkout',
] as const;

export function isValidAccessType(value: unknown): value is AccessType {
  return typeof value === 'string' && (VALID_ACCESS_TYPES as readonly string[]).includes(value);
}

/**
 * Salida del hackathon. No es un punto de una sola vez como los demás, sino un
 * interruptor: la primera lectura abre una salida (la persona queda fuera) y
 * la siguiente la cierra con su regreso. Se guarda en hackathon_salidas.
 */
export const SALIDA_ACCESS_TYPE = 'salida';

export type SalidaAccessType = typeof SALIDA_ACCESS_TYPE;

/** Lo que acepta staff-scan-nfc: los puntos de una sola vez y la salida. */
export type ScanAccessType = AccessType | SalidaAccessType;

export const VALID_SCAN_ACCESS_TYPES: readonly ScanAccessType[] = [
  ...VALID_ACCESS_TYPES,
  SALIDA_ACCESS_TYPE,
];

export function isValidScanAccessType(value: unknown): value is ScanAccessType {
  return (
    typeof value === 'string' && (VALID_SCAN_ACCESS_TYPES as readonly string[]).includes(value)
  );
}

/** Qué hizo una lectura en la salida: abrir una salida o cerrarla al regresar. */
export type SalidaMovimiento = 'salida' | 'regreso';

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
  cena_en: string | null;
  desayuno_en: string | null;
  comida_en: string | null;
  checkout_en: string | null;
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
  accessType: ScanAccessType;
  /**
   * Solo en la salida: id único (uuid) de esta lectura, generado por la app.
   * Si la respuesta se pierde y la app reintenta con el mismo id, se devuelve
   * lo que ya se registró en vez de alternar otra vez.
   */
  lecturaId?: string;
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

export interface ScanNfcSalidaAcceptedResponse {
  status: 'accepted';
  accessType: SalidaAccessType;
  /** 'salida' si la lectura abrió una salida; 'regreso' si la cerró. */
  movimiento: SalidaMovimiento;
  registeredAt: string;
  /** Hora en que salió: la de la salida que se abrió o la que se acaba de cerrar. */
  salioEn: string;
  /** true si esta lectura ya se había registrado (un reintento): es el resultado original. */
  repetida?: boolean;
  participante: OperationalIntegrante;
  equipo: OperationalEquipo | null;
}

/**
 * Lectura que no cambia nada: la misma tarjeta se leyó hace unos segundos, o
 * otro teléfono registró el mismo movimiento a la vez. `movimiento` es el
 * último que quedó registrado, que es el que sigue valiendo.
 */
export interface ScanNfcSalidaDuplicateResponse {
  status: 'duplicate';
  error: string;
  accessType: SalidaAccessType;
  movimiento: SalidaMovimiento;
  previouslyRegisteredAt: string;
  participante: OperationalIntegrante;
  equipo: OperationalEquipo | null;
}

/**
 * Puntos de acceso de SITEC, `<día>_<punto>`. Cada uno es un par de columnas
 * en sitec_asistentes: `<punto>_en` y `<punto>_registrado_por`.
 *
 * El viernes la comida tiene inicio y fin: viernes_comida es el inicio (la
 * columna de siempre) y viernes_comida_fin, el fin.
 */
export type SitecAccessType =
  | 'jueves_entrada'
  | 'jueves_comida'
  | 'jueves_salida'
  | 'viernes_entrada'
  | 'viernes_salida'
  | 'viernes_comida'
  | 'viernes_comida_fin';

export const VALID_SITEC_ACCESS_TYPES: readonly SitecAccessType[] = [
  'jueves_entrada',
  'jueves_comida',
  'jueves_salida',
  'viernes_entrada',
  'viernes_salida',
  'viernes_comida',
  'viernes_comida_fin',
] as const;

export function isValidSitecAccessType(value: unknown): value is SitecAccessType {
  return (
    typeof value === 'string' && (VALID_SITEC_ACCESS_TYPES as readonly string[]).includes(value)
  );
}

export interface OperationalSitecAsistente {
  id: string;
  nombre: string;
  apellidos: string | null;
  /** Kit comprado: 'premium', 'basico' o 'general'. null si no está en ventas. */
  kit: string | null;
  jueves_entrada_en: string | null;
  jueves_comida_en: string | null;
  jueves_salida_en: string | null;
  viernes_entrada_en: string | null;
  viernes_salida_en: string | null;
  viernes_comida_en: string | null;
  viernes_comida_fin_en: string | null;
}

export interface SitecScanNfcRequest {
  nfcToken: string;
  accessType: SitecAccessType;
}

export interface SitecScanNfcAcceptedResponse {
  status: 'accepted';
  accessType: SitecAccessType;
  registeredAt: string;
  asistente: OperationalSitecAsistente;
}

export interface SitecScanNfcDuplicateResponse {
  status: 'duplicate';
  error: string;
  accessType: SitecAccessType;
  previouslyRegisteredAt: string;
  asistente: OperationalSitecAsistente;
}

/**
 * Asistente de SITEC tal como lo ve el registro: lo justo para encontrarlo por
 * nombre y saber si ya tiene la tarjeta escrita. Nunca lleva el token NFC.
 */
export interface SitecRegistroAsistente {
  id: string;
  nombre: string;
  apellidos: string | null;
  nfc_emitida_en: string | null;
}

export interface SitecAsistentesResponse {
  asistentes: SitecRegistroAsistente[];
}

export interface SitecIssueNfcRequest {
  asistenteId: string;
  /** true cuando la app confirma que ya escribió la tarjeta. */
  written?: boolean;
}

export interface SitecIssueNfcResponse {
  asistenteId: string;
  nfcToken: string;
  payload: string; // Exactly `staffapp:nfc:<nfcToken>`
}

export interface ApiErrorResponse {
  error: string;
  details?: unknown;
}
