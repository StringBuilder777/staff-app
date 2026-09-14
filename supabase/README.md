# Backend Staff - Supabase Edge Functions

Backend serverless para la aplicación de Staff (lectura de QR y tarjetas NFC), implementado con **Supabase Edge Functions** en **TypeScript estricto (sin `any`)**.

- **Proyecto Supabase Ref**: `uopfoekxkluotowilzaa`
- **Tablas involucradas**: `public.equipos`, `public.integrantes`, `public.staff`, `public.perfiles`

---

## Edge Functions Disponibles

| Función | Método | Endpoint | Descripción |
| :--- | :--- | :--- | :--- |
| **`staff-team-from-qr`** | `POST` | `/functions/v1/staff-team-from-qr` | Busca equipo por `qr_token` y devuelve sus integrantes con datos operativos. Nunca expone datos sensibles. |
| **`staff-issue-nfc`** | `POST` | `/functions/v1/staff-issue-nfc` | Asigna o reactiva el `nfc_token` de un integrante y genera el payload exacto `staffapp:nfc:<token>`. |
| **`staff-scan-nfc`** | `POST` | `/functions/v1/staff-scan-nfc` | Registra accesos de `checkin`, `desayuno` y `comida` atómicamente evitando duplicados (HTTP 409). |

---

## Seguridad y Privacidad de Datos

1. **Autenticación y Autorización**:
   - Requiere la cabecera `Authorization: Bearer <USER_JWT>`.
   - Valida el token con Supabase Auth.
   - Verifica que el usuario tenga rol `staff` o `admin` en la tabla `public.perfiles`.
2. **Protección de Credenciales**:
   - `SUPABASE_SERVICE_ROLE_KEY` permanece en el entorno seguro del Edge Runtime; **nunca** se envía ni expone al cliente móvil.
3. **Privacidad Estricta (Whitelisting)**:
   - Los datos personales sensibles (`alergias`, `telefono`, `email`, `contacto_emergencia`, `contacto_emergencia_telefono`, etc.) **nunca** son devueltos al cliente móvil ni escritos en la tarjeta NFC física.
4. **Prevención Atómica de Duplicados**:
   - `staff-scan-nfc` ejecuta una actualización condicional en PostgreSQL (`.is(timeCol, null)`) garantizando que solicitudes concurrentes no generen registros dobles. Si ya existe un registro previo, devuelve `HTTP 409 Conflict` con la fecha y hora original.

---

## Comandos de Supabase CLI

### 1. Servir Localmente

Para ejecutar y probar las Edge Functions en tu entorno local:

```bash
# Servir todas las Edge Functions localmente
npx supabase functions serve

# Servir cargando variables de entorno desde un archivo .env.local
npx supabase functions serve --env-file ./supabase/.env.local

# Servir una función específica (por ejemplo, sin requerir verificación de JWT para depuración)
npx supabase functions serve staff-team-from-qr --no-verify-jwt
```

Variables de entorno requeridas en `./supabase/.env.local`:
```env
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=tu_anon_key
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
```

### 2. Desplegar en Producción (Requiere confirmación previa)

> **Nota**: No despliegues a producción sin confirmación explícita del equipo.

```bash
# Desplegar las tres funciones al proyecto uopfoekxkluotowilzaa
npx supabase functions deploy staff-team-from-qr --project-ref uopfoekxkluotowilzaa
npx supabase functions deploy staff-issue-nfc --project-ref uopfoekxkluotowilzaa
npx supabase functions deploy staff-scan-nfc --project-ref uopfoekxkluotowilzaa

# O desplegar todas simultáneamente:
npx supabase functions deploy --project-ref uopfoekxkluotowilzaa
```

### 3. Configurar Secretos en el Proyecto Remoto

```bash
npx supabase secrets set --project-ref uopfoekxkluotowilzaa \
  MI_VARIABLE_PERSONALIZADA=valor
```

---

## Ejecutar Pruebas y Verificación de Tipos

El proyecto cuenta con verificación estricta de TypeScript y una suite automatizada de 19 pruebas de integración/unitarias:

```bash
# 1. Verificación de tipos estricta (sin 'any', TypeScript estricto)
npx -p typescript tsc --project supabase/functions/tsconfig.json

# 2. Ejecución de la suite completa de pruebas
npx -p tsx tsx --tsconfig supabase/functions/tsconfig.json supabase/functions/tests/staff_edge_functions_test.ts
```

---

## Casos de Prueba Documentados (cURL)

### Caso 1: `staff-team-from-qr` (Éxito)
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-team-from-qr" \
  -H "Authorization: Bearer <TOKEN_STAFF>" \
  -H "Content-Type: application/json" \
  -d '{"qrToken": "qr_equipo_boreal_123"}'
