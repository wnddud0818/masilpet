type DocumentData = Record<string, unknown>;

type SetOptions = {
  merge?: boolean;
};

type QueryOperator = '==' | '>=' | 'in';

type QueryFilter = {
  fieldPath: string;
  operator: QueryOperator;
  value: unknown;
};

type PendingWrite =
  | {
    kind: 'set';
    ref: DocumentReference;
    data: DocumentData;
    merge: boolean;
  }
  | {
    kind: 'update';
    ref: DocumentReference;
    data: DocumentData;
  }
  | {
    kind: 'delete';
    ref: DocumentReference;
  };

type FirestoreValue =
  | {nullValue: null}
  | {booleanValue: boolean}
  | {integerValue: string}
  | {doubleValue: number}
  | {timestampValue: string}
  | {stringValue: string}
  | {bytesValue: string}
  | {arrayValue: {values?: FirestoreValue[]}}
  | {mapValue: {fields?: Record<string, FirestoreValue>}};

type FirestoreDocument = {
  name: string;
  fields?: Record<string, FirestoreValue>;
};

type FirestoreWrite = {
  update?: {
    name: string;
    fields: Record<string, FirestoreValue>;
  };
  updateMask?: {
    fieldPaths: string[];
  };
  updateTransforms?: Array<{
    fieldPath: string;
    setToServerValue: 'REQUEST_TIME';
  }>;
  currentDocument?: {
    exists: boolean;
  };
  delete?: string;
};

type GoogleApiErrorBody = {
  error?: {
    code?: number;
    message?: string;
    status?: string;
  };
};

const firestoreScope = 'https://www.googleapis.com/auth/datastore';
const oauthTokenUrl = 'https://oauth2.googleapis.com/token';
const defaultDatabaseId = '(default)';

let cachedAccessToken = '';
let cachedAccessTokenExpiresAt = 0;

export class Timestamp {
  private constructor(private readonly value: Date) {}

  static now(): Timestamp {
    return new Timestamp(new Date());
  }

  static fromDate(value: Date): Timestamp {
    return new Timestamp(new Date(value.getTime()));
  }

  toDate(): Date {
    return new Date(this.value.getTime());
  }

  toMillis(): number {
    return this.value.getTime();
  }

  toISOString(): string {
    return this.value.toISOString();
  }
}

export class FieldValue {
  private constructor(readonly kind: 'serverTimestamp') {}

  static serverTimestamp(): FieldValue {
    return new FieldValue('serverTimestamp');
  }
}

export class DocumentReference {
  constructor(
    readonly firestore: RestFirestore,
    readonly path: string,
  ) {}

  get id(): string {
    return this.path.split('/').at(-1) ?? '';
  }

  collection(name: string): CollectionReference {
    assertSegment(name, 'collection');
    return new CollectionReference(this.firestore, `${this.path}/${name}`);
  }

  async get(): Promise<DocumentSnapshot> {
    return this.firestore.getDocument(this);
  }
}

export class CollectionReference {
  constructor(
    readonly firestore: RestFirestore,
    readonly path: string,
  ) {}

  doc(id: string): DocumentReference {
    assertSegment(id, 'document');
    return new DocumentReference(this.firestore, `${this.path}/${id}`);
  }

  where(
    fieldPath: string,
    operator: QueryOperator,
    value: unknown,
  ): Query {
    return new Query(
      this.firestore,
      this.path,
      [{fieldPath, operator, value}],
      undefined,
    );
  }

  limit(value: number): Query {
    return new Query(this.firestore, this.path, [], value);
  }

  async get(): Promise<QuerySnapshot> {
    return new Query(this.firestore, this.path).get();
  }
}

export class Query {
  constructor(
    readonly firestore: RestFirestore,
    readonly collectionPath: string,
    readonly filters: QueryFilter[] = [],
    readonly limitCount?: number,
  ) {}

  where(
    fieldPath: string,
    operator: QueryOperator,
    value: unknown,
  ): Query {
    return new Query(
      this.firestore,
      this.collectionPath,
      [...this.filters, {fieldPath, operator, value}],
      this.limitCount,
    );
  }

  limit(value: number): Query {
    return new Query(
      this.firestore,
      this.collectionPath,
      this.filters,
      value,
    );
  }

