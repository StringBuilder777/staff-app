import { corsHeaders } from './cors.ts';
import type { ApiErrorResponse } from './types.ts';

/**
 * Returns a Response with application/json Content-Type and CORS headers.
 */
export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

/**
 * Returns a standardized error response with appropriate status code.
 */
export function errorResponse(message: string, status = 400, details?: unknown): Response {
  const payload: ApiErrorResponse = { error: message };
  if (details !== undefined) {
    payload.details = details;
  }
  return jsonResponse(payload, status);
}

/**
 * Safely parses JSON from the request body.
 */
export async function parseJsonBody<T>(req: Request): Promise<T | null> {
  try {
    const text = await req.text();
    if (!text || text.trim() === '') {
      return null;
    }
    return JSON.parse(text) as T;
  } catch {
    return null;
  }
}
