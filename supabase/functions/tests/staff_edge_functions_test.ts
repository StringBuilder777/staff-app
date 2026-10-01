import {
  createInitialMockDatabaseState,
  createMockSupabaseClient,
} from './mock_supabase.ts';
import { handleStaffTeamFromQr } from '../staff-team-from-qr/index.ts';
import { handleStaffIssueNfc } from '../staff-issue-nfc/index.ts';
import { handleStaffScanNfc } from '../staff-scan-nfc/index.ts';
import { handleStaffSitecScanNfc } from '../staff-sitec-scan-nfc/index.ts';
import { VALID_SITEC_ACCESS_TYPES } from '../_shared/types.ts';
import type {
  TeamFromQrResponse,
  IssueNfcResponse,
  ScanNfcAcceptedResponse,
  ScanNfcDuplicateResponse,
  SitecScanNfcAcceptedResponse,
  SitecScanNfcDuplicateResponse,
  ApiErrorResponse,
} from '../_shared/types.ts';

// Simple assertion helpers
function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`Assertion failed [${message}]: Expected ${String(expected)}, got ${String(actual)}`);
  }
}

async function runTests(): Promise<void> {
  console.log('🧪 Iniciando suite de pruebas automatizadas para Staff Edge Functions...\n');
  let passedCount = 0;

  async function test(name: string, fn: () => Promise<void>): Promise<void> {
    try {
      await fn();
      console.log(`  ✅ PASSED: ${name}`);
      passedCount++;
    } catch (err) {
      console.error(`  ❌ FAILED: ${name}`);
      console.error(`     ${err instanceof Error ? err.message : String(err)}`);
      throw err;
    }
  }

  // =========================================================================
  // 1. Pruebas para: staff-team-from-qr
  // =========================================================================
  console.log('--- Suite 1: staff-team-from-qr ---');

  await test('Éxito: Staff consulta equipo e integrantes con QR válido', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-team-from-qr', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({ qrToken: 'valid-qr-token-123' }),
    });

    const res = await handleStaffTeamFromQr(req, client);
    assertEqual(res.status, 200, 'HTTP Status 200');

    const data = (await res.json()) as TeamFromQrResponse;
    assertEqual(data.equipo.nombre, 'Equipo Boreal', 'Equipo nombre');
    assertEqual(data.integrantes.length, 2, 'Total integrantes');
    assertEqual(data.integrantes[0].nombre, 'Ana', 'Primer integrante nombre');
  });

  await test('Privacidad: No expone alergias, teléfonos, correos ni contactos de emergencia', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-team-from-qr', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({ qrToken: 'valid-qr-token-123' }),
    });

    const res = await handleStaffTeamFromQr(req, client);
    const data = (await res.json()) as Record<string, unknown>;
    const jsonStr = JSON.stringify(data);

    assert(!jsonStr.includes('Penicilina'), 'No debe contener alergias');
    assert(!jsonStr.includes('+528112345678'), 'No debe contener teléfonos');
    assert(!jsonStr.includes('ana.torres@example.com'), 'No debe contener emails');
    assert(!jsonStr.includes('Laura Torres'), 'No debe contener contactos de emergencia');
  });

  await test('Error de autenticación: Falta cabecera Authorization (401)', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-team-from-qr', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ qrToken: 'valid-qr-token-123' }),
    });

    const res = await handleStaffTeamFromQr(req, client);
    assertEqual(res.status, 401, 'HTTP Status 401');
  });

  await test('Error de autenticación: Token JWT inválido (401)', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-team-from-qr', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer invalid-token-xyz',
      },
      body: JSON.stringify({ qrToken: 'valid-qr-token-123' }),
    });

    const res = await handleStaffTeamFromQr(req, client);
    assertEqual(res.status, 401, 'HTTP Status 401');
  });

  await test('Error de rol: Usuario con rol participante es denegado (403)', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-team-from-qr', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-part-valid',
      },
      body: JSON.stringify({ qrToken: 'valid-qr-token-123' }),
    });

    const res = await handleStaffTeamFromQr(req, client);
    assertEqual(res.status, 403, 'HTTP Status 403 Forbidden');
  });

  await test('No encontrado: QR inexistente devuelve 404', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-team-from-qr', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({ qrToken: 'non-existent-qr' }),
    });

    const res = await handleStaffTeamFromQr(req, client);
    assertEqual(res.status, 404, 'HTTP Status 404 Not Found');
  });

  await test('Validación de payload: qrToken vacío devuelve 400', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-team-from-qr', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({ qrToken: '' }),
    });

    const res = await handleStaffTeamFromQr(req, client);
    assertEqual(res.status, 400, 'HTTP Status 400 Bad Request');
  });

  // =========================================================================
  // 2. Pruebas para: staff-issue-nfc
  // =========================================================================
  console.log('\n--- Suite 2: staff-issue-nfc ---');

  await test('Éxito: Emisión de tarjeta NFC para integrante existente', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-issue-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({ integranteId: 'int-uuid-1' }),
    });

    const res = await handleStaffIssueNfc(req, client);
    assertEqual(res.status, 200, 'HTTP Status 200');

    const data = (await res.json()) as IssueNfcResponse;
    assertEqual(data.integranteId, 'int-uuid-1', 'Integrante ID');
    assertEqual(data.nfcToken, 'valid-nfc-token-123', 'Token NFC asignado');
    assertEqual(data.payload, 'staffapp:nfc:valid-nfc-token-123', 'Payload exacto');

    // Verificar en la base de datos simulada
    const dbIntegrante = dbState.integrantes.find((i) => i.id === 'int-uuid-1');
    assert(Boolean(dbIntegrante?.nfc_activa), 'nfc_activa debe ser true');
    assert(Boolean(dbIntegrante?.nfc_emitida_en), 'nfc_emitida_en debe tener fecha');
  });

  await test('Formato del payload: No incluye ningún dato personal en tarjeta NFC', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-issue-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-admin-valid',
      },
      body: JSON.stringify({ integranteId: 'int-uuid-1' }),
    });

    const res = await handleStaffIssueNfc(req, client);
    const data = (await res.json()) as IssueNfcResponse;

    assert(data.payload.startsWith('staffapp:nfc:'), 'Prefijo exacto');
    assert(!data.payload.includes('Ana'), 'No debe contener nombres');
    assert(!data.payload.includes('Torres'), 'No debe contener apellidos');
    assert(!data.payload.includes('equipo'), 'No debe contener info de equipo');
  });

  await test('No encontrado: integranteId inexistente devuelve 404', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-issue-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({ integranteId: 'non-existent-int' }),
    });

    const res = await handleStaffIssueNfc(req, client);
    assertEqual(res.status, 404, 'HTTP Status 404');
  });

  // =========================================================================
  // 3. Pruebas para: staff-scan-nfc
  // =========================================================================
  console.log('\n--- Suite 3: staff-scan-nfc ---');

  await test('Éxito: Primer escaneo de check-in acepta acceso (200 accepted)', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'checkin',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 200, 'HTTP Status 200');

    const data = (await res.json()) as ScanNfcAcceptedResponse;
    assertEqual(data.status, 'accepted', 'Status accepted');
    assertEqual(data.accessType, 'checkin', 'accessType checkin');
    assert(Boolean(data.registeredAt), 'registeredAt presente');
    assertEqual(data.participante.id, 'int-uuid-1', 'Participante ID');
    assertEqual(data.equipo?.nombre, 'Equipo Boreal', 'Equipo nombre');

    // Verificar actualización en base de datos
    const dbInt = dbState.integrantes.find((i) => i.id === 'int-uuid-1');
    assert(Boolean(dbInt?.checkin_en), 'checkin_en actualizado');
    assertEqual(dbInt?.checkin_registrado_por, 'staff-uuid-1', 'checkin_registrado_por staff');
    assert(Boolean(dbInt?.nfc_ultimo_leido_en), 'nfc_ultimo_leido_en actualizado');
  });

  await test('Compatibilidad de formato: Acepta token con prefijo staffapp:nfc:<token>', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'staffapp:nfc:valid-nfc-token-123',
        accessType: 'comida',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 200, 'HTTP Status 200');

    const data = (await res.json()) as ScanNfcAcceptedResponse;
    assertEqual(data.status, 'accepted', 'Status accepted');
    assertEqual(data.accessType, 'comida', 'accessType comida');
  });

  await test('Acceso duplicado: Segundo escaneo para el mismo evento devuelve 409 Conflict', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    // Primer escaneo exitoso
    const req1 = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'checkin',
      }),
    });
    const res1 = await handleStaffScanNfc(req1, client);
    assertEqual(res1.status, 200, 'Primer escaneo 200');
    const data1 = (await res1.json()) as ScanNfcAcceptedResponse;

    // Segundo escaneo (intento duplicado)
    const req2 = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'checkin',
      }),
    });
    const res2 = await handleStaffScanNfc(req2, client);
    assertEqual(res2.status, 409, 'HTTP Status 409 Conflict en duplicado');

    const data2 = (await res2.json()) as ScanNfcDuplicateResponse;
    assertEqual(data2.status, 'duplicate', 'Status duplicate');
    assertEqual(data2.previouslyRegisteredAt, data1.registeredAt, 'Momento previo exacto');
    assertEqual(data2.participante.id, 'int-uuid-1', 'Participante ID en duplicado');
    assertEqual(data2.equipo?.nombre, 'Equipo Boreal', 'Equipo en duplicado');
  });

  await test('Privacidad en 409: La respuesta de duplicado nunca expone datos sensibles', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    // Simular que checkin ya estaba hecho
    dbState.integrantes[0].checkin_en = '2026-09-14T08:30:00.000Z';

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'checkin',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 409, 'HTTP Status 409');

    const rawJson = await res.text();
    assert(!rawJson.includes('Penicilina'), 'Sin alergias');
    assert(!rawJson.includes('+528112345678'), 'Sin teléfono');
    assert(!rawJson.includes('ana.torres@example.com'), 'Sin email');
    assert(!rawJson.includes('Laura Torres'), 'Sin contacto de emergencia');
  });

  await test('NFC inactiva: Tarjeta con nfc_activa=false devuelve 404', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'inactive-nfc-token-456',
        accessType: 'checkin',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 404, 'HTTP Status 404 Not Found');
  });

  await test('Token inválido: accessType no soportado devuelve 400', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'cena_invalida',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 400, 'HTTP Status 400 Bad Request');

    const data = (await res.json()) as ApiErrorResponse;
    assert(data.error.includes('accessType'), 'Mensaje descriptivo de accessType');
  });

  await test('Éxito: Validación para desayuno y comida por rol admin', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    // Desayuno
    const reqDesayuno = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-admin-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'desayuno',
      }),
    });
    const resDesayuno = await handleStaffScanNfc(reqDesayuno, client);
    assertEqual(resDesayuno.status, 200, 'Desayuno Status 200');

    // Comida
    const reqComida = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-admin-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'comida',
      }),
    });
    const resComida = await handleStaffScanNfc(reqComida, client);
    assertEqual(resComida.status, 200, 'Comida Status 200');

    // Duplicado en comida con una nueva Request
    const reqComidaDup = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-admin-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'comida',
      }),
    });
    const resComidaDup = await handleStaffScanNfc(reqComidaDup, client);
    assertEqual(resComidaDup.status, 409, 'Comida Duplicado Status 409');
  });

  await test('No encontrado: Token NFC no registrado devuelve 404', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'completely-unknown-token',
        accessType: 'checkin',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 404, 'HTTP Status 404 Not Found');
  });

  await test('Rol no autorizado: Usuario no registrado en perfiles devuelve 403', async () => {
    const dbState = createInitialMockDatabaseState();
    // Remover perfiles
    dbState.perfiles = [];
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'checkin',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 403, 'HTTP Status 403 Forbidden');
  });

  await test('Función sin permiso: Mentor no valida accesos y devuelve 403', async () => {
    const dbState = createInitialMockDatabaseState();
    // Carlos Staff pasa de Registro a Mentor, que no opera los filtros.
    dbState.staff[0].rol = 'Mentor';
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'checkin',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 403, 'HTTP Status 403 Forbidden');

    const integrante = dbState.integrantes.find((i) => i.id === 'int-uuid-1');
    assertEqual(integrante?.checkin_en, null, 'No registró el acceso');
  });

  await test('Sin alta en staff: devuelve 403 y no se da de alta solo', async () => {
    const dbState = createInitialMockDatabaseState();
    dbState.staff = [];
    const client = createMockSupabaseClient(dbState);

    const req = new Request('http://localhost/functions/v1/staff-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({
        nfcToken: 'valid-nfc-token-123',
        accessType: 'checkin',
      }),
    });

    const res = await handleStaffScanNfc(req, client);
    assertEqual(res.status, 403, 'HTTP Status 403 Forbidden');
    // El alta automática se retiró a propósito: la función operativa no se
    // puede deducir desde perfiles.rol.
    assertEqual(dbState.staff.length, 0, 'No hubo alta automática en staff');
  });

  // =========================================================================
  // 4. Pruebas para: staff-sitec-scan-nfc
  // =========================================================================
  console.log('\n--- Suite 4: staff-sitec-scan-nfc ---');

  const SITEC_TOKEN = '6f1c2a9e-4b7d-4e2a-9c3f-1a2b3c4d5e6f';
  const SITEC_TOKEN_INACTIVO = '0d9e8f7a-6b5c-4d3e-8f2a-9b8c7d6e5f4a';

  function sitecScanRequest(nfcToken: string, accessType: string): Request {
    return new Request('http://localhost/functions/v1/staff-sitec-scan-nfc', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer jwt-staff-valid',
      },
      body: JSON.stringify({ nfcToken, accessType }),
    });
  }

  await test('Éxito: Primer escaneo de la entrada del jueves registra el acceso (200)', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const res = await handleStaffSitecScanNfc(
      sitecScanRequest(SITEC_TOKEN, 'jueves_entrada'),
      client
    );
    assertEqual(res.status, 200, 'HTTP Status 200');

    const data = (await res.json()) as SitecScanNfcAcceptedResponse;
    assertEqual(data.status, 'accepted', 'Status accepted');
    assertEqual(data.accessType, 'jueves_entrada', 'accessType jueves_entrada');
    assertEqual(data.asistente.id, 'sitec-asis-1', 'Asistente ID');
    assertEqual(data.asistente.nombre, 'Marta', 'Asistente nombre');
    assertEqual(data.asistente.jueves_entrada_en, data.registeredAt, 'Hora en el asistente');

    const asistente = dbState.sitec_asistentes.find((a) => a.id === 'sitec-asis-1');
    assertEqual(asistente?.jueves_entrada_en, data.registeredAt, 'jueves_entrada_en guardado');
    assertEqual(
      asistente?.jueves_entrada_registrado_por,
      'staff-uuid-1',
      'jueves_entrada_registrado_por staff'
    );
    assert(Boolean(asistente?.nfc_ultimo_leido_en), 'nfc_ultimo_leido_en actualizado');
  });

  await test('Acceso duplicado: Segundo escaneo en el mismo punto devuelve 409 con la hora original', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const res1 = await handleStaffSitecScanNfc(
      sitecScanRequest(SITEC_TOKEN, 'jueves_comida'),
      client
    );
    assertEqual(res1.status, 200, 'Primer escaneo 200');
    const data1 = (await res1.json()) as SitecScanNfcAcceptedResponse;

    const res2 = await handleStaffSitecScanNfc(
      sitecScanRequest(SITEC_TOKEN, 'jueves_comida'),
      client
    );
    assertEqual(res2.status, 409, 'HTTP Status 409 Conflict en duplicado');

    const data2 = (await res2.json()) as SitecScanNfcDuplicateResponse;
    assertEqual(data2.status, 'duplicate', 'Status duplicate');
    assertEqual(data2.previouslyRegisteredAt, data1.registeredAt, 'Momento previo exacto');
    assertEqual(data2.asistente.id, 'sitec-asis-1', 'Asistente en duplicado');
  });

  await test('Puntos independientes: Cada punto de cada día se registra en su propia columna', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    // Pasar por un punto no consume otro: la comida del jueves no gasta la del
    // viernes, ni la entrada gasta la salida.
    for (const accessType of VALID_SITEC_ACCESS_TYPES) {
      const res = await handleStaffSitecScanNfc(sitecScanRequest(SITEC_TOKEN, accessType), client);
      assertEqual(res.status, 200, `${accessType} aceptado`);
    }

    const asistente = dbState.sitec_asistentes.find((a) => a.id === 'sitec-asis-1');
    for (const accessType of VALID_SITEC_ACCESS_TYPES) {
      assert(Boolean(asistente?.[`${accessType}_en`]), `${accessType}_en registrado`);
      assertEqual(
        asistente?.[`${accessType}_registrado_por`],
        'staff-uuid-1',
        `${accessType}_registrado_por staff`
      );
    }
  });

  await test('Compatibilidad de formato: Acepta token con prefijo staffapp:nfc:<token>', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const res = await handleStaffSitecScanNfc(
      sitecScanRequest(`staffapp:nfc:${SITEC_TOKEN}`, 'viernes_entrada'),
      client
    );
    assertEqual(res.status, 200, 'HTTP Status 200');
  });

  await test('Privacidad: La respuesta nunca expone correo, teléfono ni el token NFC', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const res = await handleStaffSitecScanNfc(
      sitecScanRequest(SITEC_TOKEN, 'viernes_comida'),
      client
    );
    assertEqual(res.status, 200, 'HTTP Status 200');

    const raw = await res.text();
    assert(!raw.includes('marta.ruiz@example.com'), 'No expone el correo');
    assert(!raw.includes('+528111111111'), 'No expone el teléfono');
    assert(!raw.includes(SITEC_TOKEN), 'No expone el token NFC');
  });

  await test('Tarjeta inactiva: Devuelve 404 y no registra el acceso', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    const res = await handleStaffSitecScanNfc(
      sitecScanRequest(SITEC_TOKEN_INACTIVO, 'jueves_entrada'),
      client
    );
    assertEqual(res.status, 404, 'HTTP Status 404');

    const asistente = dbState.sitec_asistentes.find((a) => a.id === 'sitec-asis-2');
    assertEqual(asistente?.jueves_entrada_en, null, 'No registró el acceso');
  });

  await test('Tablas separadas: Una tarjeta del hackathon no vale en SITEC (404)', async () => {
    const dbState = createInitialMockDatabaseState();
    // Token con forma de UUID, como los que emite staff-issue-nfc en producción.
    const tokenHackathon = 'c3d4e5f6-a7b8-4c9d-8e0f-112233445566';
    dbState.integrantes[0].nfc_token = tokenHackathon;
    const client = createMockSupabaseClient(dbState);

    const res = await handleStaffSitecScanNfc(
      sitecScanRequest(tokenHackathon, 'jueves_entrada'),
      client
    );
    assertEqual(res.status, 404, 'HTTP Status 404');
    assertEqual(dbState.integrantes[0].nfc_ultimo_leido_en, null, 'No tocó integrantes');
  });

  await test('Token sin formato UUID: Devuelve 404 sin llegar a consultar la tabla', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    // El mock no reproduce el error de Postgres ante un uuid mal formado, así
    // que se comprueba que la función corta antes de consultar sitec_asistentes.
    const tablasConsultadas: string[] = [];
    const from = client.from.bind(client);
    client.from = ((table: string) => {
      tablasConsultadas.push(table);
      return from(table);
    }) as typeof client.from;

    const res = await handleStaffSitecScanNfc(
      sitecScanRequest('valid-nfc-token-123', 'jueves_entrada'),
      client
    );
    assertEqual(res.status, 404, 'HTTP Status 404');
    assert(!tablasConsultadas.includes('sitec_asistentes'), 'No consultó sitec_asistentes');
  });

  await test('accessType inválido: Un acceso del hackathon o un día inexistente devuelve 400', async () => {
    const dbState = createInitialMockDatabaseState();
    const client = createMockSupabaseClient(dbState);

    for (const accessType of ['comida', 'sabado_entrada', '']) {
      const res = await handleStaffSitecScanNfc(sitecScanRequest(SITEC_TOKEN, accessType), client);
      assertEqual(res.status, 400, `"${accessType}" rechazado con 400`);
    }
  });

  await test('Función sin permiso: Mentor no valida accesos de SITEC (403)', async () => {
    const dbState = createInitialMockDatabaseState();
    dbState.staff[0].rol = 'Mentor';
    const client = createMockSupabaseClient(dbState);

    const res = await handleStaffSitecScanNfc(
      sitecScanRequest(SITEC_TOKEN, 'jueves_entrada'),
      client
    );
    assertEqual(res.status, 403, 'HTTP Status 403 Forbidden');

    const asistente = dbState.sitec_asistentes.find((a) => a.id === 'sitec-asis-1');
    assertEqual(asistente?.jueves_entrada_en, null, 'No registró el acceso');
  });

  console.log(`\n🎉 Todas las ${passedCount} pruebas se ejecutaron exitosamente.`);
}

runTests().catch((err: unknown) => {
  console.error('Error fatal durante la ejecución de las pruebas:', err);
  const globalObj = globalThis as { process?: { exit(code: number): void } };
  if (globalObj.process && typeof globalObj.process.exit === 'function') {
    globalObj.process.exit(1);
  }
});
