import type { OperationalEquipo, OperationalIntegrante } from './types.ts';

/**
 * Sanitizes integrante data to return ONLY operational information.
 * Strict whitelist ensures sensitive fields like allergies, phone numbers,
 * emergency contacts, and emails are never exposed to the client.
 */
export function sanitizeIntegrante(row: Record<string, unknown>): OperationalIntegrante {
  return {
    id: typeof row.id === 'string' ? row.id : String(row.id ?? ''),
    nombre: typeof row.nombre === 'string' ? row.nombre : '',
    apellidos: typeof row.apellidos === 'string'
      ? row.apellidos
      : typeof row.apellido === 'string'
        ? row.apellido
        : null,
    equipo_id: typeof row.equipo_id === 'string' ? row.equipo_id : null,
    nfc_token: typeof row.nfc_token === 'string' ? row.nfc_token : null,
    nfc_activa: typeof row.nfc_activa === 'boolean' ? row.nfc_activa : false,
    nfc_emitida_en: typeof row.nfc_emitida_en === 'string' ? row.nfc_emitida_en : null,
    nfc_ultimo_leido_en: typeof row.nfc_ultimo_leido_en === 'string' ? row.nfc_ultimo_leido_en : null,
    checkin_en: typeof row.checkin_en === 'string' ? row.checkin_en : null,
    desayuno_en: typeof row.desayuno_en === 'string' ? row.desayuno_en : null,
    comida_en: typeof row.comida_en === 'string' ? row.comida_en : null,
  };
}

/**
 * Sanitizes equipo data to return ONLY operational information.
 */
export function sanitizeEquipo(row: Record<string, unknown>): OperationalEquipo {
  return {
    id: typeof row.id === 'string' ? row.id : String(row.id ?? ''),
    nombre: typeof row.nombre === 'string' ? row.nombre : '',
    qr_token: typeof row.qr_token === 'string' ? row.qr_token : null,
  };
}
