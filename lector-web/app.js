// Lector de tarjetas para el staff con iPhone. El iPhone abre en Safari la
// dirección grabada en la tarjeta (`<página>/#<evento>/<token>`) y esta página
// registra el acceso en el punto elegido con las mismas Edge Functions que la
// app. El token va tras `#`, así que nunca llega al servidor de la página.
//
// No se carga código de terceros: la sesión se pide directamente a Supabase
// Auth, así que nadie más ve el token ni la sesión.
import { SUPABASE_ANON_KEY, SUPABASE_URL } from './config.js';

// Mismos puntos y en el mismo orden que la app (lib/main.dart). La letra es la
// que la app graba en la tarjeta (NfcCardEvent en lib/services/nfc_service.dart).
const EVENTS = {
  s: {
    name: 'SITEC',
    fn: 'staff-sitec-scan-nfc',
    person: (body) => body.asistente,
    points: [
      ['jueves_entrada', 'Jueves · Entrada'],
      ['jueves_comida', 'Jueves · Comida'],
      ['jueves_salida', 'Jueves · Salida'],
      ['viernes_entrada', 'Viernes · Entrada'],
      ['viernes_salida', 'Viernes · Salida'],
      ['viernes_comida', 'Viernes · Comida'],
    ],
  },
  h: {
    name: 'Hackathon',
    fn: 'staff-scan-nfc',
    person: (body) => body.participante,
    points: [
      ['checkin', 'Check-in'],
      ['desayuno', 'Desayuno'],
      ['comida', 'Comida'],
    ],
  },
};

const CARD =
  /^#([sh])\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i;

// Kits de SITEC, como los guarda la base (sitec_asistentes.kit).
const KITS = { premium: 'Premium', basico: 'Básico', general: 'General' };

// Un acceso duplicado se muestra como 67, igual que en la app.
const DUPLICATE_CODE = '67';

const SESSION_KEY = 'lector.sesion';
const POINT_KEY = 'lector.punto';
const PENDING_KEY = 'lector.tarjetas';

// Una tarjeta que espera a que se inicie sesión o se elija el punto caduca a
// los cinco minutos: abrir la página más tarde no debe registrar a nadie.
const PENDING_TTL_MS = 5 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 15 * 1000;

// Acercar dos veces seguidas la misma tarjeta no la manda dos veces.
const REPEAT_MS = 10 * 1000;

// El punto elegido caduca tras dos horas sin registrar nada en él: en el
// siguiente turno o al día siguiente se vuelve a elegir, para no registrar a
// nadie en el punto de antes.
const POINT_IDLE_MS = 2 * 60 * 60 * 1000;

const $ = (id) => document.getElementById(id);

function readJson(storage, key) {
  try {
    return JSON.parse(storage.getItem(key) ?? 'null');
  } catch {
    return null;
  }
}

// Sesión de staff -----------------------------------------------------------

/** Sin red, sin respuesta a tiempo o con el servidor caído. */
class Offline extends Error {}

/**
 * Petición a Supabase. Devuelve { ok, status, body }. El tope de tiempo cubre
 * también el cuerpo de la respuesta: sin red o sin respuesta a tiempo lanza
 * Offline.
 */
async function request(path, { headers = {}, ...options } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(`${SUPABASE_URL}${path}`, {
      ...options,
      headers: {
        apikey: SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        ...headers,
      },
      signal: controller.signal,
    });
    const body = await response.json().catch((error) => {
      if (controller.signal.aborted) throw error;
      return {};
    });
    return { ok: response.ok, status: response.status, body };
  } catch {
    throw new Offline();
  } finally {
    clearTimeout(timer);
  }
}

function storedSession() {
  const session = readJson(localStorage, SESSION_KEY);
  return session?.accessToken && session?.refreshToken ? session : null;
}

function saveSession(body) {
  const session = {
    accessToken: body.access_token,
    refreshToken: body.refresh_token,
    expiresAt:
      body.expires_at ?? Math.floor(Date.now() / 1000) + body.expires_in,
  };
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  return session;
}