  async get(): Promise<QuerySnapshot> {
    return this.firestore.runQuery(this);
  }
}

export class DocumentSnapshot {
  constructor(
    readonly ref: DocumentReference,
    private readonly value?: DocumentData,
  ) {}

  get exists(): boolean {
    return this.value !== undefined;
  }

  get id(): string {
    return this.ref.id;
  }

  data(): DocumentData | undefined {
    return this.value;
  }
}

export class QuerySnapshot {
  constructor(readonly docs: DocumentSnapshot[]) {}

  get empty(): boolean {
    return this.docs.length === 0;
  }

  get size(): number {
    return this.docs.length;
  }
}

export class WriteBatch {
  protected readonly writes: PendingWrite[] = [];

  constructor(protected readonly firestore: RestFirestore) {}

  set(
    ref: DocumentReference,
    data: DocumentData,
    options: SetOptions = {},
  ): this {
    this.writes.push({
      kind: 'set',
      ref,
      data,
      merge: options.merge === true,
    });
    return this;
  }

  update(ref: DocumentReference, data: DocumentData): this {
    this.writes.push({kind: 'update', ref, data});
    return this;
  }

  delete(ref: DocumentReference): this {
    this.writes.push({kind: 'delete', ref});
    return this;
  }

  async commit(): Promise<void> {
    await this.firestore.commitWrites(this.writes);
    this.writes.length = 0;
  }
}

export class Transaction extends WriteBatch {
  constructor(
    firestore: RestFirestore,
    private readonly transactionId: string,
  ) {
    super(firestore);
  }

  async get(
    target: DocumentReference | CollectionReference | Query,
  ): Promise<DocumentSnapshot | QuerySnapshot> {
    if (target instanceof DocumentReference) {
      return this.firestore.getDocument(target, this.transactionId);
    }
    const query = target instanceof CollectionReference
      ? new Query(this.firestore, target.path)
      : target;
    return this.firestore.runQuery(query, this.transactionId);
  }

  async commit(): Promise<void> {
    await this.firestore.commitWrites(this.writes, this.transactionId);
    this.writes.length = 0;
  }
}

class RestFirestoreApiError extends Error {
  constructor(
    message: string,
    readonly httpStatus: number,
    readonly googleStatus?: string,
  ) {
    super(message);
    this.name = 'RestFirestoreApiError';
  }
}

export class RestFirestore {
  private readonly projectId: string;
  private readonly databaseRoot: string;

  constructor() {
    this.projectId = requiredEnvironmentValue('FIREBASE_PROJECT_ID');
    this.databaseRoot =
      `projects/${this.projectId}/databases/${defaultDatabaseId}`;
  }

  collection(name: string): CollectionReference {
    assertSegment(name, 'collection');
    return new CollectionReference(this, name);
  }

  batch(): WriteBatch {
    return new WriteBatch(this);
  }

  async runTransaction<T>(
    callback: (transaction: Transaction) => Promise<T>,
  ): Promise<T> {
    const maxAttempts = 5;
    let lastError: unknown;

    for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
      const transactionId = await this.beginTransaction();
      const transaction = new Transaction(this, transactionId);
      try {
        const result = await callback(transaction);
        await transaction.commit();
        return result;
      } catch (error) {
        lastError = error;
        await this.rollback(transactionId);
        if (!isRetryableTransactionError(error) || attempt === maxAttempts - 1) {
          throw error;
        }
      }
    }

