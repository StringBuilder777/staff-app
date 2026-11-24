# Backend Staff - Supabase Edge Functions

Backend serverless para la aplicación de Staff (lectura de QR y tarjetas NFC), implementado con **Supabase Edge Functions** en **TypeScript estricto (sin `any`)**.

- **Proyecto Supabase Ref**: `uopfoekxkluotowilzaa`
- **Tablas involucradas**: `public.equipos`, `public.integrantes`, `public.staff`, `public.perfiles`, `public.sitec_asistentes` (SITEC)

---

## Edge Functions Disponibles

| Función | Método | Endpoint | Descripción |
| :--- | :--- | :--- | :--- |
| **`staff-team-from-qr`** | `POST` | `/functions/v1/staff-team-from-qr` | Busca equipo por `qr_token` y devuelve sus integrantes con datos operativos. Nunca expone datos sensibles. |
| **`staff-issue-nfc`** | `POST` | `/functions/v1/staff-issue-nfc` | Asigna o reactiva el `nfc_token` de un integrante y genera el payload exacto `staffapp:nfc:<token>`. |
| **`staff-scan-nfc`** | `POST` | `/functions/v1/staff-scan-nfc` | Registra accesos de `checkin` y `cena` (viernes) y de `desayuno`, `comida` y `checkout` (sábado) atómicamente evitando duplicados (HTTP 409). Con `accessType: "salida"` funciona como interruptor sobre `hackathon_salidas`: si la persona está dentro abre una salida y si está fuera la cierra con su regreso. La respuesta lleva `movimiento` (`salida` o `regreso`) y `salioEn`. Una segunda lectura en menos de 30 s es una doble lectura: devuelve 409 y no cambia nada. La app y el lector mandan un `lecturaId` (uuid) por lectura: si la respuesta se pierde y reintentan con el mismo id, se devuelve lo que ya se registró (`repetida: true`) en vez de alternar otra vez. |
| **`staff-sitec-scan-nfc`** | `POST` | `/functions/v1/staff-sitec-scan-nfc` | Igual que `staff-scan-nfc`, pero para SITEC: valida contra `sitec_asistentes` los puntos `jueves_entrada`, `jueves_comida`, `jueves_salida`, `viernes_entrada`, `viernes_salida`, `viernes_comida` (inicio de la comida) y `viernes_comida_fin` (fin de la comida). No toca las tablas del hackathon. El `asistente` de la respuesta lleva su `kit` (`premium`, `basico`, `general` o `null`). |
| **`staff-sitec-asistentes`** | `POST` | `/functions/v1/staff-sitec-asistentes` | Lista a los asistentes de SITEC para el registro, en orden alfabético: `id`, `nombre`, `apellidos` y `nfc_emitida_en`. Nunca expone el token NFC. Exige el mismo permiso que los accesos de SITEC (`puede_escanear`). |
| **`staff-sitec-issue-nfc`** | `POST` | `/functions/v1/staff-sitec-issue-nfc` | Emite la tarjeta de un asistente de SITEC en dos pasos: sin `written` reactiva su `nfc_token` y devuelve el payload `staffapp:nfc:<token>`; con `written: true` la app confirma que la escribió y se marca `nfc_emitida_en`. Exige el mismo permiso que los accesos de SITEC. |

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
   - `staff-scan-nfc` y `staff-sitec-scan-nfc` ejecutan una actualización condicional en PostgreSQL (`.is(timeCol, null)`) garantizando que solicitudes concurrentes no generen registros dobles. Si ya existe un registro previo, devuelven `HTTP 409 Conflict` con la fecha y hora original.

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
# Desplegar las seis funciones al proyecto uopfoekxkluotowilzaa
npx supabase functions deploy staff-team-from-qr --project-ref uopfoekxkluotowilzaa
npx supabase functions deploy staff-issue-nfc --project-ref uopfoekxkluotowilzaa
npx supabase functions deploy staff-scan-nfc --project-ref uopfoekxkluotowilzaa
npx supabase functions deploy staff-sitec-scan-nfc --project-ref uopfoekxkluotowilzaa
npx supabase functions deploy staff-sitec-asistentes --project-ref uopfoekxkluotowilzaa
npx supabase functions deploy staff-sitec-issue-nfc --project-ref uopfoekxkluotowilzaa

# O desplegar todas simultáneamente:
npx supabase functions deploy --project-ref uopfoekxkluotowilzaa
```

### 3. Configurar Secretos en el Proyecto Remoto

```bash
npx supabase secrets set --project-ref uopfoekxkluotowilzaa \
  MI_VARIABLE_PERSONALIZADA=valor