function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

/**
 * Token de acceso vigente, renovado si caducó o si se pide con [renew]. Null
 * si hay que volver a entrar. Sin red lanza Offline.
 */
async function accessToken({ renew = false } = {}) {
  const session = storedSession();
  if (!session) return null;
  if (!renew && session.expiresAt - 60 > Date.now() / 1000) {
    return session.accessToken;
  }

  const response = await request('/auth/v1/token?grant_type=refresh_token', {
    method: 'POST',
    body: JSON.stringify({ refresh_token: session.refreshToken }),
  });
  if (response.ok) return saveSession(response.body).accessToken;
  // Servidor caído o demasiadas peticiones: es pasajero y la sesión sigue.
  if (response.status >= 500 || response.status === 429) throw new Offline();

  // Otra pestaña pudo renovarla a la vez: entonces vale la suya.
  const current = storedSession();
  if (current && current.refreshToken !== session.refreshToken) {
    return current.accessToken;
  }
  clearSession();
  return null;
}

/**
 * Entra con la cuenta de staff. Devuelve null si entró, o el motivo si no.
 * Sin red lanza Offline.
 */
async function signIn(email, password) {
  const response = await request('/auth/v1/token?grant_type=password', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  if (response.ok) {
    saveSession(response.body);
    return null;
  }
  if (response.status >= 500) throw new Offline();
  if (response.body.error_code === 'email_not_confirmed') {
    return 'El correo de esta cuenta aún no está confirmado.';
  }
  if (response.status === 400) return 'Correo o contraseña incorrectos.';
  if (response.status === 429) {
    return 'Demasiados intentos. Espera un momento y vuelve a probar.';
  }
  return `No se pudo entrar (error ${response.status}).`;
}

function signOut() {
  const session = storedSession();
  clearSession();
  if (!session) return;
  // Solo esta sesión: la misma cuenta puede estar abierta en otros teléfonos.
  request('/auth/v1/logout?scope=local', {
    method: 'POST',
    headers: { Authorization: `Bearer ${session.accessToken}` },
  }).catch(() => {});
}

// Tarjetas y puntos ---------------------------------------------------------

function pointFrom(event, code) {
  const point = EVENTS[event]?.points.find(([candidate]) => candidate === code);
  return point ? { event, code: point[0], label: point[1] } : null;
}

/** Último punto elegido, aunque haya caducado, o null. */
function lastPoint() {
  const saved = readJson(localStorage, POINT_KEY);
  const point = saved ? pointFrom(saved.event, saved.code) : null;
  return point ? { ...point, usedAt: saved.usedAt } : null;
}

/** Punto elegido si sigue vigente, con su evento y su etiqueta, o null. */
function savedPoint() {
  const point = lastPoint();
  return point && Date.now() - point.usedAt < POINT_IDLE_MS ? point : null;
}

function savePoint(point) {
  localStorage.setItem(
    POINT_KEY,
    JSON.stringify({ event: point.event, code: point.code, usedAt: Date.now() }),
  );
}

/**
 * Registrar en el punto elegido lo mantiene vigente. Uno caducado no revive:
 * reintentar una tarjeta de ayer no debe valer para las de hoy.
 */
function touchPoint(point) {
  const current = savedPoint();
  if (current?.event === point.event && current.code === point.code) {
    savePoint(point);
  }
}

/**
 * Punto donde se acercó la tarjeta. Si aún no había ninguno de su evento, el
 * que se elija después.
 */
function pointOf(card) {
  if (card.point) return pointFrom(card.event, card.point);
  const saved = savedPoint();
  return saved?.event === card.event ? saved : null;
}

/** Tarjetas que esperan a que se inicie sesión o se elija el punto. */
function pendingCards() {
  const cards = readJson(sessionStorage, PENDING_KEY);
  if (!Array.isArray(cards)) return [];
  const fresh = cards.filter(
    (card) => EVENTS[card?.event] && Date.now() - card.at < PENDING_TTL_MS,
  );
  if (fresh.length !== cards.length) savePending(fresh);
  return fresh;
}

function savePending(cards) {
  if (cards.length) sessionStorage.setItem(PENDING_KEY, JSON.stringify(cards));
  else sessionStorage.removeItem(PENDING_KEY);
}

function addPending(card) {
  const others = pendingCards().filter((other) => other.token !== card.token);
  savePending([...others, card]);
}

function removePending(card) {
  savePending(pendingCards().filter((other) => other.token !== card.token));
}

/**
 * Tarjeta que trae la dirección, si la hay. Se quita de la barra para que
 * recargar la página no la vuelva a leer.
 */
function takeCardFromUrl() {
  const match = CARD.exec(location.hash);
  if (!match) return null;
  history.replaceState(null, '', location.pathname + location.search);
  return {
    event: match[1].toLowerCase(),
    token: match[2].toLowerCase(),
    at: Date.now(),
  };
}

// Vistas ---------------------------------------------------------------------

function show(view) {
  for (const id of ['login', 'points', 'scan']) $(id).hidden = id !== view;
}

/**
 * Los nombres llegan del backend: van siempre como texto, nunca como HTML.
 * `badge` es el aviso grande de arriba y `kit`, el de SITEC (ver kitOf).
 */
function showResult(kind, title, detail = '', { badge, kit } = {}) {
  const parts = [];
  if (badge) parts.push(paragraph('badge', badge));
  parts.push(paragraph('title', title));
  if (kit) parts.push(paragraph(kit.premium ? 'kit premium' : 'kit', `Kit ${kit.label}`));
  parts.push(paragraph('detail', detail));
  const result = $('result');
  result.className = `result ${kind}`;
  result.replaceChildren(...parts);
}

function paragraph(className, text) {
  const p = document.createElement('p');
  p.className = className;
  p.textContent = text;
  return p;
}

/**
 * Con [onlyEvent], solo los puntos del evento de la tarjeta que espera. El
 * último punto elegido sale marcado: como actual si sigue vigente.
 */
function showPoints(onlyEvent) {
  const last = lastPoint();
  const active = savedPoint() !== null;
  const list = $('point-list');
  list.replaceChildren();
  for (const [key, event] of Object.entries(EVENTS)) {
    if (onlyEvent && key !== onlyEvent) continue;
    const group = document.createElement('fieldset');
    const legend = document.createElement('legend');
    legend.textContent = event.name.toUpperCase();
    group.append(legend);
    for (const [code, label] of event.points) {
      const option = document.createElement('button');
      option.type = 'button';
      option.className = 'point-option';
      option.textContent = label;
      if (last?.event === key && last.code === code) {
        option.classList.add(active ? 'current' : 'previous');
        option.setAttribute('aria-current', 'true');
      }
      option.addEventListener('click', () => {
        savePoint({ event: key, code });
        // Si se pregunta por tarjetas que esperan, se registran donde se elija.
        if (onlyEvent) {
          savePending(
            pendingCards().map((card) => {
              return card.event === key ? { ...card, point: code } : card;
            }),
          );
        }
        route();
      });
      group.append(option);
    }
    list.append(group);
  }

  const hint = $('points-hint');
  hint.hidden = !onlyEvent;
  if (onlyEvent) {
    const name = EVENTS[onlyEvent].name;
    hint.textContent = `La tarjeta es de ${name}: elige en qué punto de ${name} estás.`;
  }
  show('points');
}

function showScan(point, { keepResult = false } = {}) {
  $('current-point').textContent = `${EVENTS[point.event].name} · ${point.label}`;
  // Con un registro en curso, su resultado sustituye a «Registrando…». Una
  // tarjeta repetida deja a la vista lo que salió con ella.
  if (!busy && !keepResult) {
    showResult('idle', 'Listo', 'Acerca la siguiente tarjeta.');
  }
  renderFailed();
  show('scan');
}

// Registro -------------------------------------------------------------------

/**
 * Tarjetas que no se pudieron registrar por la red o el servidor. Solo se
 * reintentan a mano y en el punto donde se leyeron: cambiar de punto después
 * no debe registrar a nadie donde no está.
 */
const failed = [];

/** Cuándo se mandó cada token, para no mandar dos veces la misma tarjeta. */
const sentAt = new Map();

function sentRecently(token) {
  const at = sentAt.get(token);
  return at !== undefined && Date.now() - at < REPEAT_MS;
}

function renderFailed() {
  const list = $('failed');
  list.replaceChildren();
  for (const entry of failed) {
    const item = document.createElement('li');
    const label = document.createElement('span');
    label.textContent = `Tarjeta …${entry.card.token.slice(-4)} · ${entry.point.label}`;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'link';
    button.textContent = 'Reintentar';
    button.addEventListener('click', () => retry(entry));
    item.append(label, button);
    list.append(item);
  }
  $('failed-block').hidden = failed.length === 0;
}

function fail(card, point, title, detail) {
  // Se puede volver a acercar enseguida para reintentar.
  sentAt.delete(card.token);
  const known = failed.some(
    (entry) => entry.card.token === card.token && entry.point.code === point.code,
  );
  if (!known) failed.push({ card, point });
  renderFailed();
  showResult('error', title, detail);
}

function personName(person) {
  return [person?.nombre, person?.apellidos].filter(Boolean).join(' ').trim();
}

/**
 * Kit de SITEC tal como se muestra. La base lo guarda en minúsculas y sin
 * acento; un valor que la página no conozca se muestra tal cual. El hackathon
 * no tiene kits y no muestra nada.
 */
function kitOf(person) {
  const kit = typeof person?.kit === 'string' ? person.kit.trim().toLowerCase() : '';
  if (!kit) return null;
  return { label: KITS[kit] ?? kit, premium: kit === 'premium' };
}

/** Hora local (13:05) de un instante ISO, o '' si no llega o no se entiende. */
function clock(iso) {
  if (typeof iso !== 'string') return '';
  const date = new Date(iso);
  return Number.isNaN(date.getTime())
    ? ''
    : date.toLocaleTimeString('es-MX', {
        hour: '2-digit',
        minute: '2-digit',
        hourCycle: 'h23',
      });
}

// Los registros van de uno en uno, en el orden en que llegan.
let queue = Promise.resolve();
let busy = false;

function serial(task) {
  queue = queue
    .then(async () => {
      busy = true;
      try {
        await task();
      } finally {
        busy = false;
      }
    })
    .catch(() => {});
  return queue;
}

/** Registra la tarjeta en el punto. Devuelve false si hay que volver a entrar. */
async function send(card, point, renewed = false) {
  const event = EVENTS[card.event];
  sentAt.set(card.token, Date.now());
  touchPoint(point);
  showResult('busy', 'Registrando…', point.label);

  let response;
  try {
    const token = await accessToken({ renew: renewed });
    if (!token) {
      sentAt.delete(card.token);
      return false;
    }
    response = await request(`/functions/v1/${event.fn}`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify({ nfcToken: card.token, accessType: point.code }),
    });
  } catch {
    fail(card, point, 'Sin conexión', 'Revisa la conexión y reintenta.');
    return true;
  }

  // Un token rechazado se renueva una vez antes de pedir que se vuelva a entrar.
  if (response.status === 401) {
    if (!renewed) return send(card, point, true);
    clearSession();
    sentAt.delete(card.token);
    return false;
  }

  const body = response.body;
  if (response.status >= 500) {
    fail(
      card,
      point,
      'No se pudo registrar',
      body.error ?? `Error ${response.status}.`,
    );
    return true;
  }

  const person = event.person(body);
  const name = personName(person);
  const kit = kitOf(person);
  const team = body.equipo?.nombre;
  if (response.ok) {
    showResult(
      'ok',
      name || 'Acceso registrado',
      team ? `${point.label} · ${team}` : point.label,
      { kit },
    );
  } else if (response.status === 409) {
    // Un duplicado no es un error más: va en rojo, con su propio aviso y el
    // mismo código que la app, y dice cuándo se registró la primera vez.
    const time = clock(body.previouslyRegisteredAt);
    showResult(
      'dup',
      name || 'Tarjeta ya registrada',
      time
        ? `Ya se registró en ${point.label} a las ${time}.`
        : `Ya se registró en ${point.label}.`,
      { badge: `${DUPLICATE_CODE} · Ya registrado`, kit },
    );
  } else if (response.status === 404) {
    showResult('error', 'Tarjeta no encontrada', 'No existe o está desactivada.');
  } else if (response.status === 403) {
    showResult(
      'error',
      'Sin permiso',
      body.error ?? 'Tu cuenta no puede registrar accesos.',
    );
  } else {
    showResult(
      'error',
      'No se pudo registrar',
      body.error ?? `Error ${response.status}.`,
    );
  }
  return true;
}