    throw lastError;
  }

  async recursiveDelete(ref: DocumentReference): Promise<void> {
    const names: string[] = [];
    await this.collectDocumentTree(ref.path, names);
    names.push(this.documentName(ref.path));

    for (let offset = 0; offset < names.length; offset += 400) {
      const writes = names.slice(offset, offset + 400).map((name) => ({
        delete: name,
      }));
      await this.request('/documents:commit', {
        method: 'POST',
        body: JSON.stringify({writes}),
      });
    }
  }

  async getDocument(
    ref: DocumentReference,
    transactionId?: string,
  ): Promise<DocumentSnapshot> {
    const query = transactionId
      ? `?transaction=${encodeURIComponent(transactionId)}`
      : '';
    try {
      const document = await this.request<FirestoreDocument>(
        `/documents/${encodeDocumentPath(ref.path)}${query}`,
      );
      return snapshotFromDocument(this, document);
    } catch (error) {
      if (error instanceof RestFirestoreApiError && error.httpStatus === 404) {
        return new DocumentSnapshot(ref);
      }
      throw error;
    }
  }

  async runQuery(
    query: Query,
    transactionId?: string,
  ): Promise<QuerySnapshot> {
    const pathSegments = query.collectionPath.split('/');
    const collectionId = pathSegments.at(-1) ?? '';
    const parentPath = pathSegments.slice(0, -1).join('/');
    const parentSuffix = parentPath
      ? `/${encodeDocumentPath(parentPath)}`
      : '';
    const structuredQuery: Record<string, unknown> = {
      from: [{collectionId}],
    };

    if (query.filters.length === 1) {
      structuredQuery.where = fieldFilter(query.filters[0]);
    } else if (query.filters.length > 1) {
      structuredQuery.where = {
        compositeFilter: {
          op: 'AND',
          filters: query.filters.map(fieldFilter),
        },
      };
    }
    if (query.limitCount !== undefined) {
      structuredQuery.limit = query.limitCount;
    }

    const rows = await this.request<Array<{document?: FirestoreDocument}>>(
      `/documents${parentSuffix}:runQuery`,
      {
        method: 'POST',
        body: JSON.stringify({
          structuredQuery,
          ...(transactionId ? {transaction: transactionId} : {}),
        }),
      },
    );

    return new QuerySnapshot(
      rows
        .flatMap((row) => row.document ? [row.document] : [])
        .map((document) => snapshotFromDocument(this, document)),
    );
  }

  async commitWrites(
    pendingWrites: PendingWrite[],
    transactionId?: string,
  ): Promise<void> {
    if (pendingWrites.length === 0 && !transactionId) {
      return;
    }
    const writes = pendingWrites.map((write) => encodeWrite(this, write));
    await this.request('/documents:commit', {
      method: 'POST',
      body: JSON.stringify({
        writes,
        ...(transactionId ? {transaction: transactionId} : {}),
      }),
    });
  }

  documentName(path: string): string {
    return `${this.databaseRoot}/documents/${path}`;
  }

  referenceFromName(name: string): DocumentReference {
    const marker = '/documents/';
    const index = name.indexOf(marker);
    if (index < 0) {
      throw new Error(`Invalid Firestore document name: ${name}`);
    }
    return new DocumentReference(this, name.slice(index + marker.length));
  }

  private async beginTransaction(): Promise<string> {
    const result = await this.request<{transaction: string}>(
      '/documents:beginTransaction',
      {
        method: 'POST',
        body: JSON.stringify({options: {readWrite: {}}}),
      },
    );
    return result.transaction;
  }

  private async rollback(transactionId: string): Promise<void> {
    try {
      await this.request('/documents:rollback', {
        method: 'POST',
        body: JSON.stringify({transaction: transactionId}),
      });
    } catch {
      // The original operation error is more useful than a rollback failure.
    }
  }

  private async collectDocumentTree(
    documentPath: string,
    names: string[],
  ): Promise<void> {
    let collectionPageToken = '';
    do {
      const collectionPage = await this.request<{
        collectionIds?: string[];
        nextPageToken?: string;
      }>(
        `/documents/${encodeDocumentPath(documentPath)}:listCollectionIds`,
        {
          method: 'POST',
          body: JSON.stringify({
            pageSize: 100,
            ...(collectionPageToken
              ? {pageToken: collectionPageToken}
              : {}),
          }),
        },
      );

      for (const collectionId of collectionPage.collectionIds ?? []) {
        let documentPageToken = '';
        do {
          const tokenQuery = documentPageToken
            ? `&pageToken=${encodeURIComponent(documentPageToken)}`
            : '';
          const page = await this.request<{
            documents?: FirestoreDocument[];
            nextPageToken?: string;
          }>(
            `/documents/${encodeDocumentPath(documentPath)}` +
              `/${encodeURIComponent(collectionId)}?pageSize=100${tokenQuery}`,
          );
          for (const document of page.documents ?? []) {
            const childRef = this.referenceFromName(document.name);
            await this.collectDocumentTree(childRef.path, names);
            names.push(document.name);
          }
          documentPageToken = page.nextPageToken ?? '';
        } while (documentPageToken);
      }

      collectionPageToken = collectionPage.nextPageToken ?? '';
    } while (collectionPageToken);
  }

  private async request<T = unknown>(
    relativePath: string,
    init: RequestInit = {},
  ): Promise<T> {
    const accessToken = await getServiceAccountAccessToken();
    const headers = new Headers(init.headers);
    headers.set('authorization', `Bearer ${accessToken}`);
    if (init.body !== undefined) {
      headers.set('content-type', 'application/json');
    }

    const response = await fetch(
      `https://firestore.googleapis.com/v1/${this.databaseRoot}${relativePath}`,
      {...init, headers},
    );
    if (!response.ok) {
      const body = await response.json().catch(() => ({})) as GoogleApiErrorBody;
      throw new RestFirestoreApiError(
        body.error?.message ?? `Firestore request failed (${response.status}).`,
        response.status,
        body.error?.status,
      );
    }
    if (response.status === 204) {
      return undefined as T;
    }
    return await response.json() as T;
  }
}