```

---

## Scripts de SITEC (se ejecutan a mano)

No son migraciones: se pegan en Supabase → SQL Editor cuando hacen falta.

- **Cambios del 2026-10-08 (cena, check-out y salidas del hackathon; fin de la comida del viernes de SITEC).** `scripts/hack_salidas_y_comida_viernes.sql` junta, en el orden en que hay que correrlas, las migraciones `20261007120000`, `20261008120000` y `20261008121000` y los permisos de lectura del panel de admin (bloques del 2026-10-04 y del 2026-10-08 de `database/alter.sql` del sitio). Es aditivo y se puede repetir. Se corre antes de desplegar `staff-scan-nfc` y `staff-sitec-scan-nfc` y de repartir la APK: sin la tabla `hackathon_salidas`, la salida responde 500, y sin la columna `viernes_comida_fin_en`, el fin de la comida también.

- **Kits desde el CSV de ventas.** `scripts/sitec_kits_desde_csv.py` lee la hoja «Registro» exportada a CSV y genera dos SQL. El de revisión no cambia nada: cuenta las ventas que ya están en la tabla y lista a quién se daría de alta y qué asistentes no aparecen en ventas. El otro pone el kit (`premium`, `basico` o `general`) a cada asistente y da de alta, con su kit, a quien todavía no está. Busca por nombre completo sin distinguir mayúsculas, acentos ni espacios, así que se puede repetir con un CSV más reciente sin duplicar a nadie. Los SQL llevan los nombres de los asistentes: se generan fuera del repositorio.

  ```bash
  python3 supabase/scripts/sitec_kits_desde_csv.py --revisar ventas.csv > /tmp/sitec_kits_1_revisar.sql
  python3 supabase/scripts/sitec_kits_desde_csv.py ventas.csv > /tmp/sitec_kits_2_aplicar.sql
  ```

  Quien aún no está en la hoja se suma con `--agregar "Nombre completo=kit"`, una vez por persona.

- **Altas sueltas.** `scripts/sitec_agregar_asistentes.sql` da de alta, con su kit, a quien se inscribe después: se pega en el SQL Editor, se escribe ahí una fila por persona (nombre, apellidos y kit) y se ejecuta. Los nombres no se escriben en el archivo, que está en el repositorio. A quien ya está no lo duplica, solo le pone el kit.

- **Borrar los accesos y salidas de un participante de prueba del hackathon.** `scripts/hack_limpiar_accesos.sql` hace lo mismo que el de SITEC para `integrantes`: vacía check-in, cena, desayuno, comida y check-out de un solo participante, buscado por nombre, y borra sus salidas. Si el nombre no coincide con nadie o coincide con varios, no borra nada. No toca su tarjeta, su equipo ni a nadie más. Va después de `hack_salidas_y_comida_viernes.sql`.

- **Borrar los accesos de un asistente de prueba.** `scripts/sitec_limpiar_accesos.sql` vacía las entradas, comidas y salidas de un solo asistente, buscado por nombre. Si el nombre no coincide con nadie o coincide con varios, no borra nada. No toca su tarjeta ni su kit, ni a nadie más.

---

## Ejecutar Pruebas y Verificación de Tipos

El proyecto cuenta con verificación estricta de TypeScript y una suite automatizada de 63 pruebas de integración/unitarias:

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
      "cena_en": null,
      "desayuno_en": null,
      "comida_en": null,
      "checkout_en": null
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
    "cena_en": null,
    "desayuno_en": null,
    "comida_en": null,
    "checkout_en": null
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
    "cena_en": null,
    "desayuno_en": null,
    "comida_en": null,
    "checkout_en": null
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

### Caso 7: `staff-sitec-asistentes` (Éxito)
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-sitec-asistentes" \
  -H "Authorization: Bearer <TOKEN_STAFF>" \
  -H "Content-Type: application/json" \
  -d '{}'
```
**Respuesta esperada (HTTP 200)**:
```json
{
  "asistentes": [
    {
      "id": "b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e",
      "nombre": "Marta",
      "apellidos": "Ruiz",
      "nfc_emitida_en": null
    }
  ]
}
```

### Caso 8: `staff-sitec-issue-nfc` (Éxito)
Primero se pide el payload y, cuando la tarjeta ya está escrita, se repite la llamada con `"written": true` para que el registro la cuente.
```bash
curl -i -X POST "https://uopfoekxkluotowilzaa.supabase.co/functions/v1/staff-sitec-issue-nfc" \
  -H "Authorization: Bearer <TOKEN_STAFF>" \
  -H "Content-Type: application/json" \
  -d '{"asistenteId": "b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e"}'
```
**Respuesta esperada (HTTP 200)**:
```json
{
  "asistenteId": "b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e",
  "nfcToken": "6f1c2a9e-4b7d-4e2a-9c3f-1a2b3c4d5e6f",
  "payload": "staffapp:nfc:6f1c2a9e-4b7d-4e2a-9c3f-1a2b3c4d5e6f"
}
```
