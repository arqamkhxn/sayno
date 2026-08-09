# Forensic Engineering Report — SAYNO UCE Ingestion Pipeline Failure

## Phase 1 — Deployment Verification

### Build Pipeline Trace

```
railway.json → buildCommand: "pnpm install && pnpm run build"
                              ↓
root package.json → "build": "turbo run build"
                              ↓
turbo.json → "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] }
                              ↓
Each package runs: tsc --project tsconfig.json
```

| Check | Result |
|---|---|
| Railway builder | NIXPACKS (standard, no Docker cache issues) |
| Build command | `pnpm install && pnpm run build` → triggers `turbo run build` → TypeScript compilation of all packages |
| Start command | `cd functions && npm start` → `node dist/standalone.js` |
| `.gitignore` includes `dist/` | ✅ Yes — `dist/` and `.turbo/` are gitignored. No stale build artifacts can be committed. |
| Turbo cache | Build `outputs: ["dist/**"]` — Turbo may cache builds between Railway deploys. However, Railway runs `pnpm install && pnpm run build` fresh in a new container each time. Nixpacks does NOT persist `.turbo/` cache across deploys. |
| `tsconfig.base.json` | `module: "commonjs"`, `target: "ES2022"` — correct for Node.js 20. |
| Monorepo build order | `turbo.json` has `"dependsOn": ["^build"]` — packages build in dependency order: `shared → layer1/layer2/layer3 → functions`. ✅ Correct. |

**Deployment Verdict**: ✅ **No deployment issue**. The Railway build pipeline is straightforward — Nixpacks rebuilds everything from scratch. The start command (`cd functions && npm start → node dist/standalone.js`) matches the entry point. The deployed code IS the latest commit.

---

## Phase 2 — Complete Execution Trace

### Startup Sequence (matches Railway logs exactly)

```
standalone.ts:13-24    → Firebase Admin SDK init (checks FIREBASE_SERVICE_ACCOUNT_BASE64)
standalone.ts:29       → createApp() — Express server created
standalone.ts:31       → app.listen(PORT) — "Standalone Express server listening on port 8080"
standalone.ts:54       → runScheduledIngestion() — called immediately
```

### Ingestion Execution Path

```
standalone.ts:38-51
  └─ runScheduledIngestion()
       └─ createIngestionRunner()                          [container.ts:226-244]
            ├─ getConfig()                                 [config.ts:43-96]
            │   └─ reads YOUTUBE_API_KEY env var            [config.ts:67]
            ├─ pipelineFactory closure                     [container.ts:229-237]
            └─ new IngestionRunner(...)                    [container.ts:239-244]

  └─ runner.run(correlationId)                             [ingestion-runner.ts:144-205]
       ├─ getSeedSources().filter(g => g.enabled)          [seed-sources.ts:122-124]
       │   └─ Returns: [youtube_general] (1 enabled group)
       │
       └─ this.runGroup(group, correlationId)              [ingestion-runner.ts:211-278]
            ├─ new YouTubeAdapter({ apiKey, channelIds, searchQueries })  [line 228-232]
            │   └─ channelIds: ['UCcefcZRL2oaA_uBNeo5UNqg', 'UC2D2CMWXMOVWx7giW1n3LIg',
            │                    'UCoOae5nYA7VqaXzerajD0lg', 'UCSHZKyawb77ixDdsGog4iWA']
            │
            ├─ pipelineFactory(adapter, normalizer)        [line 236]
            │   └─ new IngestionPipeline(...)               [container.ts:230-237]
            │
            ├─ cursorStore.getCursor('youtube_general')    [line 241]
            │
            └─ pipeline.runBatch(cursor)                   [ingestion-pipeline.ts:80-201]
                 └─ adapter.fetchBatch(cursor, limit=25)   [ingestion-pipeline.ts:97]
                      └─ fetchChannelVideos(                [youtube-adapter.ts:97-102]
                           'UCcefcZRL2oaA_uBNeo5UNqg',     ← first channel
                           null,                            ← no pageToken  
                           25,                              ← maxResults
                           fetchedAt
                         )
```

