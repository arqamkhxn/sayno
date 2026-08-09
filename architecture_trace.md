# Architecture Trace — Railway Runtime Ownership

## Finding: There Is ONE Railway Service

There is exactly **one** `railway.json` at the monorepo root. No Dockerfiles. No Nixpacks config. No per-package Railway configs. No multi-service setup.

**Railway runs a single service from this single config file.**

---

## Build Pipeline (Exact)

```
railway.json:5  →  buildCommand: "pnpm install && pnpm run build"
                                   │                │
                                   │                └─ root package.json:16 → "build": "turbo run build"
                                   │                                           │
                                   │                   turbo.json:5-8          │
                                   │                   "build": {              │
                                   │                     "dependsOn": ["^build"],  ← dependencies build FIRST
                                   │                     "outputs": ["dist/**"]    ← Turbo caches dist/ contents
                                   │                   }                       │
                                   │                                           │
                                   │                   Turbo resolves dependency graph from pnpm workspace:
                                   │                   ┌──────────────────────────────────────────┐
                                   │                   │  @sayno-uce/shared           (no deps)   │ ← builds FIRST
                                   │                   │  @sayno-uce/layer1-ingestion (→ shared)  │ ← builds 2nd
                                   │                   │  @sayno-uce/layer2-intelligence (→ shared)│ ← builds 2nd
                                   │                   │  @sayno-uce/semantic-layer  (→ shared)   │ ← builds 2nd
                                   │                   │  @sayno-uce/layer3-recommendation        │ ← builds 3rd
                                   │                   │     (→ shared, layer1, layer2)            │
                                   │                   │  @sayno-uce/functions                    │ ← builds LAST
                                   │                   │     (→ shared, layer1, layer2, layer3)    │
                                   │                   └──────────────────────────────────────────┘
                                   │
                                   └─ pnpm install: creates symlinks in node_modules
```

Each package's `build` script is `tsc --project tsconfig.json`, which compiles:
- `src/**/*.ts` → `dist/**/*.js` (within that package's own directory)

### Where Each Package's Compiled JS Lives

| Package | Source | Compiled Output |
|---|---|---|
| `@sayno-uce/shared` | `packages/shared/src/` | `packages/shared/dist/` |
| `@sayno-uce/layer1-ingestion` | `packages/layer1-ingestion/src/` | `packages/layer1-ingestion/dist/` |
| `@sayno-uce/layer2-intelligence` | `packages/layer2-intelligence/src/` | `packages/layer2-intelligence/dist/` |
| `@sayno-uce/layer3-recommendation` | `packages/layer3-recommendation/src/` | `packages/layer3-recommendation/dist/` |
| `@sayno-uce/semantic-layer` | `packages/semantic-layer/src/` | `packages/semantic-layer/dist/` |
| `@sayno-uce/functions` | `functions/src/` | `functions/dist/` |

**Each package has its OWN `dist/` directory. They do NOT share compiled artifacts.**

---

## Runtime Process (Exact)

```
railway.json:8  →  startCommand: "cd functions && npm start"
                                   │
                   functions/package.json:16 → "start": "node dist/standalone.js"
                                   │
                   Node.js loads: functions/dist/standalone.js
```

**The single process that runs is `node functions/dist/standalone.js`.**

---

## Module Resolution at Runtime

When `functions/dist/standalone.js` does:
```javascript
const { YouTubeAdapter } = require("@sayno-uce/layer1-ingestion");
```

Node.js resolution with pnpm workspace (from `pnpm-lock.yaml:38-40`):
```yaml
'@sayno-uce/layer1-ingestion':
  specifier: workspace:*
  version: link:../packages/layer1-ingestion     ← SYMLINK
```

pnpm creates a symlink:
```
functions/node_modules/@sayno-uce/layer1-ingestion  →  ../../packages/layer1-ingestion
```

Then Node reads `packages/layer1-ingestion/package.json:6`:
```json
"main": "./dist/index.js"
```

Which loads: **`packages/layer1-ingestion/dist/index.js`**

Which re-exports: **`packages/layer1-ingestion/dist/adapters/youtube-adapter.js`**

---

## The Critical Question: Which Compiled JS Runs youtube-adapter?

```
Runtime file: packages/layer1-ingestion/dist/adapters/youtube-adapter.js
Source file:  packages/layer1-ingestion/src/adapters/youtube-adapter.ts
Built by:     packages/layer1-ingestion's own "build" script (tsc)
```

**The `functions` package does NOT compile `youtube-adapter.ts`.** Functions' `tsc` only compiles `functions/src/**/*.ts`.

The `youtube-adapter.js` that executes at runtime is compiled by `@sayno-uce/layer1-ingestion`'s own build step.

---

## Answer to Each Question

### 1. Which Dockerfile is used?
**None.** Railway uses Nixpacks with `buildCommand` from `railway.json`. No Dockerfile exists anywhere in the repo.

### 2. Which workspace/package is built?
**All of them.** `turbo run build` builds every package in dependency order. There is no filtering.

### 3. Does it compile `packages/layer1-ingestion`?
**Yes**, but in its OWN build step. `turbo run build` runs `tsc --project tsconfig.json` inside `packages/layer1-ingestion/`, producing `packages/layer1-ingestion/dist/`.

### 4. Does it share compiled artifacts with functions?
**No.** Each package compiles into its own `dist/` directory. `functions` accesses `layer1-ingestion`'s compiled JS via a pnpm **symlink** in `node_modules`, which points to `packages/layer1-ingestion` (and then `package.json:main` resolves to `./dist/index.js`).

### 5. Which service is actually executing `youtube-adapter.ts`?
**The single Railway service.** The runtime file is `packages/layer1-ingestion/dist/adapters/youtube-adapter.js`, resolved via pnpm symlink from the `functions` process.

---

## ⚠️ CRITICAL IMPLICATION FOR THE DIAGNOSTIC LOGGING

This architecture reveals why the diagnostic change **may not be taking effect**:

### Turbo Cache Problem

`turbo.json` caches `build` outputs by `dist/**`:

```json
"build": {
  "dependsOn": ["^build"],
  "outputs": ["dist/**"]        ← Turbo hashes inputs and skips build if unchanged
}
```

Turbo determines if a package needs rebuilding by hashing its **inputs**. The inputs for `@sayno-uce/layer1-ingestion` are:
- All files in `packages/layer1-ingestion/src/`
- Its dependencies' outputs (i.e., `@sayno-uce/shared/dist/`)

**If Turbo's remote cache (or local `.turbo/` cache) from a previous Railway build still has a cached `dist/` for `layer1-ingestion`, and Turbo considers the inputs unchanged, it will SKIP recompilation and use the cached (OLD) `dist/`.**

However: Railway uses Nixpacks, which builds in a fresh container. The `.turbo/` directory is in `.gitignore` and would not be in the git clone. **Unless Railway has a Nixpacks build cache layer** that persists `node_modules/` or `.turbo/` between deploys, the Turbo cache should be cold on each deploy.

This needs verification:
- If Railway persists the Nixpacks build cache, the old `layer1-ingestion/dist/` may be served from Turbo cache
- If Railway builds fully fresh each time, the diagnostic code SHOULD be compiled

### How to verify
Check the Railway build logs for the `layer1-ingestion` build step. You should see either:
- `@sayno-uce/layer1-ingestion:build: cache hit` → **Turbo used cached old JS — your diagnostic is NOT deployed**
- `@sayno-uce/layer1-ingestion:build: ...tsc output...` → Package was rebuilt with your changes
