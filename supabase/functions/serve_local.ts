import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { handleStaffTeamFromQr } from './staff-team-from-qr/index.ts';
import { handleStaffIssueNfc } from './staff-issue-nfc/index.ts';
import { handleStaffScanNfc } from './staff-scan-nfc/index.ts';

// 1. Cargar variables de entorno desde supabase/.env.local si existe
const envPath = path.resolve(import.meta.dirname ?? '.', '../.env.local');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx > 0) {
        const key = trimmed.slice(0, eqIdx).trim();
        const value = trimmed.slice(eqIdx + 1).trim();
        if (!process.env[key]) {
          process.env[key] = value;
        }
      }
    }
  }
  console.log(`📄 Variables cargadas desde ${envPath}`);
}

// Habilitar autorización de prueba en servidor local si la app no envía JWT
process.env.DEV_ALLOW_ANON_STAFF = 'true';

// 2. Polyfill de Deno para entorno local
const globalObj = globalThis as unknown as {
  Deno?: {
    env: {
      get(key: string): string | undefined;
      set(key: string, val: string): void;
    };
    serve: (handler: (req: Request) => Promise<Response>) => void;
  };
};

if (!globalObj.Deno) {
  globalObj.Deno = {
    env: {
      get: (key: string): string | undefined => process.env[key],
      set: (key: string, val: string): void => {
        process.env[key] = val;
      },
    },
    serve: (): void => {},
  };
}

const PORT = Number(process.env.PORT || 54321);

// 3. Servidor HTTP local con soporte nativo de Web Request/Response
const server = http.createServer(async (req, res) => {
  try {
    const host = req.headers.host || `127.0.0.1:${PORT}`;
    const fullUrl = `http://${host}${req.url || '/'}`;
    const url = new URL(fullUrl);

    // Encabezados
    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) {
      if (v) {
        headers.set(k, Array.isArray(v) ? v.join(', ') : v);
      }
    }

    // Cuerpo
    const chunks: Buffer[] = [];
    for await (const chunk of req) {
      chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
    }
    const bodyBuffer = chunks.length > 0 ? Buffer.concat(chunks) : null;
    const body =
      req.method !== 'GET' && req.method !== 'HEAD' && bodyBuffer && bodyBuffer.length > 0
        ? bodyBuffer
        : null;

    const webReq = new Request(fullUrl, {
      method: req.method,
      headers,
      body,
    });

    console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${url.pathname}`);

    let webRes: Response;
    if (url.pathname.includes('staff-team-from-qr')) {
      webRes = await handleStaffTeamFromQr(webReq);
    } else if (url.pathname.includes('staff-issue-nfc')) {
      webRes = await handleStaffIssueNfc(webReq);
    } else if (url.pathname.includes('staff-scan-nfc')) {
      webRes = await handleStaffScanNfc(webReq);
    } else if (url.pathname === '/' || url.pathname === '/health') {
      webRes = new Response(
        JSON.stringify({
          status: 'ok',
          message: 'Staff Edge Functions Local Server is running',
          database: process.env.SUPABASE_URL || 'not set',
          endpoints: [
            '/functions/v1/staff-team-from-qr',
            '/functions/v1/staff-issue-nfc',
            '/functions/v1/staff-scan-nfc',
          ],
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    } else {
      webRes = new Response(
        JSON.stringify({
          error: 'Ruta no encontrada',
          endpointsDisponibles: [
            '/functions/v1/staff-team-from-qr',
            '/functions/v1/staff-issue-nfc',
            '/functions/v1/staff-scan-nfc',
          ],
        }),
        {
          status: 404,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }

    res.statusCode = webRes.status;
    webRes.headers.forEach((val, key) => {
      res.setHeader(key, val);
    });

    const responseBytes = Buffer.from(await webRes.arrayBuffer());
    res.end(responseBytes);
  } catch (err: unknown) {
    console.error('Error procesando solicitud:', err);
    res.statusCode = 500;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ error: 'Error interno del servidor', details: String(err) }));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`
🚀 Servidor local de Staff Edge Functions iniciado:
   • Local:            http://127.0.0.1:${PORT}
   • Red Wi-Fi:        http://10.0.40.78:${PORT}
   • Base de datos:    ${process.env.SUPABASE_URL || 'No configurada en .env.local'}

Rutas activas:
   POST /functions/v1/staff-team-from-qr
   POST /functions/v1/staff-issue-nfc
   POST /functions/v1/staff-scan-nfc

Para conectar tu teléfono:
   1. En otra terminal ejecuta: npx localtunnel --port ${PORT}
   2. Pega la URL del túnel en la app Flutter.
`);
});