let firestoreInstance: RestFirestore | undefined;

export function initializeFirestore(
  _app?: unknown,
  _settings?: unknown,
): RestFirestore {
  firestoreInstance ??= new RestFirestore();
  return firestoreInstance;
}

export function getFirestore(_app?: unknown): RestFirestore {
  return initializeFirestore();
}

function encodeWrite(
  firestore: RestFirestore,
  pending: PendingWrite,
): FirestoreWrite {
  if (pending.kind === 'delete') {
    return {delete: firestore.documentName(pending.ref.path)};
  }

  const {fields, transforms, fieldPaths} = encodeDocumentData(pending.data);
  const write: FirestoreWrite = {
    update: {
      name: firestore.documentName(pending.ref.path),
      fields,
    },
  };

  if (pending.kind === 'update' || pending.merge) {
    write.updateMask = {fieldPaths};
  }
  if (pending.kind === 'update') {
    write.currentDocument = {exists: true};
  }
  if (transforms.length > 0) {
    write.updateTransforms = transforms;
  }
  return write;
}

function encodeDocumentData(data: DocumentData): {
  fields: Record<string, FirestoreValue>;
  transforms: Array<{
    fieldPath: string;
    setToServerValue: 'REQUEST_TIME';
  }>;
  fieldPaths: string[];
} {
  const fields: Record<string, FirestoreValue> = {};
  const transforms: Array<{
    fieldPath: string;
    setToServerValue: 'REQUEST_TIME';
  }> = [];
  const fieldPaths: string[] = [];

  for (const [fieldPath, value] of Object.entries(data)) {
    if (value instanceof FieldValue && value.kind === 'serverTimestamp') {
      transforms.push({fieldPath, setToServerValue: 'REQUEST_TIME'});
      continue;
    }
    fields[fieldPath] = encodeValue(value);
    fieldPaths.push(fieldPath);
  }
  return {fields, transforms, fieldPaths};
}

function encodeValue(value: unknown): FirestoreValue {
  if (value === null || value === undefined) {
    return {nullValue: null};
  }
  if (value instanceof Timestamp) {
    return {timestampValue: value.toISOString()};
  }
  if (value instanceof Date) {
    return {timestampValue: value.toISOString()};
  }
  if (typeof value === 'boolean') {
    return {booleanValue: value};
  }
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? {integerValue: String(value)}
      : {doubleValue: value};
  }
  if (typeof value === 'string') {
    return {stringValue: value};
  }
  if (value instanceof Uint8Array) {
    return {bytesValue: bytesToBase64(value)};
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        ...(value.length > 0 ? {values: value.map(encodeValue)} : {}),
      },
    };
  }
  if (typeof value === 'object') {
    const fields = Object.fromEntries(
      Object.entries(value as DocumentData)
        .map(([key, nestedValue]) => [key, encodeValue(nestedValue)]),
    );
    return {
      mapValue: {
        ...(Object.keys(fields).length > 0 ? {fields} : {}),
      },
    };
  }
  throw new Error(`Unsupported Firestore value type: ${typeof value}`);
}