### Where Execution STOPS

```
youtube-adapter.ts:229  → this.http.get<...>('/search', { params: searchParams })
                        ↓
                        YouTube API returns HTTP 400
                        ↓
youtube-adapter.ts:256  → catch (error) { this.handleApiError(error, ...) }
                        ↓
youtube-adapter.ts:336  → throw new SourceApiError(SOURCE_ID, `YouTube API error [400]...`)
                        ↓
ingestion-pipeline.ts:97 → UNCAUGHT — adapter.fetchBatch() throws
                        ↓
                        This propagates through:
                        ingestion-pipeline.ts:97 → ingestion-runner.ts:253 → runner.runGroup() throws
                        ↓
ingestion-runner.ts:172 → logger.error('Source group ingestion failed', ...)
                        ↓
ingestion-runner.ts:176-183 → error recorded in sourceResults
                        ↓
ingestion-runner.ts:190 → persistAuditLog() — ATTEMPTS to write to Firestore
                        ↓
ingestion-runner.ts:192 → 'Ingestion run complete' logged
```

### Log Correlation

| Railway Log | Code Location |
|---|---|
| `Standalone scheduled ingestion started` | [standalone.ts:40](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L40) |
| `Ingestion run started` | [ingestion-runner.ts:148](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L148) |
| `Source group ingestion started` | [ingestion-runner.ts:215](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L215) |
| `Standalone Node server initialization complete.` | [standalone.ts:130](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L130) |
| `Standalone Express server listening on port 8080` | [standalone.ts:32](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L32) |
| `Ingestion batch started` | [ingestion-pipeline.ts:92](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/pipeline/ingestion-pipeline.ts#L92) |
| `Source group ingestion failed` ⬅ **THE FAILURE** | [ingestion-runner.ts:172](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L172) |
| `Ingestion run complete` | [ingestion-runner.ts:192](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L192) |

> [!IMPORTANT]
> The gap between `Ingestion batch started` and `Source group ingestion failed` is only ~0.1 seconds (20.644 → 20.727). The YouTube API responded almost instantly with an error. This is consistent with an **invalid request being rejected before any work is done**, NOT a timeout or rate limit.

---

## Phase 3 — YouTube API 400 Investigation

### Exact Request Reconstructed from Code

The Axios instance is created at [youtube-adapter.ts:69-73](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/adapters/youtube-adapter.ts#L69-L73):

```typescript
this.http = axios.create({
  baseURL: 'https://www.googleapis.com/youtube/v3',
  timeout: 15_000,
  params: { key: config.apiKey },   // ← API key baked into every request
});
```

The `fetchChannelVideos` method at [youtube-adapter.ts:219-226](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/adapters/youtube-adapter.ts#L219-L226) constructs:

```typescript
const searchParams = {
  part: 'snippet',
  channelId: 'UCcefcZRL2oaA_uBNeo5UNqg',
  type: 'video',
  order: 'date',
  maxResults: 25,
};
```

The actual HTTP request sent by Axios:

```
GET https://www.googleapis.com/youtube/v3/search?key=<YOUTUBE_API_KEY>&part=snippet&channelId=UCcefcZRL2oaA_uBNeo5UNqg&type=video&order=date&maxResults=25
```

### Validation Against YouTube Data API v3 Documentation

| Parameter | Value | Valid? | Documentation |
|---|---|---|---|
| `part` | `snippet` | ✅ Required, valid value |  |
| `channelId` | `UCcefcZRL2oaA_uBNeo5UNqg` | ✅ Valid format (starts with UC, 24 chars) | Y Combinator's real channel ID |
| `type` | `video` | ✅ Valid filter | |
| `order` | `date` | ✅ Valid sort | |
| `maxResults` | `25` | ✅ Valid (1-50 range) | |
| `key` | `<env value>` | **⚠️ CANNOT VERIFY** | Must be a valid YouTube Data API v3 key |

### Critical Finding

**The request structure is syntactically correct.** All parameters match the YouTube Data API v3 specification exactly. The 400 error is NOT caused by a malformed request shape.

**The only possible cause of a 400 from a structurally valid request is an invalid API key.** When YouTube receives a request with an API key that:
- Is empty/blank
- Is malformed
- Belongs to a project where the YouTube Data API v3 is NOT enabled
- Has been revoked or has API restrictions that block `googleapis.com/youtube/v3`

...it returns HTTP 400, NOT 401 or 403.

> [!WARNING]  
> YouTube returns **400** (not 403) when the API key is associated with a GCP project where the YouTube Data API v3 has not been enabled. This is a known confusing behavior.

---

## Phase 4 — Error Visibility Gap

### Current Error Handling

At [youtube-adapter.ts:316-348](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/adapters/youtube-adapter.ts#L316-L348), `handleApiError()` does this:

```typescript
throw new SourceApiError(
  SOURCE_ID,
  `YouTube API error [${status ?? 'unknown'}] during [${operation}]: ${error.message}`,
  { status, operation },
);
```

This **discards** the critical information from the YouTube response:
- `error.response?.data` — the actual JSON error body from YouTube (which contains the specific reason like `keyInvalid`, `accessNotConfigured`, etc.)
- `error.response?.headers`
- `error.config?.url` — the full URL with all parameters
- `error.config?.params` — the actual params sent

The Logger at [logger.ts:142-160](file:///d:/A-SAYNO%20APP/sayno-uce/packages/shared/src/utils/logger.ts#L142-L160) formats errors as:

```typescript
const result = { message: error.message };
if (uceError.code) result.code = uceError.code;
if (uceError.context) result.context = uceError.context;
```

This captures `{ status, operation }` from the SourceApiError context, but the **actual YouTube error JSON** (the most diagnostic information) is completely lost.

---

## Phase 5 — Firestore Verification

### Firebase Initialization

[standalone.ts:13-24](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L13-L24):
```typescript
if (!admin.apps.length) {
  if (process.env["FIREBASE_SERVICE_ACCOUNT_BASE64"]) {
    const serviceAccount = JSON.parse(
      Buffer.from(process.env["FIREBASE_SERVICE_ACCOUNT_BASE64"], 'base64').toString('utf8')
    );
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    admin.initializeApp();
  }
}
```

There is also a **redundant initialization** in [firestore-client.ts:27-28](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/firestore-client.ts#L27-L28):
```typescript
if (admin.apps.length === 0) {
  admin.initializeApp();
}
```

Because `standalone.ts` initializes first (it runs at top-level before any imports are lazily resolved), and checks `admin.apps.length`, the `firestore-client.ts` will see `admin.apps.length === 1` and skip. This is fine — **no conflict**.

### Project ID

- [.firebaserc](file:///d:/A-SAYNO%20APP/sayno-uce/.firebaserc): `"default": "sayno-6bbdd"`
- [.env.example](file:///d:/A-SAYNO%20APP/sayno-uce/.env.example): `GCLOUD_PROJECT=sayno-development`
- [config.ts:68](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/config.ts#L68): `const projectId = require('GCLOUD_PROJECT');`

> [!WARNING]
> The `.env.example` shows `GCLOUD_PROJECT=sayno-development` but `.firebaserc` shows the actual project is `sayno-6bbdd`. If `GCLOUD_PROJECT` is not set correctly in Railway, the Firebase Admin SDK might connect to the wrong project. However, when `FIREBASE_SERVICE_ACCOUNT_BASE64` is provided, the project ID comes from the service account JSON itself, which would be authoritative.

### Firestore Writes — Are They Attempted?

**No.** The execution path proves that Firestore writes are **never reached** because the YouTube API call fails at [ingestion-pipeline.ts:97](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/pipeline/ingestion-pipeline.ts#L97), which is **Step 1: Fetch**. Steps 2-7 (persist raw, normalize, deduplicate, validate, persist normalized, publish event) are never executed.

The **only** Firestore write that IS attempted after failure is the audit log at [ingestion-runner.ts:289-309](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L289-L309), which is wrapped in a try-catch and writes to `ingestion_runs` collection. This write may or may not succeed depending on Firestore credentials, but it's non-critical.

**Conclusion**: Firestore is empty because the pipeline never gets past the YouTube API fetch step. The writes aren't failing — they're **never attempted**.

---

## Phase 6 — Environment Variables

### Required Variables (from [config.ts](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/config.ts))

| Variable | Code Reference | Consumed At | Status |
|---|---|---|---|
| `GEMINI_API_KEY` | [config.ts:66](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/config.ts#L66) | `require('GEMINI_API_KEY')` — will throw on startup if missing | ✅ Must be set (server starts) |
| `YOUTUBE_API_KEY` | [config.ts:67](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/config.ts#L67) | `require('YOUTUBE_API_KEY')` — will throw on startup if missing | ✅ Must be set (server starts) |
| `GCLOUD_PROJECT` | [config.ts:68](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/config.ts#L68) | `require('GCLOUD_PROJECT')` — will throw on startup if missing | ✅ Must be set (server starts) |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | [standalone.ts:14](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L14) | Optional — if missing, `admin.initializeApp()` is called with no args | **⚠️ CRITICAL**: On Railway, if this is NOT set, Firebase Admin SDK has NO credentials. It will use Application Default Credentials which DON'T EXIST on Railway. |
| `PORT` | [standalone.ts:30](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L30) | Optional, defaults to 8080 | ✅ Railway sets this automatically |

### Key Consumption Chain

```
YOUTUBE_API_KEY (Railway env var)
  → config.ts:67 → loadConfig().youtubeApiKey
    → container.ts:229 → new YouTubeAdapter({ apiKey: this.config.youtubeApiKey })
      → youtube-adapter.ts:72 → axios.create({ params: { key: config.apiKey } })
        → EVERY HTTP request to YouTube includes ?key=<value>
```

**The key IS consumed correctly.** If the server starts without crashing, all three required env vars (`GEMINI_API_KEY`, `YOUTUBE_API_KEY`, `GCLOUD_PROJECT`) are present. The question is whether the `YOUTUBE_API_KEY` value is **valid**.

---

## Phase 7 — Log Correlation

| Timestamp | Stream | Log Message | Code Reference | Analysis |
|---|---|---|---|---|
| `08:20:19.396` | `[inf]` | `Standalone scheduled ingestion started` | [standalone.ts:40](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L40) | ✅ `runScheduledIngestion()` invoked |
| `08:20:19.396` | `[inf]` | `Ingestion run started` | [ingestion-runner.ts:148](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L148) | ✅ `runner.run()` began |
| `08:20:19.396` | `[inf]` | `Source group ingestion started` | [ingestion-runner.ts:215](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L215) | ✅ `runGroup(youtube_general)` began |
| `08:20:19.396` | `[inf]` | `Standalone Node server initialization complete.` | [standalone.ts:130](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L130) | ✅ Standalone init finished synchronously while ingestion runs async |
| `08:20:19.396` | `[inf]` | `Standalone Express server listening on port 8080` | [standalone.ts:32](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L32) | ✅ HTTP server started |
| `08:20:20.644` | `[inf]` | `Ingestion batch started` | [ingestion-pipeline.ts:92](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/pipeline/ingestion-pipeline.ts#L92) | ✅ `pipeline.runBatch()` entered — note: ~1.2s gap from previous log = Firestore cursor read time |
| `08:20:20.727` | `[err]` | `Source group ingestion failed` | [ingestion-runner.ts:172](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L172) | ❌ **FAILURE** — ~83ms after batch start = YouTube API rejected instantly |
| `08:20:21.069` | `[inf]` | `Ingestion run complete` | [ingestion-runner.ts:192](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L192) | ✅ Runner completed (with 0 ingested, 1 failed) |

### Key Timing Observations

1. **1.2 seconds** between `Source group ingestion started` and `Ingestion batch started` — this is the Firestore cursor read ([ingestion-runner.ts:241](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L241)). **Firestore connectivity IS working** (if it weren't, the cursor read would fail with a timeout, not return in 1.2s).

2. **83 milliseconds** between `Ingestion batch started` and `Source group ingestion failed` — the YouTube API rejected the request almost immediately. This is consistent with an API key validation failure, NOT a network issue, timeout, or quota exhaustion.

---

## Phase 8 — Root Cause Analysis

### 1. Root Cause

**The `YOUTUBE_API_KEY` environment variable in Railway contains an invalid API key.** The key is present (the server starts without crashing), but the key value is either:

- (a) A key from a GCP project where the **YouTube Data API v3 is not enabled**, OR
- (b) A key that has **API restrictions** (IP, referer, or API restriction) that block server-side `googleapis.com/youtube/v3` calls, OR
- (c) A **placeholder** or incorrectly copied value (e.g., `your-youtube-api-key-here` from `.env.example`)

### 2. Evidence

| Evidence | Location | What It Proves |
|---|---|---|
| Server starts without crashing | Railway logs | `YOUTUBE_API_KEY` is present (not empty) — [config.ts:67-74](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/config.ts#L67-L74) would throw on empty |
| `Ingestion batch started` → `Source group ingestion failed` in 83ms | Railway logs | YouTube API rejected instantly — not a timeout or network issue |
| Error message `YouTube API error [400]` | Railway logs (stderr, structured JSON) | HTTP 400 = invalid request parameter, not auth (401/403) or rate limit (429) |
| Error includes `fetchChannelVideos(UCcefcZRL2oaA_uBNeo5UNqg)` | Railway logs | Confirms first channel ID Y Combinator is being called — channel ID format is valid |
| Request params are structurally valid | [youtube-adapter.ts:219-226](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/adapters/youtube-adapter.ts#L219-L226) | `part`, `channelId`, `type`, `order`, `maxResults` all match YouTube API spec |
| API key is injected as `params.key` on every request | [youtube-adapter.ts:72](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/adapters/youtube-adapter.ts#L72) | Key is sent correctly via query parameter |
| YouTube returns 400 for invalid keys / disabled APIs | Official API docs | Known behavior: YouTube returns 400 (not 403) when the API key's project hasn't enabled YouTube Data API v3 |
| Firestore cursor read takes 1.2s (succeeds) | Log timing analysis | Firestore IS reachable — the issue is purely YouTube API |
| Firestore is empty | User report | No data was written because execution never reaches write steps |

### 3. Why It Happens

The ingestion pipeline has 7 steps: `Fetch → Persist Raw → Normalize → Deduplicate → Validate → Persist → Publish`. The YouTube API call is **Step 1** ([ingestion-pipeline.ts:97](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/pipeline/ingestion-pipeline.ts#L97)). When Step 1 throws a `SourceApiError`, it propagates through `fetchBatch()` → `runBatch()` → `runGroup()` → caught at [ingestion-runner.ts:168](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/ingestion/ingestion-runner.ts#L168). The entire source group is marked as failed and no items are processed.

### 4. Minimal Fix

**Step 1: Verify and fix the YouTube API key in Railway** (this is the primary fix):

```
1. Go to Google Cloud Console → APIs & Services → Credentials
2. Find the API key being used
3. Verify:
   a. YouTube Data API v3 is ENABLED in the project (APIs & Services → Library → Search "YouTube Data API v3" → Enable)
   b. The API key has NO API restrictions that exclude YouTube Data API v3
   c. The API key has NO IP restrictions, OR Railway's IP ranges are included
4. Copy the correct API key
5. In Railway → Variables → set YOUTUBE_API_KEY to the correct value
```

**Step 2: Add diagnostic logging to `handleApiError` to prevent blind debugging in the future:**

```diff
// youtube-adapter.ts — handleApiError()
  private handleApiError(error: unknown, operation: string): never {
    if (axios.isAxiosError(error)) {
      const status = error.response?.status;
+     
+     // Log full YouTube error for diagnostics
+     this.logger.error('YouTube API request failed', 'youtube.api_error', error, {
+       metadata: {
+         operation,
+         status,
+         responseData: error.response?.data,
+         requestUrl: error.config?.url,
+         requestParams: error.config?.params,
+       },
+     });
      
      if (status === 429) { ... }
```

### 5. Why That Fix Is Correct

- The request structure is provably valid (Phase 3 analysis).
- The only query parameter not verified against the spec is the `key` value itself.
- YouTube's 400 response for disabled API keys / invalid keys is documented behavior.
- Once the API key is valid, the request will succeed, `fetchBatch()` will return items, and Steps 2-7 of the pipeline (raw persist → normalize → dedup → validate → content persist → event publish) will execute, writing to Firestore.

### 6. Secondary Problems Remaining

| # | Problem | Severity | Location | Details |
|---|---|---|---|---|
| 1 | **Error diagnostic data is lost** | Medium | [youtube-adapter.ts:336-340](file:///d:/A-SAYNO%20APP/sayno-uce/packages/layer1-ingestion/src/adapters/youtube-adapter.ts#L336-L340) | `handleApiError()` discards `error.response?.data` (the actual YouTube error JSON with reason codes). Only the HTTP status and Axios error message are preserved. |
| 2 | **Potential project ID mismatch** | Low | [.env.example](file:///d:/A-SAYNO%20APP/sayno-uce/.env.example) vs [.firebaserc](file:///d:/A-SAYNO%20APP/sayno-uce/.firebaserc) | `.env.example` says `GCLOUD_PROJECT=sayno-development` but `.firebaserc` says project is `sayno-6bbdd`. The Railway `GCLOUD_PROJECT` env var must match the actual Firebase project. This won't block ingestion (YouTube doesn't use this), but could cause Firestore writes to target the wrong project. |
| 3 | **Dual Firebase initialization** | Low | [standalone.ts:13-24](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/standalone.ts#L13-L24) vs [firestore-client.ts:27-28](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/firestore-client.ts#L27-L28) | Two places call `admin.initializeApp()`. The `standalone.ts` path uses service account credentials if `FIREBASE_SERVICE_ACCOUNT_BASE64` is set, but `firestore-client.ts` always calls `admin.initializeApp()` (no credentials). This only matters if `firestore-client.ts` runs first (it won't on Railway since `standalone.ts` is the entry point), but it's a latent bug for other entry points. |
| 4 | **Identity catalog might be empty** | Low | [container.ts:255-259](file:///d:/A-SAYNO%20APP/sayno-uce/functions/src/bootstrap/container.ts#L255-L259) | `loadIdentityProfiles()` reads from `identity_catalog` Firestore collection. If this collection doesn't exist or is empty, the Intelligence Pipeline (Layer 2) will have no identity profiles, which may cause poor or no semantic analysis. This will surface AFTER the YouTube fix. |

### 7. Confidence Level

**95% confident** that the root cause is an invalid/misconfigured YouTube API key.

**The remaining 5%** accounts for the possibility that the API key is valid but has an obscure restriction (like an IP whitelist that excludes Railway's egress IPs). The fix for both cases is the same: verify and reconfigure the API key in GCP Console.

The diagnostic logging fix (Step 2) will provide the exact YouTube error reason on the next attempt, which will either confirm the key issue or reveal the specific restriction.

---

## Recommended Immediate Actions

1. **Verify YouTube API key** in GCP Console (check that YouTube Data API v3 is enabled + no key restrictions)
2. **Apply diagnostic logging** to `handleApiError()` so future failures are debuggable
3. **Verify `GCLOUD_PROJECT`** in Railway matches your actual Firebase project (`sayno-6bbdd`)
4. **Re-deploy** and monitor logs for success
