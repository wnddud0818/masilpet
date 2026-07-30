import {cert, getApps, initializeApp, type App} from 'firebase-admin/app';
import {getAuth, type DecodedIdToken} from 'firebase-admin/auth';
import {initializeFirestore} from 'firebase-admin/firestore';

interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
  TOUR_API_KEY: string;
  ALLOWED_ORIGINS: string;
}

type CallableName =
  | 'ensureUserBootstrap'
  | 'deleteUserProgress'
  | 'getNearbyPois'
  | 'attemptCheckIn'
  | 'applyStepProgress'
  | 'syncStepsV2'
  | 'hatchEgg'
  | 'interactWithPet'
  | 'setActivePet'
  | 'setActiveEgg'
  | 'seedStarterRegionData'
  | 'syncKoreaPois'
  | 'syncBusanPois';

type CallableExport = {
  run(request: {
    data: Record<string, unknown>;
    auth: {
      uid: string;
      token: DecodedIdToken;
    };
  }): unknown | Promise<unknown>;
};

type BackendModule = Record<CallableName, CallableExport>;

const callableNames = new Set<CallableName>([
  'ensureUserBootstrap',
  'deleteUserProgress',
  'getNearbyPois',
  'attemptCheckIn',
  'applyStepProgress',
  'syncStepsV2',
  'hatchEgg',
  'interactWithPet',
  'setActivePet',
  'setActiveEgg',
  'seedStarterRegionData',
  'syncKoreaPois',
  'syncBusanPois',
]);

let backendPromise: Promise<BackendModule> | undefined;

function firebaseApp(env: Env): App {
  const existing = getApps()[0];
  if (existing) {
    return existing;
  }

  const app = initializeApp({
    credential: cert({
      projectId: env.FIREBASE_PROJECT_ID,
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
      privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    }),
    projectId: env.FIREBASE_PROJECT_ID,
  });
  initializeFirestore(app, {preferRest: true});
  return app;
}

async function backend(env: Env): Promise<BackendModule> {
  firebaseApp(env);
  backendPromise ??= import('../../functions/src/index')
    .then((module) => module as unknown as BackendModule);
  return backendPromise;
}

function allowedOrigin(request: Request, env: Env): string | null {
  const origin = request.headers.get('Origin');
  if (!origin) {
    return null;
  }
  const allowed = new Set(
    env.ALLOWED_ORIGINS
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
  );
  return allowed.has(origin) ? origin : '';
}

function corsHeaders(origin: string | null): HeadersInit {
  if (!origin) {
    return {};
  }
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

function json(
  body: unknown,
  status: number,
  origin: string | null,
): Response {
  return Response.json(body, {
    status,
    headers: {
      ...corsHeaders(origin),
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}

function statusForCode(code: string): number {
  switch (code) {
    case 'invalid-argument':
      return 400;
    case 'unauthenticated':
      return 401;
    case 'permission-denied':
      return 403;
    case 'not-found':
      return 404;
    case 'already-exists':
      return 409;
    case 'failed-precondition':
      return 412;
    case 'resource-exhausted':
      return 429;
    case 'unavailable':
      return 503;
    default:
      return 500;
  }
}

function errorPayload(error: unknown): {
  status: number;
  body: {
    error: {
      code: string;
      message: string;
      details?: unknown;
    };
  };
} {
  const candidate = error as {
    code?: unknown;
    message?: unknown;
    details?: unknown;
  };
  const code = typeof candidate?.code === 'string'
    ? candidate.code
    : 'internal';
  const message = typeof candidate?.message === 'string'
    ? candidate.message
    : 'Unexpected server error.';
  return {
    status: statusForCode(code),
    body: {
      error: {
        code,
        message,
        ...(candidate?.details === undefined
          ? {}
          : {details: candidate.details}),
      },
    },
  };
}

async function decodeBody(request: Request): Promise<Record<string, unknown>> {
  const contentType = request.headers.get('Content-Type') ?? '';
  if (!contentType.toLowerCase().startsWith('application/json')) {
    throw Object.assign(new Error('Content-Type must be application/json.'), {
      code: 'invalid-argument',
    });
  }
  const body = await request.json();
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw Object.assign(new Error('JSON body must be an object.'), {
      code: 'invalid-argument',
    });
  }
  const candidate = body as Record<string, unknown>;
  const data = candidate.data;
  if (data === undefined) {
    return candidate;
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw Object.assign(new Error('data must be an object.'), {
      code: 'invalid-argument',
    });
  }
  return data as Record<string, unknown>;
}

async function authenticate(
  request: Request,
  env: Env,
): Promise<DecodedIdToken> {
  const authorization = request.headers.get('Authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  if (!match) {
    throw Object.assign(new Error('Authentication is required.'), {
      code: 'unauthenticated',
    });
  }
  try {
    return await getAuth(firebaseApp(env)).verifyIdToken(match[1]);
  } catch {
    throw Object.assign(new Error('Firebase ID token is invalid.'), {
      code: 'unauthenticated',
    });
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = allowedOrigin(request, env);
    if (origin === '') {
      return json(
        {error: {code: 'permission-denied', message: 'Origin is not allowed.'}},
        403,
        null,
      );
    }

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(origin),
      });
    }

    const url = new URL(request.url);
    if (url.pathname === '/health' && request.method === 'GET') {
      return json({
        ok: true,
        service: 'masilpet-api',
        firebaseProjectId: env.FIREBASE_PROJECT_ID,
        firebaseCredentialsConfigured: Boolean(
          env.FIREBASE_CLIENT_EMAIL && env.FIREBASE_PRIVATE_KEY,
        ),
        tourApiConfigured: Boolean(env.TOUR_API_KEY),
      }, 200, origin);
    }

    const match = /^\/v1\/([A-Za-z][A-Za-z0-9]*)$/.exec(url.pathname);
    const functionName = match?.[1] as CallableName | undefined;
    if (!functionName || !callableNames.has(functionName)) {
      return json(
        {error: {code: 'not-found', message: 'Endpoint not found.'}},
        404,
        origin,
      );
    }
    if (request.method !== 'POST') {
      return json(
        {error: {code: 'invalid-argument', message: 'POST is required.'}},
        405,
        origin,
      );
    }

    try {
      const token = await authenticate(request, env);
      const [data, module] = await Promise.all([
        decodeBody(request),
        backend(env),
      ]);
      const result = await module[functionName].run({
        data,
        auth: {uid: token.uid, token},
      });
      return json({data: result}, 200, origin);
    } catch (error) {
      const payload = errorPayload(error);
      return json(payload.body, payload.status, origin);
    }
  },
} satisfies ExportedHandler<Env>;