```
**Respuesta esperada (HTTP 200)**:
```json
{
  "equipo": {
    "id": "7b79a408-5dc6-490a-a0f1-4bbfebce6cf7",
    "nombre": "Equipo Boreal",
    "qr_token": "qr_equipo_boreal_123"
  },
  "integrantes": [
    {
      "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
      "nombre": "Ana",
      "apellidos": "Torres",
      "equipo_id": "7b79a408-5dc6-490a-a0f1-4bbfebce6cf7",
      "nfc_token": "98765432-abcd-ef01-2345-6789abcdef01",
      "nfc_activa": true,
      "nfc_emitida_en": "2026-09-14T10:00:00.000Z",
      "nfc_ultimo_leido_en": null,
      "checkin_en": null,
      "desayuno_en": null,
      "comida_en": null
    }
  ]
}
```

### Caso 2: `staff-issue-nfc` (Éxito)
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-issue-nfc" \
  -H "Authorization: Bearer <TOKEN_STAFF>" \
  -H "Content-Type: application/json" \
  -d '{"integranteId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"}'
```
**Respuesta esperada (HTTP 200)**:
```json
{
  "integranteId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
  "nfcToken": "98765432-abcd-ef01-2345-6789abcdef01",
  "payload": "staffapp:nfc:98765432-abcd-ef01-2345-6789abcdef01"
}
```

### Caso 3: `staff-scan-nfc` (Éxito - Primer Escaneo)
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-scan-nfc" \
  -H "Authorization: Bearer <TOKEN_STAFF>" \
  -H "Content-Type: application/json" \
  -d '{
    "nfcToken": "98765432-abcd-ef01-2345-6789abcdef01",
    "accessType": "checkin"
  }'
```
**Respuesta esperada (HTTP 200)**:
```json
{
  "status": "accepted",
  "accessType": "checkin",
  "registeredAt": "2026-09-14T14:30:00.000Z",
  "participante": {
    "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "nombre": "Ana",
    "apellidos": "Torres",
    "equipo_id": "7b79a408-5dc6-490a-a0f1-4bbfebce6cf7",
    "nfc_token": "98765432-abcd-ef01-2345-6789abcdef01",
    "nfc_activa": true,
    "nfc_emitida_en": "2026-09-14T10:00:00.000Z",
    "nfc_ultimo_leido_en": "2026-09-14T14:30:00.000Z",
    "checkin_en": "2026-09-14T14:30:00.000Z",
    "desayuno_en": null,
    "comida_en": null
  },
  "equipo": {
    "id": "7b79a408-5dc6-490a-a0f1-4bbfebce6cf7",
    "nombre": "Equipo Boreal",
    "qr_token": "qr_equipo_boreal_123"
  }
}
```

### Caso 4: `staff-scan-nfc` (Acceso Duplicado)
Al escanear nuevamente la misma tarjeta para `checkin`:
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-scan-nfc" \
  -H "Authorization: Bearer <TOKEN_STAFF>" \
  -H "Content-Type: application/json" \
  -d '{
    "nfcToken": "98765432-abcd-ef01-2345-6789abcdef01",
    "accessType": "checkin"
  }'
```
**Respuesta esperada (HTTP 409 Conflict)**:
```json
{
  "status": "duplicate",
  "error": "El acceso de checkin ya había sido registrado para este participante",
  "accessType": "checkin",
  "previouslyRegisteredAt": "2026-09-14T14:30:00.000Z",
  "participante": {
    "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "nombre": "Ana",
    "apellidos": "Torres",
    "equipo_id": "7b79a408-5dc6-490a-a0f1-4bbfebce6cf7",
    "nfc_token": "98765432-abcd-ef01-2345-6789abcdef01",
    "nfc_activa": true,
    "nfc_emitida_en": "2026-09-14T10:00:00.000Z",
    "nfc_ultimo_leido_en": "2026-09-14T14:35:10.000Z",
    "checkin_en": "2026-09-14T14:30:00.000Z",
    "desayuno_en": null,
    "comida_en": null
  },
  "equipo": {
    "id": "7b79a408-5dc6-490a-a0f1-4bbfebce6cf7",
    "nombre": "Equipo Boreal",
    "qr_token": "qr_equipo_boreal_123"
  }
}
```

### Caso 5: Token Inválido o Ausente (HTTP 401)
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-scan-nfc" \
  -H "Content-Type: application/json" \
  -d '{"nfcToken": "token-123", "accessType": "checkin"}'
```
**Respuesta esperada (HTTP 401)**:
```json
{
  "error": "Cabecera Authorization no proporcionada"
}
```

### Caso 6: Rol No Autorizado (HTTP 403)
Cuando un usuario autenticado con rol `participante` intenta invocar la función:
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-scan-nfc" \
  -H "Authorization: Bearer <TOKEN_PARTICIPANTE>" \
  -H "Content-Type: application/json" \
  -d '{"nfcToken": "token-123", "accessType": "checkin"}'
```
**Respuesta esperada (HTTP 403)**:
```json
{
  "error": "Acceso no autorizado: se requiere rol de staff o admin"
}
```