function decodeValue(value: FirestoreValue): unknown {
  if ('nullValue' in value) {
    return null;
  }
  if ('booleanValue' in value) {
    return value.booleanValue;
  }
  if ('integerValue' in value) {
    return Number(value.integerValue);
  }
  if ('doubleValue' in value) {
    return value.doubleValue;
  }
  if ('timestampValue' in value) {
    return Timestamp.fromDate(new Date(value.timestampValue));
  }
  if ('stringValue' in value) {
    return value.stringValue;
  }
  if ('bytesValue' in value) {
    return value.bytesValue;
  }
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(decodeValue);
  }
  if ('mapValue' in value) {
    return decodeFields(value.mapValue.fields ?? {});
  }
  return undefined;
}

function decodeFields(
  fields: Record<string, FirestoreValue>,
): DocumentData {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function snapshotFromDocument(
  firestore: RestFirestore,
  document: FirestoreDocument,
): DocumentSnapshot {
  return new DocumentSnapshot(
    firestore.referenceFromName(document.name),
    decodeFields(document.fields ?? {}),
  );
}

function fieldFilter(filter: QueryFilter): Record<string, unknown> {
  const operator = {
    '==': 'EQUAL',
    '>=': 'GREATER_THAN_OR_EQUAL',
    'in': 'IN',
  }[filter.operator];
  return {
    fieldFilter: {
      field: {fieldPath: filter.fieldPath},
      op: operator,
      value: encodeValue(filter.value),
    },
  };
}

function isRetryableTransactionError(error: unknown): boolean {
  return error instanceof RestFirestoreApiError &&
    (error.httpStatus === 409 ||
      error.httpStatus === 429 ||
      error.googleStatus === 'ABORTED' ||
      error.googleStatus === 'UNAVAILABLE');
}

async function getServiceAccountAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedAccessToken && now < cachedAccessTokenExpiresAt - 60_000) {
    return cachedAccessToken;
  }

  const clientEmail = requiredEnvironmentValue('FIREBASE_CLIENT_EMAIL');
  const privateKey = requiredEnvironmentValue('FIREBASE_PRIVATE_KEY')
    .replace(/\\n/g, '\n');
  const issuedAt = Math.floor(now / 1000);
  const header = base64UrlJson({alg: 'RS256', typ: 'JWT'});
  const claims = base64UrlJson({
    iss: clientEmail,
    sub: clientEmail,
    aud: oauthTokenUrl,
    scope: firestoreScope,
    iat: issuedAt,
    exp: issuedAt + 3600,
  });
  const unsignedJwt = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemPrivateKeyBytes(privateKey),
    {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'},
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedJwt),
  );
  const assertion = `${unsignedJwt}.${base64UrlBytes(new Uint8Array(signature))}`;

  const response = await fetch(oauthTokenUrl, {
    method: 'POST',
    headers: {'content-type': 'application/x-www-form-urlencoded'},
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const result = await response.json() as {
    access_token?: string;
    expires_in?: number;
    error_description?: string;
  };
  if (!response.ok || !result.access_token) {
    throw new Error(
      result.error_description ??
        `Service account token exchange failed (${response.status}).`,
    );
  }

  cachedAccessToken = result.access_token;
  cachedAccessTokenExpiresAt =
    now + (Number(result.expires_in ?? 3600) * 1000);
  return cachedAccessToken;
}

function pemPrivateKeyBytes(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

function base64UrlJson(value: unknown): string {
  return base64UrlBytes(
    new TextEncoder().encode(JSON.stringify(value)),
  );
}

function base64UrlBytes(value: Uint8Array): string {
  return bytesToBase64(value)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function bytesToBase64(value: Uint8Array): string {
  let binary = '';
  for (let index = 0; index < value.length; index += 1) {
    binary += String.fromCharCode(value[index]);
  }
  return btoa(binary);
}

function requiredEnvironmentValue(name: string): string {
  const processLike = globalThis as typeof globalThis & {
    process?: {env?: Record<string, string | undefined>};
  };
  const value = processLike.process?.env?.[name]?.trim();
  if (!value) {
    throw new Error(`${name} is not configured.`);
  }
  return value;
}

function encodeDocumentPath(path: string): string {
  return path.split('/').map(encodeURIComponent).join('/');
}

function assertSegment(value: string, kind: string): void {
  if (!value || value.includes('/')) {
    throw new Error(`Invalid Firestore ${kind} segment.`);
  }
}