/** Registra las tarjetas que esperaban, cada una en su punto. */
function drain() {
  return serial(async () => {
    for (;;) {
      const [card] = pendingCards();
      const point = card && pointOf(card);
      if (!card || !point) break;
      // Se saca de la espera antes de mandarla: pase lo que pase, no vuelve a
      // registrarse sola.
      removePending(card);
      if (!(await send(card, point))) {
        // Hay que volver a entrar; después se registra en este mismo punto.
        addPending({ ...card, point: point.code });
        break;
      }
    }
    // Falta entrar, o la siguiente es de otro evento y hay que elegir punto.
    if (pendingCards().length) setTimeout(route);
  });
}

function retry(entry) {
  const index = failed.indexOf(entry);
  if (index < 0) return;
  failed.splice(index, 1);
  renderFailed();
  serial(async () => {
    if (!(await send(entry.card, entry.point))) {
      // Hay que volver a entrar: el reintento sigue siendo a mano.
      failed.push(entry);
      setTimeout(route);
    }
  });
}

/**
 * Con [menu], si no llega ninguna tarjeta se muestra el menú de puntos: al
 * abrir la página se elige dónde se registra, que puede no ser donde se
 * registró la última vez. Las tarjetas se registran en el punto elegido.
 */
async function route({ menu = false } = {}) {
  const card = takeCardFromUrl();
  const repeated = card !== null && sentRecently(card.token);
  if (card && !repeated) {
    // Se registra en el punto donde se acercó, aunque luego se cambie.
    const point = savedPoint();
    if (point?.event === card.event) card.point = point.code;
    addPending(card);
  }

  const signedIn = storedSession() !== null;
  $('logout').hidden = !signedIn;
  if (!signedIn) {
    show('login');
    return;
  }

  const point = savedPoint();
  const [next] = pendingCards();
  if (!point || (next && !pointOf(next)) || (menu && !next)) {
    showPoints(next?.event);
    return;
  }

  showScan(point, { keepResult: repeated });
  await drain();
}

$('login-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = $('login-button');
  const error = $('login-error');
  button.disabled = true;
  error.hidden = true;
  try {
    const problem = await signIn($('email').value.trim(), $('password').value);
    if (problem === null) {
      $('password').value = '';
      route({ menu: true });
      return;
    }
    error.textContent = problem;
  } catch {
    error.textContent = 'Sin conexión. Revisa la conexión y vuelve a intentarlo.';
  } finally {
    button.disabled = false;
  }
  error.hidden = false;
});

$('logout').addEventListener('click', () => {
  signOut();
  failed.length = 0;
  savePending([]);
  route();
});

$('change-point').addEventListener('click', () => showPoints());

// Safari puede reutilizar la pestaña y cambiar solo lo que va tras `#`.
window.addEventListener('hashchange', () => route());

// Volver a una pestaña que Safari guardó entera cuenta como abrir la página.
window.addEventListener('pageshow', (event) => {
  if (event.persisted) route({ menu: true });
});

route({ menu: true });
