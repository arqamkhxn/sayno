# SAYNO Universal Content Engine (UCE)
## Engineering Implementation Specification

**Version:** 1.0  
**Status:** Draft — Pending Founder Review  
**Author:** Lead Software Architect  
**Date:** 2026-07-18  
**Source of Truth:** `uce_architecture.md` (v2.0)  

---

> [!IMPORTANT]
> This document translates the frozen UCE Architecture & Software Design Specification (SDS) into production-grade implementation guidance. The SDS defines *what* and *why*. This document defines *how*, *where*, and *when*. If any statement in this document conflicts with the SDS, the SDS wins.

---

## Table of Contents

1. [Engineering Principles](#1-engineering-principles)
2. [Repository Organization](#2-repository-organization)
3. [Service Boundaries & Module Breakdown](#3-service-boundaries--module-breakdown)
4. [Database Implementation](#4-database-implementation)
5. [Event System Implementation](#5-event-system-implementation)
6. [Layer 1 — Ingestion Implementation](#6-layer-1--ingestion-implementation)
7. [Layer 2 — Intelligence Pipeline Implementation](#7-layer-2--intelligence-pipeline-implementation)
8. [Knowledge Graph Implementation](#8-knowledge-graph-implementation)
9. [Layer 3 — Recommendation Engine Implementation](#9-layer-3--recommendation-engine-implementation)
10. [Learning Path Implementation](#10-learning-path-implementation)
11. [Feed API Specification](#11-feed-api-specification)
12. [Authentication & Authorization](#12-authentication--authorization)
13. [Configuration Management](#13-configuration-management)
14. [Caching Strategy](#14-caching-strategy)
15. [Logging & Monitoring](#15-logging--monitoring)
16. [Error Handling & Retry Strategy](#16-error-handling--retry-strategy)
17. [Testing Strategy](#17-testing-strategy)
18. [CI/CD Pipeline](#18-cicd-pipeline)
19. [Deployment Strategy](#19-deployment-strategy)
20. [Development Roadmap & Sprint Plan](#20-development-roadmap--sprint-plan)
21. [Risk Register](#21-risk-register)
22. [Future Enhancements](#22-future-enhancements)
23. [Implementation Review Notes](#23-implementation-review-notes)

---

## 1. Engineering Principles

These principles govern all implementation decisions. They are derived directly from the SDS design philosophy (SDS §1.3) and augmented with operational guidance.

| # | Principle | Implementation Rule |
|---|---|---|
| EP-1 | **Layer Sovereignty** | No function call, database query, or import statement may cross layer boundaries. All cross-layer communication is via events. Violation is a merge-blocking defect. |
| EP-2 | **Adapter-First** | Every external dependency (AI API, YouTube API, database, cache, message queue) is accessed exclusively through an adapter interface. Direct SDK calls in business logic are forbidden. |
| EP-3 | **Idempotent Everything** | Every pipeline stage, event handler, and database write must be safely re-executable. Use UPSERT semantics, `eventId`-based deduplication, and version-aware writes. |
| EP-4 | **Configuration over Code** | Weights, thresholds, schedules, feature flags, and catalog data are stored in configuration files or environment variables — never hardcoded. Changing a weight must never require a code deployment. |
| EP-5 | **Process Once, Serve Forever** | AI is invoked exactly once per content item at ingestion time. The hot path (feed serving) must never call an AI provider. Zero LLM calls in the feed generation path. |
| EP-6 | **Graceful Degradation** | Every component must define its degraded-mode behavior. If Layer 2 is down, Layer 1 continues. If the AI provider is down, Layer 2 queues work. If the feed cache is empty, the client falls back to `SeedContentCatalogProvider`. |
| EP-7 | **Cost Awareness** | Every AI call, database query, and network request has a cost. Log cost estimates. Alert on budget threshold breaches. Prefer batch over individual calls. |
| EP-8 | **Observability by Default** | Every significant operation emits structured logs and metrics. No silent failures. No `catch (e) {}` blocks. |

---

## 2. Repository Organization

### 2.1 Monorepo Strategy (Seed Tier)

The UCE backend is implemented as a **TypeScript monorepo** using Node.js. TypeScript is chosen because:
- Firebase Cloud Functions natively supports Node.js/TypeScript.
- The Seed tier runs entirely on Firebase infrastructure (SDS §20.2).
- Type safety reduces integration errors across modules.
- The same codebase can be deployed to Cloud Run at Growth tier without rewriting.

```
sayno-uce/
├── package.json                     # Root workspace config
├── tsconfig.base.json               # Shared TypeScript config
├── turbo.json                       # Turborepo build orchestration
├── .env.example                     # Environment variable template
├── .env.seed                        # Seed tier defaults (not committed)
├── .env.growth                      # Growth tier defaults (not committed)
│
├── packages/
│   ├── shared/                      # Cross-package types, utilities
│   │   ├── src/
│   │   │   ├── types/
│   │   │   │   ├── universal-content.ts      # UniversalContentItem
│   │   │   │   ├── intelligence-record.ts    # IntelligenceRecord
│   │   │   │   ├── events.ts                 # Event envelope + payload types
│   │   │   │   ├── identity-ontology.ts      # Ontology entity types
│   │   │   │   ├── learning-path.ts          # LearningPath, PathStep
│   │   │   │   ├── feed.ts                   # ContentCollection, ContentItem (API shapes)
│   │   │   │   └── model-registry.ts         # ModelMetadata
│   │   │   ├── errors/
│   │   │   │   └── uce-errors.ts             # Typed error classes
│   │   │   ├── validation/
│   │   │   │   ├── schema-validator.ts       # JSON schema validation
│   │   │   │   └── schemas/                  # JSON Schema definitions
│   │   │   └── utils/
│   │   │       ├── fingerprint.ts            # SHA-256 + SimHash
│   │   │       ├── idempotency.ts            # Idempotency key helpers
│   │   │       └── logger.ts                 # Structured logging wrapper
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── layer1-ingestion/            # Content Ingestion
│   │   ├── src/
│   │   │   ├── adapters/
│   │   │   │   ├── content-source-adapter.ts       # Interface
│   │   │   │   ├── youtube-adapter.ts              # YouTube Data API v3
│   │   │   │   ├── podcast-rss-adapter.ts          # RSS feed parser
│   │   │   │   └── article-adapter.ts              # Article/blog fetcher
│   │   │   ├── normalizers/
│   │   │   │   ├── source-normalizer.ts            # Interface
│   │   │   │   ├── youtube-normalizer.ts
│   │   │   │   ├── podcast-normalizer.ts
│   │   │   │   └── article-normalizer.ts
│   │   │   ├── pipeline/
│   │   │   │   ├── ingestion-pipeline.ts           # Orchestrates fetch → normalize → dedup → validate → persist → publish
│   │   │   │   ├── deduplication-engine.ts         # Exact + fuzzy dedup
│   │   │   │   └── schema-validator.ts             # Validates against Universal Content Schema
│   │   │   ├── lifecycle/
│   │   │   │   ├── verification-pipeline.ts        # Scheduled content verification (§13.2)
│   │   │   │   └── dedup-rerun-worker.ts           # Weekly SimHash re-scan (§13.3)
│   │   │   ├── storage/
│   │   │   │   ├── raw-content-store.ts            # Interface + GCS implementation
│   │   │   │   └── normalized-content-store.ts     # Interface + Firestore/Postgres implementation
│   │   │   ├── scheduling/
│   │   │   │   └── ingestion-scheduler.ts          # Cron + on-demand trigger logic
│   │   │   └── index.ts                            # Cloud Function entry points
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── layer2-intelligence/         # Content Intelligence
│   │   ├── src/
│   │   │   ├── adapters/
│   │   │   │   ├── ai-analysis-adapter.ts          # Interface
│   │   │   │   ├── gemini-adapter.ts               # Google Gemini implementation
│   │   │   │   ├── openai-adapter.ts               # OpenAI implementation
│   │   │   │   ├── claude-adapter.ts               # Anthropic Claude implementation
│   │   │   │   ├── safety-adapter.ts               # Interface
│   │   │   │   ├── rule-based-safety.ts            # Tier 1: Deterministic rules
│   │   │   │   ├── transcript-adapter.ts           # Interface
│   │   │   │   └── youtube-transcript-adapter.ts   # YouTube captions API
│   │   │   ├── pipeline/
│   │   │   │   ├── analysis-pipeline.ts            # 5-stage orchestrator
│   │   │   │   ├── stage1-metadata-extraction.ts
│   │   │   │   ├── stage2-ai-analysis.ts
│   │   │   │   ├── stage3-trust-credibility.ts
│   │   │   │   ├── stage4-identity-mapping.ts
│   │   │   │   └── stage5-quality-scoring.ts
│   │   │   ├── prompts/
│   │   │   │   ├── analysis-prompt.ts              # Prompt template + builder
│   │   │   │   └── prompt-schemas.ts               # Expected JSON output schema
│   │   │   ├── trust/
│   │   │   │   ├── trust-score-calculator.ts       # Trust(Author) formula
│   │   │   │   └── blocklist-manager.ts            # Channel/domain blocklists
│   │   │   ├── storage/
│   │   │   │   └── intelligence-store.ts           # Interface + Firestore/Postgres implementation
│   │   │   ├── governance/
│   │   │   │   ├── model-registry.ts               # Model metadata CRUD
│   │   │   │   ├── shadow-evaluator.ts             # Shadow deployment logic
│   │   │   │   └── model-tier-router.ts            # Routes content to appropriate model tier
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── layer3-recommendation/       # Recommendation Engine
│   │   ├── src/
│   │   │   ├── feed/
│   │   │   │   ├── feed-generator.ts               # Full pipeline orchestrator
│   │   │   │   ├── candidate-selector.ts           # Phase 1: Query intelligence store
│   │   │   │   ├── ranking-engine.ts               # Phase 2: PRS computation
│   │   │   │   ├── diversity-enforcer.ts           # Phase 3: Greedy re-ranking
│   │   │   │   ├── collection-assembler.ts         # Phase 4: Group into collections
│   │   │   │   └── feed-cache-manager.ts           # Phase 5: Cache write/read
│   │   │   ├── scoring/
│   │   │   │   ├── prs-calculator.ts               # Personalized Relevance Score
│   │   │   │   ├── identity-relevance.ts           # α factor
│   │   │   │   ├── goal-relevance.ts               # β factor
│   │   │   │   ├── difficulty-match.ts             # γ factor
│   │   │   │   ├── freshness-boost.ts              # δ factor
│   │   │   │   ├── exploration-bonus.ts            # ζ factor
│   │   │   │   ├── format-preference.ts            # η factor
│   │   │   │   ├── completion-likelihood.ts        # θ factor
│   │   │   │   ├── path-continuity.ts              # ι factor (v2)
│   │   │   │   └── repetition-penalty.ts           # κ factor (v2)
│   │   │   ├── feedback/
│   │   │   │   ├── feedback-processor.ts           # Processes content.consumed, content.dismissed, content.saved
│   │   │   │   ├── implicit-signal-tracker.ts      # Tier 1 signals
│   │   │   │   └── identity-evolution.ts           # Drift detection, goal saturation
│   │   │   ├── memory/
│   │   │   │   ├── recommendation-memory.ts        # Anti-fatigue, dismissal propagation
│   │   │   │   └── recommendation-memory-store.ts  # Interface + Firestore/Postgres
│   │   │   ├── user/
│   │   │   │   ├── user-context-loader.ts          # Loads profile + history + preferences
│   │   │   │   ├── user-profile-store.ts           # Interface + Firestore
│   │   │   │   └── user-history-store.ts           # Interface + Firestore/ClickHouse
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── semantic-layer/              # Knowledge Graph & Ontology
│   │   ├── src/
│   │   │   ├── ontology/
│   │   │   │   ├── ontology-schema.ts              # Entity type definitions
│   │   │   │   ├── ontology-loader.ts              # Loads ontology from config
│   │   │   │   └── ontology-validator.ts           # DAG validation, cycle detection
│   │   │   ├── graph/
│   │   │   │   ├── graph-store.ts                  # Interface
│   │   │   │   ├── firestore-graph-store.ts        # Seed tier: Firestore adjacency collections
│   │   │   │   ├── postgres-graph-store.ts         # Growth tier: Recursive CTE queries
│   │   │   │   ├── graph-enrichment-pipeline.ts    # NER extraction + edge writing
│   │   │   │   └── graph-query-engine.ts           # Traversals, PageRank, path finding
│   │   │   ├── learning-paths/
│   │   │   │   ├── learning-path-engine.ts         # Topological sort, path generation
│   │   │   │   ├── path-rerouter.ts                # Dynamic rerouting on content retirement
│   │   │   │   └── learning-path-store.ts          # Interface + Firestore/Postgres
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── api/                         # Feed API (HTTP surface)
│       ├── src/
│       │   ├── routes/
│       │   │   ├── feed-routes.ts                  # GET /feed, POST /feed/refresh
│       │   │   ├── signal-routes.ts                # POST /signals/consumed, /signals/dismissed, /signals/saved
│       │   │   └── health-routes.ts                # GET /health, /health/detailed
│       │   ├── middleware/
│       │   │   ├── auth-middleware.ts               # Firebase Auth token verification
│       │   │   ├── rate-limiter.ts                  # Per-user rate limiting
│       │   │   └── request-validator.ts             # Input schema validation
│       │   ├── mappers/
│       │   │   └── feed-response-mapper.ts          # UCE internal → Flutter ContentItem/ContentCollection shape
│       │   └── index.ts
│       ├── package.json
│       └── tsconfig.json
│
├── config/
│   ├── identity-catalog.json        # Identity Catalog (goals, skills per identity)
│   ├── ontology.json                # Universal Identity Ontology graph definition
│   ├── quality-weights.json         # Stage 5 quality scoring weights
│   ├── prs-weights.json             # PRS ranking factor weights (α through κ)
│   ├── feed-constraints.json        # Max items, max collections, diversity rules
│   ├── ingestion-schedules.json     # Per-source cron expressions
│   ├── model-registry.json          # AI model metadata
│   ├── model-tiering-rules.json     # Content → model tier routing rules
│   ├── safety-blocklists.json       # Blocked channels, domains, keywords
│   └── trust-weights.json           # Trust Score formula weights (w₁–w₄)
│
├── functions/                       # Firebase Cloud Functions deployment entry
│   ├── src/
│   │   └── index.ts                 # Re-exports from layer packages
│   ├── package.json
│   └── tsconfig.json
│
├── scripts/
│   ├── seed-ontology.ts             # Populates initial ontology graph
│   ├── seed-content.ts              # Ingests initial content batch
│   ├── backfill-intelligence.ts     # Re-analyzes content with new model
│   ├── migrate-firestore-to-pg.ts   # Growth tier migration script
│   └── golden-set-validator.ts      # Validates recommendations against golden set
│
├── tests/
│   ├── unit/                        # Pure logic tests (normalizers, scoring, diversity)
│   ├── integration/                 # Adapter + database tests
│   ├── e2e/                         # Full pipeline tests
│   └── fixtures/                    # Test data (raw payloads, expected outputs)
│
└── docs/
    ├── uce_architecture.md          # SDS (canonical copy)
    └── Engineering_Implementation_Specification.md  # This document
```

### 2.2 Package Dependency Rules

Dependencies flow in one direction. Violations are merge-blocking.

```
shared ← layer1-ingestion
shared ← layer2-intelligence
shared ← layer3-recommendation
shared ← semantic-layer
shared ← api

layer1-ingestion → (no internal package dependencies)
layer2-intelligence → (no internal package dependencies)
layer3-recommendation → (no internal package dependencies)
semantic-layer → (no internal package dependencies)
api → layer3-recommendation (imports feed generator for direct invocation at Seed tier)
```

At Seed tier, the `api` package directly invokes `layer3-recommendation`'s `FeedGenerator` because both run in the same Firebase Cloud Functions process. At Growth tier, this becomes an internal HTTP call between Cloud Run services.

### 2.3 Language & Runtime

| Aspect | Choice | Rationale |
|---|---|---|
| Language | TypeScript 5.x (strict mode) | Type safety, Firebase compatibility, shared types across packages |
| Runtime | Node.js 20 LTS | Firebase Cloud Functions v2 target; long-term support |
| Package Manager | pnpm | Workspace support, fast installs, strict dependency resolution |
| Build System | Turborepo | Parallel builds, smart caching across monorepo packages |
| Linting | ESLint (strict-type-checked) | Catches type errors, enforces coding standards |
| Formatting | Prettier | Consistent formatting, no style debates |

---

## 3. Service Boundaries & Module Breakdown

### 3.1 Seed Tier — Single Deployment Unit

At the Seed tier (0–2,000 users), all packages are bundled into a single Firebase Cloud Functions deployment. The logical boundaries exist in code (packages), not in infrastructure.

```
Firebase Cloud Functions (single project)
├── Scheduled Functions
│   ├── ingestYouTube()         — every 6 hours
│   ├── ingestPodcasts()        — every 6 hours
│   ├── verifyContent()         — daily
│   ├── dedupRerun()            — weekly
│   └── shadowEvaluation()      — on model.deployed event
│
├── Event-Triggered Functions
│   ├── onContentIngested()     — Firestore trigger → Layer 2 pipeline
│   ├── onContentAnalyzed()     — Firestore trigger → Layer 3 cache invalidation + Graph enrichment
│   ├── onContentRetired()      — Firestore trigger → Intelligence cleanup + Path rerouting
│   ├── onIdentityUpdated()     — Firestore trigger → Feed cache invalidation
│   └── onModelDeployed()       — Firestore trigger → Shadow evaluation start
│
├── HTTP Functions
│   ├── GET  /api/v1/feed                — Returns personalized feed
│   ├── POST /api/v1/feed/refresh        — Force-refreshes feed
│   ├── POST /api/v1/signals/consumed    — Records content consumption
│   ├── POST /api/v1/signals/dismissed   — Records content dismissal
│   ├── POST /api/v1/signals/saved       — Records content save
│   └── GET  /api/v1/health              — Health check
│
└── Admin Functions (authenticated, restricted)
    ├── POST /admin/v1/ingest/trigger    — On-demand ingestion
    ├── POST /admin/v1/reanalyze         — Trigger re-analysis
    └── POST /admin/v1/ontology/update   — Update ontology version
```

### 3.2 Growth Tier — Separated Services

At the Growth tier (2,000–100,000 users), each layer becomes an independent Cloud Run service with its own deployment lifecycle.

| Service | Cloud Run Service | Database | Event Source |
|---|---|---|---|
| Ingestion Service | `uce-ingestion` | Cloud SQL (PostgreSQL), GCS | Pub/Sub publisher |
| Intelligence Service | `uce-intelligence` | Cloud SQL (PostgreSQL) | Pub/Sub subscriber + publisher |
| Recommendation Service | `uce-recommendation` | Cloud SQL (PostgreSQL), Redis | Pub/Sub subscriber |
| Semantic Service | `uce-semantic` | Cloud SQL (PostgreSQL) | Pub/Sub subscriber |
| Feed API | `uce-api` | Redis (read), Firestore (user profiles) | HTTP only |

### 3.3 Internal Module Responsibility Matrix

| Module | Owner Layer | Responsibility | Talks To |
|---|---|---|---|
| `IngestionPipeline` | Layer 1 | Orchestrate: fetch → normalize → dedup → validate → persist → publish | Source adapters, content stores, event bus |
| `VerificationPipeline` | Layer 1 | Scheduled HTTP checks to detect deleted/private content | Source APIs, normalized content store |
| `AnalysisPipeline` | Layer 2 | Orchestrate 5 analysis stages sequentially per content item | AI adapter, safety adapter, identity catalog, graph store |
| `TrustScoreCalculator` | Layer 2 | Compute Trust(Author) from historical data | Intelligence store (aggregation queries) |
| `ModelTierRouter` | Layer 2 | Route content to appropriate AI model based on tiering rules | Model registry config, AI adapters |
| `ShadowEvaluator` | Layer 2 | Parallel AI analysis with candidate models for comparison | AI adapters, shadow index store |
| `FeedGenerator` | Layer 3 | Full feed pipeline: select → rank → diversify → assemble → cache | Intelligence store (read), user context, recommendation memory, feed cache |
| `PRSCalculator` | Layer 3 | Compute Personalized Relevance Score for each candidate | PRS weights config, user profile |
| `DiversityEnforcer` | Layer 3 | Greedy re-ranking to satisfy diversity constraints | Feed constraints config |
| `FeedbackProcessor` | Layer 3 | Process consumption/dismissal/save events into user profile updates | User history store, user profile store |
| `IdentityEvolution` | Layer 3 | Detect drift vectors, goal saturation, publish suggestions | User history store, ontology, event bus |
| `RecommendationMemory` | Layer 3 | Track shown items, apply anti-fatigue logic, explainability | Recommendation memory store |
| `GraphEnrichmentPipeline` | Semantic | Extract entities from intelligence records, write graph edges | Intelligence store (read), graph store |
| `GraphQueryEngine` | Semantic | Traverse graph for prerequisites, PageRank, similarity | Graph store |
| `LearningPathEngine` | Semantic | Generate topologically sorted paths, handle rerouting | Graph store, learning path store, user history |
| `OntologyLoader` | Semantic | Load, validate, and version-manage the ontology configuration | Config files, event bus |
| `FeedResponseMapper` | API | Transform UCE internal feed into Flutter `ContentItem`/`ContentCollection` shape | Feed generator output |

---

## 4. Database Implementation

### 4.1 Seed Tier — Firestore Collections

At the Seed tier, all data lives in Firestore. Each store from the SDS (§14) maps to a Firestore collection.

#### Collection: `raw_content`

```
raw_content/{contentId}
├── sourceId: string              // "youtube", "podcast_rss", "article"
├── externalId: string            // Platform-specific ID
├── rawPayload: map               // Verbatim source response
├── fetchedAt: timestamp
└── storageRef: string            // GCS path (for large payloads)
```

**Retention policy:** Documents older than 12 months are moved to GCS cold storage via a scheduled Cloud Function. The Firestore document is replaced with a pointer `{ archived: true, gcsPath: "..." }`.

#### Collection: `content`

This is the **Normalized Content Store** — the Firestore implementation of the Universal Content Schema (SDS §11.1).

```
content/{contentId}
├── id: string (UUID)
├── sourceId: string
├── externalId: string
├── canonicalUrl: string
├── title: string
├── description: string
├── thumbnailUrl: string | null
├── authorName: string
├── authorExternalId: string | null
├── publishedAt: timestamp
├── contentFormat: string          // "VIDEO" | "PODCAST" | "ARTICLE" | "COURSE" | "BOOK_SUMMARY"
├── durationSeconds: number | null
├── wordCount: number | null
├── language: string               // ISO 639-1
├── sourceMetadata: map
├── transcriptAvailable: boolean
├── transcriptText: string | null
├── ingestedAt: timestamp
├── updatedAt: timestamp
├── contentFingerprint: string     // SHA-256
├── fuzzyFingerprint: string       // SimHash
├── status: string                 // "ACTIVE" | "QUARANTINED" | "DELETED" | "PENDING_REVIEW"
├── lifecycleState: string         // "FRESH" | "AGING" | "STALE" | "RETIRED"
├── lastVerifiedAt: timestamp | null
└── schemaVersion: number          // For lazy backfill
```

**Indexes required:**
- Composite: `(status, lifecycleState)` — for candidate selection queries
- Composite: `(sourceId, externalId)` — for deduplication lookups
- Single: `contentFingerprint` — for exact dedup
- Single: `fuzzyFingerprint` — for fuzzy dedup queries

#### Collection: `intelligence`

Stores Intelligence Records (SDS §8.4).

```
intelligence/{contentId}
├── contentId: string
├── version: number
├── analyzedAt: timestamp
├── modelId: string
│
├── stage1: map
│   ├── detectedLanguage: string
│   ├── contentFormat: string
│   └── channelReputationScore: number
│
├── stage2: map
│   ├── categories: array<string>
│   ├── topics: array<string>
│   ├── skills: array<string>
│   ├── difficulty: string         // "BEGINNER" | "INTERMEDIATE" | "ADVANCED" | "EXPERT"
│   ├── educationalValue: string   // "entertainment" | "informational" | "educational" | "transformational"
│   ├── summary: string
│   ├── keyTakeaways: array<string>
│   ├── estimatedLearningTime: string
│   ├── contentType: string
│   ├── clickbaitScore: number
│   └── aiConfidence: number
│
├── stage3: map
│   ├── safetyStatus: string       // "TRUSTED" | "PROVISIONAL" | "REVIEW" | "BLOCKED"
│   ├── safetyFlags: array<string>
│   └── trustScore: number
│
├── stage4: map
│   ├── identityMappings: array<{identityId: string, relevanceScore: number}>
│   └── goalMappings: array<{goalId: string, relevanceScore: number}>
│
├── stage5: map
│   └── qualityScore: number
│
└── trustTier: string              // "TRUSTED" | "PROVISIONAL" | "REVIEW" | "BLOCKED"
```

**Indexes required:**
- Array-contains on `stage4.identityMappings` (for candidate selection by identity)
- Composite: `(stage3.safetyStatus, stage5.qualityScore)` — for candidate filtering
- Composite: `(stage2.topics)` — array-contains for topic-based queries

#### Collection: `users` (existing — extended)

The existing Firestore `users` collection is extended with UCE-specific fields.

```
users/{userId}
├── ... (existing auth fields)
├── identityConfig: map            // Active identity configuration
│   ├── configId: string (UUID)
│   ├── identities: array<{identityId: string, priority: number}>
│   └── goals: array<{goalId: string, identityId: string}>
├── inferredDifficulty: number     // Float, updated by feedback processor
├── preferredFormats: array<string>
├── activeGoalSaturation: map      // { goalId: saturationPercent }
│
├── (subcollection) identityHistory/{configId}
│   ├── identities: array
│   ├── goals: array
│   ├── activatedAt: timestamp
│   └── deactivatedAt: timestamp | null
│
├── (subcollection) driftVectors/{vectorId}
│   ├── suggestedIdentityId: string
│   ├── confidence: number
│   ├── detectedAt: timestamp
│   └── status: string             // "PENDING" | "ACCEPTED" | "DISMISSED"
```

#### Collection: `user_history`

Records all content interaction events.

```
user_history/{userId}/events/{eventId}
├── eventType: string              // "consumed" | "dismissed" | "saved" | "replacement_completed"
├── contentId: string
├── timestamp: timestamp
├── durationSeconds: number | null
├── depth: number | null           // 0.0–1.0 consumption depth
├── reason: string | null          // For dismissals
├── sessionOrigin: string | null   // "replacement" | "intentional"
```

#### Collection: `recommendation_memory`

```
recommendation_memory/{userId}/records/{recordId}
├── contentId: string
├── recommendedAt: timestamp
├── feedGenerationId: string       // Links to the specific feed instance
├── prsScore: number
├── primarySignal: string          // Which PRS factor was dominant
├── userAction: string             // "CONSUMED" | "IGNORED" | "DISMISSED" | "SAVED"
├── actionAt: timestamp | null
```

#### Collection: `learning_paths`

```
learning_paths/{pathId}
├── userId: string
├── goalId: string
├── title: string
├── status: string                 // "ACTIVE" | "COMPLETED" | "PAUSED"
├── progressPercent: number
├── createdAt: timestamp
├── updatedAt: timestamp
│
├── (subcollection) steps/{stepId}
│   ├── contentId: string
│   ├── orderIndex: number
│   ├── status: string             // "LOCKED" | "UNLOCKED" | "COMPLETED"
│   ├── difficulty: string
│   ├── role: string               // "FOUNDATIONAL" | "CORE" | "COMPLEMENTARY"
│   └── completedAt: timestamp | null
```

#### Collection: `graph_nodes`

Seed tier Knowledge Graph stored as Firestore documents.

```
graph_nodes/{nodeId}
├── nodeType: string               // "IDENTITY" | "DOMAIN" | "GOAL" | "SKILL" | "CONCEPT" | "TOPIC" | "HABIT" | "CONTENT" | "AUTHOR" | "COMPANY" | "UNIVERSITY"
├── label: string                  // Human-readable name
├── metadata: map                  // Type-specific attributes
├── status: string                 // "ACTIVE" | "DEPRECATED"
├── createdAt: timestamp
└── updatedAt: timestamp
```

#### Collection: `graph_edges`

```
graph_edges/{edgeId}
├── sourceNodeId: string
├── targetNodeId: string
├── edgeType: string               // "TEACHES" | "REQUIRES" | "REINFORCES" | "AUTHORED_BY" | "WORKS_AT" | "FOUNDER_OF" | "GRADUATED_FROM" | "SERVES" | "IS_ALIAS_OF"
├── weight: number                 // 0.0–1.0
├── metadata: map
├── createdAt: timestamp
└── updatedAt: timestamp
```

**Indexes required:**
- Composite: `(sourceNodeId, edgeType)` — outbound edge traversal
- Composite: `(targetNodeId, edgeType)` — inbound edge traversal
- Composite: `(edgeType, weight)` — weighted edge queries

#### Collection: `feed_cache`

```
feed_cache/{userId}
├── identityConfigHash: string
├── generatedAt: timestamp
├── expiresAt: timestamp           // generatedAt + 4 hours
├── collections: array<map>        // Full feed payload, ready to serve
└── feedGenerationId: string       // UUID for recommendation memory linkage
```

#### Collection: `model_registry`

```
model_registry/{modelId}
├── provider: string
├── status: string                 // "CANDIDATE" | "SHADOW" | "ACTIVE" | "DEPRECATED" | "RETIRED"
├── costPer1KTokens: number
├── maxContextTokens: number
├── supportedOutputs: array<string>
├── promotedAt: timestamp | null
├── deprecatedAt: timestamp | null
```

#### Collection: `event_log`

Consumer-side deduplication and audit trail.

```
event_log/{eventId}
├── eventType: string
├── processedAt: timestamp
├── status: string                 // "PROCESSED" | "FAILED" | "DLQ"
├── retryCount: number
└── error: string | null
```

### 4.2 Growth Tier — PostgreSQL Schemas

At the Growth tier, Firestore collections migrate to PostgreSQL. The migration is transparent to business logic because all database access goes through storage adapter interfaces.

#### Schema: `layer1`

```sql
CREATE SCHEMA layer1;

CREATE TABLE layer1.content (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id       VARCHAR(50) NOT NULL,
    external_id     VARCHAR(255) NOT NULL,
    canonical_url   TEXT NOT NULL,
    title           VARCHAR(500) NOT NULL,
    description     TEXT,
    thumbnail_url   TEXT,
    author_name     VARCHAR(255) NOT NULL,
    author_external_id VARCHAR(255),
    published_at    TIMESTAMPTZ NOT NULL,
    content_format  VARCHAR(20) NOT NULL CHECK (content_format IN ('VIDEO', 'PODCAST', 'ARTICLE', 'COURSE', 'BOOK_SUMMARY')),
    duration_seconds INTEGER,
    word_count      INTEGER,
    language        VARCHAR(10) NOT NULL DEFAULT 'en',
    source_metadata JSONB DEFAULT '{}',
    transcript_available BOOLEAN NOT NULL DEFAULT FALSE,
    transcript_text TEXT,
    ingested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    content_fingerprint VARCHAR(64) NOT NULL,
    fuzzy_fingerprint   VARCHAR(64) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'QUARANTINED', 'DELETED', 'PENDING_REVIEW')),
    lifecycle_state VARCHAR(10) NOT NULL DEFAULT 'FRESH' CHECK (lifecycle_state IN ('FRESH', 'AGING', 'STALE', 'RETIRED')),
    last_verified_at TIMESTAMPTZ,
    schema_version  INTEGER NOT NULL DEFAULT 1,
    UNIQUE (source_id, external_id)
);

CREATE INDEX idx_content_fingerprint ON layer1.content (content_fingerprint);
CREATE INDEX idx_content_fuzzy ON layer1.content (fuzzy_fingerprint);
CREATE INDEX idx_content_status_lifecycle ON layer1.content (status, lifecycle_state);
CREATE INDEX idx_content_source ON layer1.content (source_id, ingested_at DESC);
CREATE INDEX idx_content_lifecycle_verified ON layer1.content (lifecycle_state, last_verified_at);
```

#### Schema: `layer2`

```sql
CREATE SCHEMA layer2;

CREATE TABLE layer2.intelligence (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id      UUID NOT NULL REFERENCES layer1.content(id),
    version         INTEGER NOT NULL DEFAULT 1,
    analyzed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    model_id        VARCHAR(100) NOT NULL,

    -- Stage 1
    detected_language     VARCHAR(10),
    content_format        VARCHAR(20),
    channel_reputation    REAL,

    -- Stage 2 (JSONB for flexibility)
    categories      JSONB NOT NULL DEFAULT '[]',
    topics          JSONB NOT NULL DEFAULT '[]',
    skills          JSONB NOT NULL DEFAULT '[]',
    difficulty      VARCHAR(20) NOT NULL CHECK (difficulty IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'EXPERT')),
    educational_value VARCHAR(20) NOT NULL CHECK (educational_value IN ('entertainment', 'informational', 'educational', 'transformational')),
    summary         TEXT,
    key_takeaways   JSONB DEFAULT '[]',
    estimated_learning_time VARCHAR(50),
    content_type    VARCHAR(50),
    clickbait_score REAL NOT NULL DEFAULT 0.0 CHECK (clickbait_score BETWEEN 0.0 AND 1.0),
    ai_confidence   REAL NOT NULL DEFAULT 0.0 CHECK (ai_confidence BETWEEN 0.0 AND 1.0),

    -- Stage 3
    safety_status   VARCHAR(20) NOT NULL DEFAULT 'REVIEW' CHECK (safety_status IN ('TRUSTED', 'PROVISIONAL', 'REVIEW', 'BLOCKED')),
    safety_flags    JSONB DEFAULT '[]',
    trust_score     REAL CHECK (trust_score BETWEEN 0.0 AND 1.0),

    -- Stage 4
    identity_mappings JSONB DEFAULT '[]',
    goal_mappings     JSONB DEFAULT '[]',

    -- Stage 5
    quality_score   REAL NOT NULL DEFAULT 0.0 CHECK (quality_score BETWEEN 0.0 AND 1.0),

    UNIQUE (content_id, version)
);

CREATE INDEX idx_intelligence_content ON layer2.intelligence (content_id);
CREATE INDEX idx_intelligence_safety_quality ON layer2.intelligence (safety_status, quality_score DESC);
CREATE INDEX idx_intelligence_topics ON layer2.intelligence USING GIN (topics);
CREATE INDEX idx_intelligence_skills ON layer2.intelligence USING GIN (skills);
CREATE INDEX idx_intelligence_identities ON layer2.intelligence USING GIN (identity_mappings);
CREATE INDEX idx_intelligence_model ON layer2.intelligence (model_id);

CREATE TABLE layer2.author_trust (
    author_external_id VARCHAR(255) PRIMARY KEY,
    source_id          VARCHAR(50) NOT NULL,
    author_name        VARCHAR(255) NOT NULL,
    consistency_score  REAL NOT NULL DEFAULT 0.5,
    reputation_score   REAL NOT NULL DEFAULT 0.5,
    historical_quality REAL NOT NULL DEFAULT 0.5,
    safety_record      REAL NOT NULL DEFAULT 1.0,
    trust_score        REAL NOT NULL DEFAULT 0.5,
    items_analyzed     INTEGER NOT NULL DEFAULT 0,
    last_updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### Schema: `layer3`

```sql
CREATE SCHEMA layer3;

CREATE TABLE layer3.recommendation_memory (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(128) NOT NULL,
    content_id      UUID NOT NULL,
    recommended_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    feed_generation_id UUID NOT NULL,
    prs_score       REAL NOT NULL,
    primary_signal  VARCHAR(30) NOT NULL,
    user_action     VARCHAR(20) DEFAULT 'PENDING' CHECK (user_action IN ('PENDING', 'CONSUMED', 'IGNORED', 'DISMISSED', 'SAVED')),
    action_at       TIMESTAMPTZ
) PARTITION BY RANGE (recommended_at);

-- Create monthly partitions
CREATE TABLE layer3.recommendation_memory_2026_07 PARTITION OF layer3.recommendation_memory
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
-- ... additional monthly partitions created by scheduled job

CREATE INDEX idx_recmem_user_date ON layer3.recommendation_memory (user_id, recommended_at DESC);
CREATE INDEX idx_recmem_user_action ON layer3.recommendation_memory (user_id, user_action);

CREATE TABLE layer3.learning_paths (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(128) NOT NULL,
    goal_id         VARCHAR(100) NOT NULL,
    title           VARCHAR(255) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'COMPLETED', 'PAUSED')),
    progress_percent REAL NOT NULL DEFAULT 0.0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_paths_user_status ON layer3.learning_paths (user_id, status);

CREATE TABLE layer3.path_steps (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path_id         UUID NOT NULL REFERENCES layer3.learning_paths(id) ON DELETE CASCADE,
    content_id      UUID NOT NULL,
    order_index     INTEGER NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'LOCKED' CHECK (status IN ('LOCKED', 'UNLOCKED', 'COMPLETED')),
    difficulty      VARCHAR(20) NOT NULL,
    role            VARCHAR(20) NOT NULL CHECK (role IN ('FOUNDATIONAL', 'CORE', 'COMPLEMENTARY')),
    completed_at    TIMESTAMPTZ,
    UNIQUE (path_id, order_index)
);

CREATE INDEX idx_steps_path ON layer3.path_steps (path_id, order_index);
CREATE INDEX idx_steps_content ON layer3.path_steps (content_id);
```

#### Schema: `semantic` (Growth Tier Graph — PostgreSQL Adjacency Tables)

```sql
CREATE SCHEMA semantic;

CREATE TABLE semantic.nodes (
    id          VARCHAR(255) PRIMARY KEY,  -- Stable, human-readable ID (e.g., "identity:entrepreneur")
    node_type   VARCHAR(30) NOT NULL CHECK (node_type IN ('IDENTITY', 'DOMAIN', 'GOAL', 'SKILL', 'CONCEPT', 'TOPIC', 'HABIT', 'CONTENT', 'AUTHOR', 'COMPANY', 'UNIVERSITY')),
    label       VARCHAR(500) NOT NULL,
    metadata    JSONB DEFAULT '{}',
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DEPRECATED')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_nodes_type ON semantic.nodes (node_type);
CREATE INDEX idx_nodes_type_status ON semantic.nodes (node_type, status);

CREATE TABLE semantic.edges (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_node_id  VARCHAR(255) NOT NULL REFERENCES semantic.nodes(id),
    target_node_id  VARCHAR(255) NOT NULL REFERENCES semantic.nodes(id),
    edge_type       VARCHAR(30) NOT NULL CHECK (edge_type IN ('TEACHES', 'REQUIRES', 'REINFORCES', 'AUTHORED_BY', 'WORKS_AT', 'FOUNDER_OF', 'GRADUATED_FROM', 'SERVES', 'IS_ALIAS_OF', 'SUPPORTS', 'COMPOUNDS_INFLUENCE')),
    weight          REAL NOT NULL DEFAULT 1.0 CHECK (weight BETWEEN 0.0 AND 1.0),
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_node_id, target_node_id, edge_type)
);

CREATE INDEX idx_edges_source ON semantic.edges (source_node_id, edge_type);
CREATE INDEX idx_edges_target ON semantic.edges (target_node_id, edge_type);
CREATE INDEX idx_edges_type ON semantic.edges (edge_type);
```

**Prerequisite Traversal (Recursive CTE):**

```sql
-- Find all prerequisites for a Goal, ordered topologically
WITH RECURSIVE prereqs AS (
    -- Base: direct prerequisites of the target goal
    SELECT e.target_node_id AS node_id, e.source_node_id AS prereq_id, 1 AS depth
    FROM semantic.edges e
    WHERE e.target_node_id = :goal_node_id
      AND e.edge_type = 'REQUIRES'

    UNION ALL

    -- Recursive: prerequisites of prerequisites
    SELECT p.prereq_id AS node_id, e.source_node_id AS prereq_id, p.depth + 1
    FROM prereqs p
    JOIN semantic.edges e ON e.target_node_id = p.prereq_id
    WHERE e.edge_type = 'REQUIRES'
      AND p.depth < 10  -- Prevent infinite loops (DAG guard)
)
SELECT DISTINCT prereq_id, MAX(depth) AS max_depth
FROM prereqs
GROUP BY prereq_id
ORDER BY max_depth DESC;  -- Topological order: deepest prerequisites first
```

### 4.3 Object Storage Organization (GCS)

```
gs://sayno-uce-raw/
├── youtube/{externalId}/{timestamp}.json
├── podcast/{externalId}/{timestamp}.json
├── article/{externalId}/{timestamp}.json
└── archive/                               # Cold storage for payloads > 12 months
    └── {year}/{month}/{contentId}.json.gz

gs://sayno-uce-config/
├── ontology/
│   ├── v1.0.0.json
│   ├── v1.1.0.json
│   └── current.json                       # Symlink to latest
├── catalogs/
│   ├── identity-catalog-v1.json
│   └── identity-catalog-current.json
└── golden-sets/
    └── recommendation-golden-v1.json
```

---

## 5. Event System Implementation

### 5.1 Event Envelope

Every event conforms to this TypeScript type (SDS §12.2):

```typescript
interface UCEEvent<T = unknown> {
  eventId: string;        // UUID v4
  eventType: string;      // Dot-notation event name
  version: string;        // Schema version of this event type ("2.0")
  timestamp: string;      // ISO 8601 UTC
  source: string;         // Producing service identifier
  payload: T;             // Event-specific data
}
```

### 5.2 Event Payload Types

```typescript
// content.ingested
interface ContentIngestedPayload {
  contentId: string;       // UUID
  sourceId: string;
  ingestedAt: string;      // ISO 8601
}

// content.analyzed
interface ContentAnalyzedPayload {
  contentId: string;
  qualityScore: number;
  trustTier: 'TRUSTED' | 'PROVISIONAL' | 'REVIEW' | 'BLOCKED';
  topics: string[];
}

// content.analyzed.failed
interface ContentAnalysisFailedPayload {
  contentId: string;
  stage: string;           // "stage1" | "stage2" | "stage3" | "stage4" | "stage5"
  error: string;
}

// content.trust.flagged
interface ContentTrustFlaggedPayload {
  contentId: string;
  trustScore: number;
  flags: string[];
}

// content.retired
interface ContentRetiredPayload {
  contentId: string;
  reason: string;          // "SOURCE_DELETED" | "VERIFICATION_FAILED" | "DUPLICATE_OF_EXISTING" | "MANUAL"
  retiredAt: string;
}

// content.consumed
interface ContentConsumedPayload {
  userId: string;
  contentId: string;
  durationSeconds: number;
  depth: number;           // 0.0–1.0
}

// content.dismissed
interface ContentDismissedPayload {
  userId: string;
  contentId: string;
  reason: string;
}

// content.saved
interface ContentSavedPayload {
  userId: string;
  contentId: string;
  savedAt: string;
}

// identity.updated
interface IdentityUpdatedPayload {
  userId: string;
  newIdentityConfigId: string;
}

// identity.evolution.detected
interface IdentityEvolutionPayload {
  userId: string;
  suggestedIdentityId: string;
  confidence: number;
}

// path.completed
interface PathCompletedPayload {
  userId: string;
  pathId: string;
  completedAt: string;
}

// model.deployed
interface ModelDeployedPayload {
  modelId: string;
  version: string;
  deploymentMode: 'SHADOW' | 'ACTIVE';
}

// catalog.updated
interface CatalogUpdatedPayload {
  catalogVersion: string;
}

// ontology.updated
interface OntologyUpdatedPayload {
  ontologyVersion: string;
}
```

### 5.3 Seed Tier — Firestore Trigger Implementation

At the Seed tier, events are emitted by writing documents to an `events` collection in Firestore, which triggers Cloud Functions.

```typescript
// Event publishing (Seed tier)
class FirestoreEventBus implements EventBusAdapter {
  async publish(event: UCEEvent): Promise<void> {
    await db.collection('events').doc(event.eventId).set({
      ...event,
      _processed: false,
      _createdAt: FieldValue.serverTimestamp(),
    });
  }
}

// Event consumption (Seed tier) — Cloud Function trigger
export const onContentIngested = onDocumentCreated(
  'events/{eventId}',
  async (snapshot) => {
    const event = snapshot.data as UCEEvent;
    if (event.eventType !== 'content.ingested') return;
    
    // Idempotency check
    const logRef = db.collection('event_log').doc(event.eventId);
    const existing = await logRef.get();
    if (existing.exists) return; // Already processed
    
    try {
      await analysisPipeline.process(event.payload as ContentIngestedPayload);
      await logRef.set({ status: 'PROCESSED', processedAt: FieldValue.serverTimestamp() });
    } catch (error) {
      await logRef.set({ status: 'FAILED', error: error.message, retryCount: 1 });
      // Cloud Functions retry policy handles re-invocation
    }
  }
);
```

### 5.4 Growth Tier — Pub/Sub Implementation

At the Growth tier, the `EventBusAdapter` implementation switches to Google Cloud Pub/Sub.

```typescript
class PubSubEventBus implements EventBusAdapter {
  async publish(event: UCEEvent): Promise<void> {
    const topic = this.topicForEvent(event.eventType);
    await topic.publishMessage({
      json: event,
      orderingKey: event.payload.contentId || event.payload.userId, // Partition key
      attributes: {
        eventType: event.eventType,
        version: event.version,
      },
    });
  }

  private topicForEvent(eventType: string): Topic {
    // Map event types to topics
    const mapping: Record<string, string> = {
      'content.ingested': 'uce-content-ingested',
      'content.analyzed': 'uce-content-analyzed',
      'content.retired': 'uce-content-retired',
      'content.consumed': 'uce-user-signals',
      'content.dismissed': 'uce-user-signals',
      'content.saved': 'uce-user-signals',
      'identity.updated': 'uce-identity-events',
      'identity.evolution.detected': 'uce-identity-events',
      'model.deployed': 'uce-system-events',
      'catalog.updated': 'uce-system-events',
      'ontology.updated': 'uce-system-events',
    };
    return this.pubsub.topic(mapping[eventType] || 'uce-system-events');
  }
}
```

### 5.5 Dead Letter Queue

```typescript
// DLQ handling
async function processWithDLQ(
  event: UCEEvent,
  handler: (event: UCEEvent) => Promise<void>,
  maxRetries: number
): Promise<void> {
  const logRef = db.collection('event_log').doc(event.eventId);
  const existing = await logRef.get();
  
  if (existing.exists && existing.data().status === 'PROCESSED') return;
  
  const retryCount = existing.exists ? existing.data().retryCount : 0;
  
  if (retryCount >= maxRetries) {
    await logRef.set({
      status: 'DLQ',
      eventType: event.eventType,
      retryCount,
      lastError: 'Max retries exceeded',
      movedToDlqAt: FieldValue.serverTimestamp(),
    });
    logger.error(`Event ${event.eventId} moved to DLQ after ${maxRetries} retries`, { event });
    // Alert to monitoring
    return;
  }
  
  try {
    await handler(event);
    await logRef.set({ status: 'PROCESSED', processedAt: FieldValue.serverTimestamp() });
  } catch (error) {
    await logRef.set({
      status: 'FAILED',
      retryCount: retryCount + 1,
      lastError: error.message,
      lastFailedAt: FieldValue.serverTimestamp(),
    });
    throw error; // Let Cloud Functions/Pub/Sub retry policy handle re-invocation
  }
}
```

---

## 6. Layer 1 — Ingestion Implementation

### 6.1 YouTube Adapter

```typescript
class YouTubeAdapter implements ContentSourceAdapter {
  private youtube: youtube_v3.Youtube;
  
  sourceId(): string { return 'youtube'; }

  async fetchBatch(cursor: string | null, limit: number): Promise<FetchResult> {
    // Strategy: Fetch from curated channel list + topic-based search queries
    const channelIds = this.config.channelIds;  // From ingestion-schedules.json
    const searchQueries = this.config.searchQueries;  // Identity-derived queries
    
    const items: RawContentItem[] = [];
    
    // 1. Fetch recent uploads from curated channels
    for (const channelId of channelIds) {
      const response = await this.youtube.search.list({
        part: ['snippet'],
        channelId,
        order: 'date',
        publishedAfter: cursor || this.defaultStartDate(),
        maxResults: Math.min(limit, 50),
        type: ['video'],
      });
      
      for (const item of response.data.items || []) {
        // Fetch full video details (duration, statistics)
        const videoDetails = await this.youtube.videos.list({
          part: ['snippet', 'contentDetails', 'statistics'],
          id: [item.id.videoId],
        });
        
        items.push({
          externalId: item.id.videoId,
          sourceId: 'youtube',
          rawPayload: videoDetails.data.items[0],
          fetchedAt: new Date(),
        });
      }
    }
    
    return {
      items,
      nextCursor: /* ISO date of last item */ ,
      hasMore: items.length === limit,
      fetchedAt: new Date(),
    };
  }

  async healthCheck(): Promise<HealthStatus> {
    try {
      await this.youtube.search.list({ part: ['id'], q: 'test', maxResults: 1 });
      return { status: 'HEALTHY', checkedAt: new Date() };
    } catch (error) {
      return { status: 'UNHEALTHY', error: error.message, checkedAt: new Date() };
    }
  }
}
```

### 6.2 YouTube Normalizer

```typescript
class YouTubeNormalizer implements SourceNormalizer {
  normalize(raw: RawContentItem): UniversalContentItem {
    const video = raw.rawPayload;
    const snippet = video.snippet;
    const contentDetails = video.contentDetails;
    const statistics = video.statistics;
    
    return {
      id: uuidv4(),
      sourceId: 'youtube',
      externalId: video.id,
      canonicalUrl: `https://www.youtube.com/watch?v=${video.id}`,
      title: snippet.title.substring(0, 500),
      description: (snippet.description || '').substring(0, 5000),
      thumbnailUrl: snippet.thumbnails?.high?.url || snippet.thumbnails?.default?.url || null,
      authorName: snippet.channelTitle,
      authorExternalId: snippet.channelId,
      publishedAt: new Date(snippet.publishedAt),
      contentFormat: 'VIDEO',
      durationSeconds: parseDuration(contentDetails.duration),  // ISO 8601 → seconds
      wordCount: null,
      language: snippet.defaultLanguage || snippet.defaultAudioLanguage || 'en',
      sourceMetadata: {
        viewCount: parseInt(statistics.viewCount || '0'),
        likeCount: parseInt(statistics.likeCount || '0'),
        channelSubscriberCount: null,  // Requires separate channel API call
        categoryId: snippet.categoryId,
        tags: snippet.tags || [],
      },
      transcriptAvailable: false,  // Set after transcript fetch attempt
      transcriptText: null,
      ingestedAt: new Date(),
      updatedAt: new Date(),
      contentFingerprint: '',   // Computed by pipeline
      fuzzyFingerprint: '',     // Computed by pipeline
      status: 'ACTIVE',
    };
  }
}
```

### 6.3 Ingestion Pipeline Orchestration

```typescript
class IngestionPipeline {
  constructor(
    private sourceAdapters: Map<string, ContentSourceAdapter>,
    private normalizers: Map<string, SourceNormalizer>,
    private deduplicationEngine: DeduplicationEngine,
    private schemaValidator: SchemaValidator,
    private rawContentStore: RawContentStore,
    private normalizedContentStore: NormalizedContentStore,
    private eventBus: EventBusAdapter,
    private logger: Logger,
  ) {}

  async ingestFromSource(sourceId: string): Promise<IngestionReport> {
    const adapter = this.sourceAdapters.get(sourceId);
    const normalizer = this.normalizers.get(sourceId);
    const report = new IngestionReport(sourceId);
    
    let cursor = await this.getLastCursor(sourceId);
    let hasMore = true;

    while (hasMore) {
      const batch = await adapter.fetchBatch(cursor, 50);
      
      for (const rawItem of batch.items) {
        try {
          // 1. Store raw payload
          await this.rawContentStore.store(rawItem);
          
          // 2. Normalize
          const normalized = normalizer.normalize(rawItem);
          
          // 3. Generate fingerprints
          normalized.contentFingerprint = generateSHA256(`${normalized.sourceId}:${normalized.externalId}`);
          normalized.fuzzyFingerprint = generateSimHash(`${normalized.title} ${normalized.description}`);
          
          // 4. Deduplication check
          const dupResult = await this.deduplicationEngine.check(normalized);
          if (dupResult.isDuplicate) {
            report.recordSkipped(normalized.externalId, dupResult.reason);
            continue;
          }
          
          // 5. Schema validation
          const validationResult = this.schemaValidator.validate(normalized);
          if (!validationResult.valid) {
            await this.quarantine(normalized, validationResult.errors);
            report.recordQuarantined(normalized.externalId, validationResult.errors);
            continue;
          }
          
          // 6. Persist
          await this.normalizedContentStore.upsert(normalized);
          
          // 7. Publish event
          await this.eventBus.publish({
            eventId: uuidv4(),
            eventType: 'content.ingested',
            version: '2.0',
            timestamp: new Date().toISOString(),
            source: 'layer1.ingestion',
            payload: {
              contentId: normalized.id,
              sourceId: normalized.sourceId,
              ingestedAt: normalized.ingestedAt.toISOString(),
            },
          });
          
          report.recordIngested(normalized.id);
        } catch (error) {
          this.logger.error('Ingestion failed for item', { sourceId, externalId: rawItem.externalId, error });
          report.recordFailed(rawItem.externalId, error.message);
          
          // Publish failure event
          await this.eventBus.publish({
            eventId: uuidv4(),
            eventType: 'content.ingested.failed',
            version: '2.0',
            timestamp: new Date().toISOString(),
            source: 'layer1.ingestion',
            payload: {
              sourceId: rawItem.sourceId,
              externalId: rawItem.externalId,
              error: error.message,
            },
          });
        }
      }
      
      cursor = batch.nextCursor;
      hasMore = batch.hasMore;
      await this.saveLastCursor(sourceId, cursor);
    }
    
    return report;
  }
}
```

### 6.4 Deduplication Engine

```typescript
class DeduplicationEngine {
  constructor(
    private normalizedContentStore: NormalizedContentStore,
  ) {}

  async check(item: UniversalContentItem): Promise<DuplicateCheckResult> {
    // Level 1: Exact match
    const exact = await this.normalizedContentStore.findByFingerprint(item.contentFingerprint);
    if (exact) {
      return { isDuplicate: true, reason: 'EXACT_MATCH', matchedContentId: exact.id };
    }
    
    // Level 2: Fuzzy match (SimHash with Hamming distance ≤ 3)
    const fuzzyMatches = await this.normalizedContentStore.findByFuzzyFingerprint(
      item.fuzzyFingerprint,
      3  // Max Hamming distance
    );
    if (fuzzyMatches.length > 0) {
      return { isDuplicate: true, reason: 'FUZZY_MATCH', matchedContentId: fuzzyMatches[0].id };
    }
    
    return { isDuplicate: false };
  }
}
```

### 6.5 Content Verification Pipeline (SDS §13.2)

```typescript
class VerificationPipeline {
  // Scheduled: daily
  async verifyBatch(): Promise<void> {
    // Videos: check every 30 days
    const videosToVerify = await this.contentStore.findByVerificationDue('VIDEO', 30);
    for (const content of videosToVerify) {
      await this.verifyYouTubeVideo(content);
    }
    
    // Podcasts: check every 45 days
    const podcastsToVerify = await this.contentStore.findByVerificationDue('PODCAST', 45);
    for (const content of podcastsToVerify) {
      await this.verifyPodcast(content);
    }
    
    // Articles: check every 14 days
    const articlesToVerify = await this.contentStore.findByVerificationDue('ARTICLE', 14);
    for (const content of articlesToVerify) {
      await this.verifyArticle(content);
    }
  }

  private async verifyYouTubeVideo(content: UniversalContentItem): Promise<void> {
    try {
      const video = await this.youtubeApi.videos.list({
        part: ['status'],
        id: [content.externalId],
      });
      
      if (!video.data.items?.length) {
        await this.handleVerificationFailure(content, 'VIDEO_DELETED');
        return;
      }
      
      const status = video.data.items[0].status;
      if (status.privacyStatus === 'private' || !status.embeddable) {
        await this.handleVerificationFailure(content, 'VIDEO_PRIVATE_OR_UNEMBEDDABLE');
        return;
      }
      
      await this.contentStore.updateVerification(content.id, 'FRESH');
    } catch (error) {
      this.logger.warn('Verification check failed', { contentId: content.id, error });
    }
  }

  private async handleVerificationFailure(content: UniversalContentItem, reason: string): Promise<void> {
    const failureCount = await this.contentStore.incrementVerificationFailures(content.id);
    
    if (failureCount >= 3 || reason === 'VIDEO_DELETED') {
      // Retire the content (SDS §13.4)
      await this.contentStore.updateLifecycleState(content.id, 'RETIRED');
      await this.eventBus.publish({
        eventId: uuidv4(),
        eventType: 'content.retired',
        version: '2.0',
        timestamp: new Date().toISOString(),
        source: 'layer1.lifecycle',
        payload: {
          contentId: content.id,
          reason: reason,
          retiredAt: new Date().toISOString(),
        },
      });
    } else {
      await this.contentStore.updateLifecycleState(content.id, 'STALE');
    }
  }
}
```

---

## 7. Layer 2 — Intelligence Pipeline Implementation

### 7.1 Analysis Pipeline Orchestrator

The pipeline processes one content item at a time through five sequential stages (SDS §8.2). Each stage receives the accumulated output of previous stages.

```typescript
class AnalysisPipeline {
  constructor(
    private stage1: MetadataExtractor,
    private stage2: AIAnalyzer,
    private stage3: TrustCredibilityEvaluator,
    private stage4: IdentityMapper,
    private stage5: QualityScorer,
    private intelligenceStore: IntelligenceStore,
    private eventBus: EventBusAdapter,
    private logger: Logger,
  ) {}

  async process(payload: ContentIngestedPayload): Promise<void> {
    const content = await this.contentStore.findById(payload.contentId);
    if (!content) throw new Error(`Content not found: ${payload.contentId}`);
    
    const context: PipelineContext = { content, stages: {} };
    
    try {
      // Stage 1: Metadata Extraction (no AI)
      context.stages.stage1 = await this.stage1.extract(content);
      
      // Stage 2: AI Analysis
      context.stages.stage2 = await this.stage2.analyze(content, context.stages.stage1);
      
      // Stage 3: Trust & Credibility
      context.stages.stage3 = await this.stage3.evaluate(content, context.stages.stage2);
      
      // If BLOCKED, stop pipeline here — do not index or rank this content
      if (context.stages.stage3.safetyStatus === 'BLOCKED') {
        await this.persistBlockedRecord(payload.contentId, context);
        return;
      }
      
      // Stage 4: Identity & Knowledge Graph Mapping
      context.stages.stage4 = await this.stage4.map(content, context.stages.stage2, context.stages.stage3);
      
      // Stage 5: Quality Scoring
      context.stages.stage5 = await this.stage5.score(context);
      
      // Persist Intelligence Record
      const record = this.buildIntelligenceRecord(payload.contentId, context);
      await this.intelligenceStore.upsert(record);
      
      // Publish content.analyzed event
      await this.eventBus.publish({
        eventId: uuidv4(),
        eventType: 'content.analyzed',
        version: '2.0',
        timestamp: new Date().toISOString(),
        source: 'layer2.intelligence',
        payload: {
          contentId: payload.contentId,
          qualityScore: record.qualityScore,
          trustTier: record.trustTier,
          topics: record.topics,
        },
      });
    } catch (error) {
      this.logger.error('Analysis pipeline failed', {
        contentId: payload.contentId,
        stage: context.lastCompletedStage,
        error,
      });
      
      await this.eventBus.publish({
        eventId: uuidv4(),
        eventType: 'content.analyzed.failed',
        version: '2.0',
        timestamp: new Date().toISOString(),
        source: 'layer2.intelligence',
        payload: {
          contentId: payload.contentId,
          stage: context.lastCompletedStage || 'unknown',
          error: error.message,
        },
      });
      
      throw error; // Allow retry mechanism to handle
    }
  }
}
```

### 7.2 Stage 2 — AI Analysis Prompt

```typescript
class AIAnalyzer {
  constructor(
    private modelTierRouter: ModelTierRouter,
    private transcriptAdapter: TranscriptAdapter,
  ) {}

  async analyze(content: UniversalContentItem, stage1: Stage1Output): Promise<Stage2Output> {
    // Determine which AI model to use
    const adapter = await this.modelTierRouter.selectAdapter(content);
    
    // Attempt transcript fetch
    let transcript: string | null = null;
    if (content.contentFormat === 'VIDEO' || content.contentFormat === 'PODCAST') {
      transcript = await this.transcriptAdapter.fetchTranscript(content.sourceId, content.externalId);
    } else if (content.contentFormat === 'ARTICLE') {
      transcript = content.description;  // Article body IS the transcript
    }
    
    // Build prompt (SDS §18.3)
    const prompt = this.buildPrompt(content, stage1, transcript);
    
    // Call AI
    const response = await adapter.analyze({
      systemPrompt: ANALYSIS_SYSTEM_PROMPT,
      userPrompt: prompt,
      expectedSchema: ANALYSIS_OUTPUT_SCHEMA,
    });
    
    // Validate response structure
    const validated = this.validateAIOutput(response);
    
    return validated;
  }
  
  private buildPrompt(content: UniversalContentItem, stage1: Stage1Output, transcript: string | null): string {
    const transcriptExcerpt = transcript
      ? transcript.split(/\s+/).slice(0, 3000).join(' ')  // First 3000 words
      : '(No transcript available)';
    
    return `
CONTEXT:
- Content Format: ${content.contentFormat}
- Duration: ${content.durationSeconds ? `${Math.round(content.durationSeconds / 60)} minutes` : 'Unknown'}
- Language: ${stage1.detectedLanguage}
- Channel Reputation Score: ${stage1.channelReputationScore.toFixed(2)}

CONTENT:
Title: ${content.title}
Description: ${content.description}
Transcript (first 3000 words): ${transcriptExcerpt}
Source Tags: ${(content.sourceMetadata.tags || []).join(', ')}

Analyze this content and return the structured JSON.`;
  }
}

const ANALYSIS_SYSTEM_PROMPT = `You are a content analysis engine for an educational content platform.
Your job is to analyze a piece of content and extract structured metadata.
You must return a JSON object matching the exact schema provided.
Do not include any text outside the JSON object.

SCHEMA:
{
  "categories": ["string"],
  "topics": ["string"],
  "skills": ["string"],
  "difficulty": "Beginner|Intermediate|Advanced|Expert",
  "educationalValue": "entertainment|informational|educational|transformational",
  "summary": "string (max 150 words)",
  "keyTakeaways": ["string (max 5 items)"],
  "estimatedLearningTime": "string",
  "contentType": "string",
  "clickbaitScore": 0.0-1.0,
  "confidence": 0.0-1.0
}`;
```

### 7.3 Stage 3 — Trust & Credibility

```typescript
class TrustCredibilityEvaluator {
  constructor(
    private blocklistManager: BlocklistManager,
    private trustScoreCalculator: TrustScoreCalculator,
    private config: TrustWeightsConfig,
  ) {}

  async evaluate(content: UniversalContentItem, stage2: Stage2Output): Promise<Stage3Output> {
    // Tier 1: Deterministic Safety Rules
    const blockResult = await this.blocklistManager.check(content);
    if (blockResult.isBlocked) {
      return {
        safetyStatus: 'BLOCKED',
        safetyFlags: blockResult.reasons,
        trustScore: 0.0,
      };
    }
    
    // Tier 2: AI-Assisted Safety (extracted from Stage 2 output)
    const safetyFlags: string[] = [];
    if (stage2.clickbaitScore > 0.7) safetyFlags.push('HIGH_CLICKBAIT');
    // Additional AI-derived safety signals would be extracted here
    
    // Tier 3: Source Credibility
    const trustScore = await this.trustScoreCalculator.compute(
      content.authorExternalId || content.authorName,
      content.sourceId
    );
    
    let safetyStatus: string;
    if (safetyFlags.some(f => f.startsWith('SEVERE_'))) {
      safetyStatus = 'BLOCKED';
    } else if (safetyFlags.length > 0 || trustScore < 0.3) {
      safetyStatus = 'REVIEW';
    } else if (trustScore < 0.6) {
      safetyStatus = 'PROVISIONAL';
    } else {
      safetyStatus = 'TRUSTED';
    }
    
    return { safetyStatus, safetyFlags, trustScore };
  }
}
```

### 7.4 Stage 5 — Quality Scoring

```typescript
class QualityScorer {
  constructor(private weights: QualityWeightsConfig) {}

  score(context: PipelineContext): Stage5Output {
    const { stage1, stage2, stage3, stage4 } = context.stages;
    
    // Load weights from configuration (SDS §8.3, Stage 5)
    const w = this.weights;
    
    const signals = {
      aiConfidence: stage2.aiConfidence,
      educationalValue: this.educationalValueToNumeric(stage2.educationalValue),
      clickbaitInverse: 1.0 - stage2.clickbaitScore,
      authorTrustScore: stage3.trustScore,
      contentDepth: this.computeContentDepth(context.content, stage2),
      graphConnectivity: this.computeGraphConnectivity(stage4),
    };
    
    const qualityScore = Math.min(1.0, Math.max(0.0,
      w.aiConfidence * signals.aiConfidence +
      w.educationalValue * signals.educationalValue +
      w.clickbaitInverse * signals.clickbaitInverse +
      w.authorTrustScore * signals.authorTrustScore +
      w.contentDepth * signals.contentDepth +
      w.graphConnectivity * signals.graphConnectivity
    ));
    
    return { qualityScore };
  }

  private educationalValueToNumeric(value: string): number {
    const map: Record<string, number> = {
      'entertainment': 0.2,
      'informational': 0.5,
      'educational': 0.8,
      'transformational': 1.0,
    };
    return map[value] || 0.5;
  }

  private computeContentDepth(content: UniversalContentItem, stage2: Stage2Output): number {
    const durationMinutes = (content.durationSeconds || 0) / 60;
    const difficultyMultiplier: Record<string, number> = {
      'BEGINNER': 0.5, 'INTERMEDIATE': 0.75, 'ADVANCED': 1.0, 'EXPERT': 1.0,
    };
    // Normalized: 30-minute intermediate video = 1.0
    return Math.min(1.0, (durationMinutes / 30) * (difficultyMultiplier[stage2.difficulty] || 0.5));
  }

  private computeGraphConnectivity(stage4: Stage4Output): number {
    const totalMappings = stage4.identityMappings.length + stage4.goalMappings.length;
    // Normalized: 5+ mappings = 1.0
    return Math.min(1.0, totalMappings / 5);
  }
}
```

### 7.5 Model Tier Router (SDS §17.2)

```typescript
class ModelTierRouter {
  constructor(
    private adapters: Map<string, AIAnalysisAdapter>,
    private modelRegistry: ModelRegistry,
    private tieringRules: ModelTieringConfig,
  ) {}

  async selectAdapter(content: UniversalContentItem): Promise<AIAnalysisAdapter> {
    const activeModel = await this.modelRegistry.getActiveModel();
    
    // Apply tiering rules (SDS §24.3)
    let tier: 'lightweight' | 'standard' | 'premium';
    
    if (content.transcriptAvailable && (content.durationSeconds || 0) > 300) {
      tier = 'standard';
    } else if ((content.description || '').split(/\s+/).length > 200) {
      tier = 'standard';
    } else {
      tier = 'lightweight';
    }
    
    const modelId = this.tieringRules.modelForTier(tier, activeModel.provider);
    return this.adapters.get(modelId)!;
  }
}
```

---

## 8. Knowledge Graph Implementation

### 8.1 Seed Tier — Firestore Graph

At the Seed tier, the Knowledge Graph is stored in Firestore `graph_nodes` and `graph_edges` collections (§4.1). Graph operations are implemented in application code rather than graph database queries.

```typescript
class FirestoreGraphStore implements GraphStore {
  async addContentNode(contentId: string, intelligence: IntelligenceRecord): Promise<void> {
    // Create content node
    await this.nodesCollection.doc(`content:${contentId}`).set({
      nodeType: 'CONTENT',
      label: intelligence.title,
      metadata: {
        contentId,
        difficulty: intelligence.difficulty,
        qualityScore: intelligence.qualityScore,
      },
      status: 'ACTIVE',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    
    // Create edges: TEACHES → Skills/Concepts
    for (const skill of intelligence.skills) {
      const skillNodeId = `skill:${this.normalizeId(skill)}`;
      await this.ensureNode(skillNodeId, 'SKILL', skill);
      await this.addEdge(`content:${contentId}`, skillNodeId, 'TEACHES', 0.8);
    }
    
    // Create edges: AUTHORED_BY → Author
    const authorNodeId = `author:${intelligence.authorExternalId || this.normalizeId(intelligence.authorName)}`;
    await this.ensureNode(authorNodeId, 'AUTHOR', intelligence.authorName);
    await this.addEdge(`content:${contentId}`, authorNodeId, 'AUTHORED_BY', 1.0);
    
    // Create edges: SERVES → Goals (from identity mappings)
    for (const mapping of intelligence.goalMappings) {
      await this.addEdge(`content:${contentId}`, `goal:${mapping.goalId}`, 'SERVES', mapping.relevanceScore);
    }
  }
  
  async findPrerequisites(goalNodeId: string, maxDepth: number = 10): Promise<string[]> {
    // BFS traversal of REQUIRES edges (Seed tier: application-level traversal)
    const visited = new Set<string>();
    const ordered: string[] = [];
    const queue: Array<{ nodeId: string; depth: number }> = [{ nodeId: goalNodeId, depth: 0 }];
    
    while (queue.length > 0) {
      const { nodeId, depth } = queue.shift()!;
      if (visited.has(nodeId) || depth > maxDepth) continue;
      visited.add(nodeId);
      
      const inboundEdges = await this.edgesCollection
        .where('targetNodeId', '==', nodeId)
        .where('edgeType', '==', 'REQUIRES')
        .get();
      
      for (const edge of inboundEdges.docs) {
        const prereqId = edge.data().sourceNodeId;
        if (!visited.has(prereqId)) {
          queue.push({ nodeId: prereqId, depth: depth + 1 });
          ordered.unshift(prereqId);  // Prerequisites come first
        }
      }
    }
    
    return ordered;
  }
}
```

### 8.2 Ontology Seeding

The initial ontology is loaded from `config/ontology.json`:

```json
{
  "version": "1.0.0",
  "nodes": [
    { "id": "identity:entrepreneur", "type": "IDENTITY", "label": "Entrepreneur" },
    { "id": "domain:business", "type": "DOMAIN", "label": "Business & Startups" },
    { "id": "goal:raise-seed-round", "type": "GOAL", "label": "Raise a Seed Round" },
    { "id": "skill:pitching", "type": "SKILL", "label": "Pitching & Presentation" },
    { "id": "concept:product-market-fit", "type": "CONCEPT", "label": "Product-Market Fit" },
    { "id": "topic:venture-capital", "type": "TOPIC", "label": "Venture Capital" }
  ],
  "edges": [
    { "source": "identity:entrepreneur", "target": "domain:business", "type": "SERVES", "weight": 1.0 },
    { "source": "domain:business", "target": "goal:raise-seed-round", "type": "SERVES", "weight": 0.9 },
    { "source": "goal:raise-seed-round", "target": "skill:pitching", "type": "REQUIRES", "weight": 0.85 },
    { "source": "skill:pitching", "target": "concept:product-market-fit", "type": "REQUIRES", "weight": 0.7 }
  ]
}
```

---

## 9. Layer 3 — Recommendation Engine Implementation

### 9.1 Feed Generator Pipeline

```typescript
class FeedGenerator {
  constructor(
    private candidateSelector: CandidateSelector,
    private rankingEngine: RankingEngine,
    private diversityEnforcer: DiversityEnforcer,
    private collectionAssembler: CollectionAssembler,
    private feedCacheManager: FeedCacheManager,
    private userContextLoader: UserContextLoader,
    private recommendationMemory: RecommendationMemory,
    private learningPathEngine: LearningPathEngine,
    private feedConstraints: FeedConstraintsConfig,
  ) {}

  async generateFeed(userId: string): Promise<FeedResponse> {
    // Check cache first
    const cached = await this.feedCacheManager.get(userId);
    if (cached && !cached.isExpired()) return cached;
    
    // Load user context
    const userContext = await this.userContextLoader.load(userId);
    
    // Phase 1: Candidate Selection
    const candidates = await this.candidateSelector.select(userContext, this.feedConstraints.candidatePoolSize);
    
    // Phase 2: Ranking (PRS computation)
    const ranked = await this.rankingEngine.rank(candidates, userContext);
    
    // Phase 3: Diversity Enforcement
    const diversified = this.diversityEnforcer.enforce(ranked, this.feedConstraints);
    
    // Phase 4: Collection Assembly
    const collections = await this.collectionAssembler.assemble(diversified, userContext);
    
    // Inject Learning Path steps at the top (SDS §16.4)
    const activePaths = await this.learningPathEngine.getActiveSteps(userId);
    if (activePaths.length > 0) {
      collections.unshift(this.buildLearningPathCollection(activePaths));
    }
    
    // Write to Recommendation Memory
    const feedGenerationId = uuidv4();
    await this.recommendationMemory.recordFeed(userId, feedGenerationId, diversified);
    
    // Phase 5: Cache
    const feed: FeedResponse = { collections, generatedAt: new Date(), feedGenerationId };
    await this.feedCacheManager.set(userId, feed, userContext.identityConfigHash);
    
    return feed;
  }
}
```

### 9.2 PRS Calculator Implementation

```typescript
class PRSCalculator {
  constructor(private weights: PRSWeightsConfig) {}

  compute(content: IntelligenceRecord, userContext: UserContext): number {
    const w = this.weights;
    
    return (
      w.alpha * this.identityRelevance(content, userContext) +
      w.beta  * this.goalRelevance(content, userContext) +
      w.gamma * this.difficultyMatch(content, userContext) +
      w.delta * this.freshnessBoost(content) +
      w.epsilon * content.qualityScore +
      w.zeta  * this.explorationBonus(content, userContext) +
      w.eta   * this.formatPreference(content, userContext) +
      w.theta * this.completionLikelihood(content, userContext) +
      w.iota  * this.pathContinuity(content, userContext) +
      w.kappa * this.repetitionPenalty(content, userContext)
    );
  }

  private identityRelevance(content: IntelligenceRecord, user: UserContext): number {
    // SDS §9.3, Phase 2: Identity Priority Weighting
    const priorityMultipliers: Record<number, number> = { 1: 1.50, 2: 1.25, 3: 1.10, 4: 1.00 };
    
    let maxRelevance = 0;
    for (const mapping of content.identityMappings) {
      const userIdentity = user.identities.find(i => i.identityId === mapping.identityId);
      if (userIdentity) {
        const multiplier = priorityMultipliers[userIdentity.priority] || 1.0;
        maxRelevance = Math.max(maxRelevance, mapping.relevanceScore * multiplier);
      }
    }
    return maxRelevance;
  }

  private freshnessBoost(content: IntelligenceRecord): number {
    // Exponential decay, half-life: 30 days
    const ageInDays = (Date.now() - content.publishedAt.getTime()) / (1000 * 60 * 60 * 24);
    const halfLife = 30;
    return Math.pow(0.5, ageInDays / halfLife);
  }

  private explorationBonus(content: IntelligenceRecord, user: UserContext): number {
    // Higher for cold-start users (SDS §19.3)
    const historyDepth = user.consumedContentIds.length;
    let explorationMultiplier: number;
    
    if (historyDepth < 10) explorationMultiplier = 2.0;
    else if (historyDepth < 50) explorationMultiplier = 1.5;
    else if (historyDepth < 200) explorationMultiplier = 1.0;
    else explorationMultiplier = 0.7;
    
    // Check if content's topics overlap with user's consumed topics
    const consumedTopics = new Set(user.consumedTopics);
    const contentTopics = content.topics;
    const novelTopics = contentTopics.filter(t => !consumedTopics.has(t));
    const noveltyRatio = contentTopics.length > 0 ? novelTopics.length / contentTopics.length : 0;
    
    return noveltyRatio * explorationMultiplier;
  }

  private repetitionPenalty(content: IntelligenceRecord, user: UserContext): number {
    // v2: Negative weight — penalty for recently shown/ignored topics
    const recentlyIgnored = user.recommendationMemory
      .filter(r => r.userAction === 'IGNORED' && r.recommendedAt > this.sevenDaysAgo())
      .map(r => r.contentId);
    
    if (recentlyIgnored.includes(content.contentId)) return -1.0;
    return 0.0;
  }
}
```

### 9.3 Diversity Enforcer

```typescript
class DiversityEnforcer {
  enforce(ranked: ScoredContent[], constraints: FeedConstraintsConfig): ScoredContent[] {
    const result: ScoredContent[] = [];
    const counters = {
      byIdentity: new Map<string, number>(),
      byTopic: new Map<string, number>(),
      consecutiveTopics: [] as string[],
      byDifficulty: new Set<string>(),
      byFormat: new Set<string>(),
      byAuthor: new Map<string, number>(),
    };
    
    const maxItems = constraints.maxItemsPerFeed;  // 20-30
    
    for (const candidate of ranked) {
      if (result.length >= maxItems) break;
      if (this.violatesDiversity(candidate, counters, constraints, result.length)) continue;
      
      result.push(candidate);
      this.updateCounters(candidate, counters);
    }
    
    return result;
  }

  private violatesDiversity(
    candidate: ScoredContent,
    counters: DiversityCounters,
    constraints: FeedConstraintsConfig,
    currentSize: number,
  ): boolean {
    const maxItems = constraints.maxItemsPerFeed;
    
    // No single identity > 50% (SDS §9.3, Phase 3)
    for (const mapping of candidate.identityMappings) {
      const count = counters.byIdentity.get(mapping.identityId) || 0;
      if (count >= maxItems * 0.5) return true;
    }
    
    // No single topic in > 3 consecutive items
    if (counters.consecutiveTopics.length >= 3) {
      const lastThreeTopics = counters.consecutiveTopics.slice(-3);
      const candidatePrimaryTopic = candidate.topics[0];
      if (lastThreeTopics.every(t => t === candidatePrimaryTopic)) return true;
    }
    
    // No single author > 25%
    const authorCount = counters.byAuthor.get(candidate.authorExternalId) || 0;
    if (authorCount >= maxItems * 0.25) return true;
    
    // No single author > 3 per feed
    if (authorCount >= 3) return true;
    
    return false;
  }
}
```

---

## 10. Learning Path Implementation

### 10.1 Path Generation (SDS §16.2)

```typescript
class LearningPathEngine {
  constructor(
    private graphStore: GraphStore,
    private learningPathStore: LearningPathStore,
    private intelligenceStore: IntelligenceStore,
    private userContextLoader: UserContextLoader,
  ) {}

  async generatePath(userId: string, goalId: string): Promise<LearningPath> {
    // 1. Extract dependency tree from Knowledge Graph
    const prerequisites = await this.graphStore.findPrerequisites(`goal:${goalId}`);
    
    // 2. Find content teaching these prerequisites
    const contentCandidates = await this.findContentForNodes(prerequisites);
    
    // 3. Topological sort (Kahn's Algorithm)
    const sorted = this.topologicalSort(contentCandidates, prerequisites);
    
    // 4. Filter by user's difficulty level
    const userContext = await this.userContextLoader.load(userId);
    const filtered = this.filterByDifficulty(sorted, userContext.inferredDifficulty);
    
    // 5. Assign roles
    const steps: PathStep[] = filtered.map((content, index) => ({
      stepId: uuidv4(),
      contentId: content.contentId,
      orderIndex: index,
      status: index === 0 ? 'UNLOCKED' : 'LOCKED',
      difficulty: content.difficulty,
      role: this.assignRole(content, index, filtered.length),
    }));
    
    // 6. Persist
    const path: LearningPath = {
      id: uuidv4(),
      userId,
      goalId,
      title: await this.generatePathTitle(goalId),
      status: 'ACTIVE',
      steps,
      progressPercent: 0,
    };
    
    await this.learningPathStore.create(path);
    return path;
  }

  private topologicalSort(contents: ContentCandidate[], prereqOrder: string[]): ContentCandidate[] {
    // Kahn's Algorithm implementation
    const inDegree = new Map<string, number>();
    const adjacency = new Map<string, string[]>();
    
    for (const content of contents) {
      inDegree.set(content.contentId, 0);
      adjacency.set(content.contentId, []);
    }
    
    // Build adjacency from REQUIRES edges
    for (const content of contents) {
      for (const prereq of content.prerequisites) {
        const prereqContent = contents.find(c => c.teachesNodes.includes(prereq));
        if (prereqContent) {
          adjacency.get(prereqContent.contentId)!.push(content.contentId);
          inDegree.set(content.contentId, (inDegree.get(content.contentId) || 0) + 1);
        }
      }
    }
    
    // Process zero-indegree nodes first
    const queue = contents
      .filter(c => (inDegree.get(c.contentId) || 0) === 0)
      .sort((a, b) => a.difficulty.localeCompare(b.difficulty));  // Easier content first
    
    const result: ContentCandidate[] = [];
    while (queue.length > 0) {
      const current = queue.shift()!;
      result.push(current);
      
      for (const neighbor of adjacency.get(current.contentId) || []) {
        inDegree.set(neighbor, (inDegree.get(neighbor) || 0) - 1);
        if (inDegree.get(neighbor) === 0) {
          queue.push(contents.find(c => c.contentId === neighbor)!);
        }
      }
    }
    
    return result;
  }

  private assignRole(content: ContentCandidate, index: number, total: number): string {
    const position = index / total;
    if (position < 0.3) return 'FOUNDATIONAL';
    if (position < 0.8) return 'CORE';
    return 'COMPLEMENTARY';
  }
}
```

---

## 11. Feed API Specification

### 11.1 Endpoints

#### `GET /api/v1/feed`

Returns the personalized feed for the authenticated user.

**Headers:**
```
Authorization: Bearer <firebase-id-token>
```

**Response (200):**
```json
{
  "collections": [
    {
      "id": "coll-001",
      "title": "Continue Learning",
      "subtitle": "Pick up where you left off",
      "type": "continueLearning",
      "items": [
        {
          "id": "uuid",
          "title": "How to Validate a Startup Idea",
          "thumbnailUrl": "https://...",
          "provider": "youtube",
          "providerId": "dQw4w9WgXcQ",
          "durationSeconds": 1200,
          "difficulty": "Intermediate",
          "estimatedTime": "20 min",
          "collectionName": "Continue Learning",
          "tags": ["startups", "validation", "product-market-fit"]
        }
      ]
    }
  ],
  "generatedAt": "2026-07-18T14:30:00Z",
  "feedGenerationId": "uuid"
}
```

**Response (304):** Feed unchanged (ETag match).

**Response (401):** Invalid or missing authentication token.

#### `POST /api/v1/feed/refresh`

Force-refreshes the feed, bypassing cache.

**Headers:**
```
Authorization: Bearer <firebase-id-token>
```

**Response (200):** Same shape as `GET /api/v1/feed`.

#### `POST /api/v1/signals/consumed`

Records a content consumption event.

**Body:**
```json
{
  "contentId": "uuid",
  "durationSeconds": 600,
  "depth": 0.75,
  "sessionOrigin": "intentional"
}
```

**Response (202):** Accepted. Signal is processed asynchronously.

#### `POST /api/v1/signals/dismissed`

**Body:**
```json
{
  "contentId": "uuid",
  "reason": "not_relevant"
}
```

#### `POST /api/v1/signals/saved`

**Body:**
```json
{
  "contentId": "uuid"
}
```

#### `GET /api/v1/health`

**Response (200):**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "layers": {
    "ingestion": "healthy",
    "intelligence": "healthy",
    "recommendation": "healthy"
  }
}
```

### 11.2 Feed Response Mapper

The API's response mapper transforms internal UCE types to the Flutter app's expected `ContentItem` shape (SDS §11.3):

```typescript
class FeedResponseMapper {
  mapToClientFeed(internalFeed: InternalFeed): ClientFeedResponse {
    return {
      collections: internalFeed.collections.map(col => ({
        id: col.id,
        title: col.title,
        subtitle: col.subtitle,
        type: col.type,  // Maps directly to Flutter CollectionType enum
        items: col.items.map(item => this.mapContentItem(item)),
      })),
      generatedAt: internalFeed.generatedAt.toISOString(),
      feedGenerationId: internalFeed.feedGenerationId,
    };
  }

  private mapContentItem(item: InternalContentItem): ClientContentItem {
    return {
      id: item.id,
      title: item.title,
      thumbnailUrl: item.thumbnailUrl || '',
      provider: item.sourceId,            // UniversalContentItem.sourceId → ContentItem.provider
      providerId: item.externalId,        // UniversalContentItem.externalId → ContentItem.providerId
      durationSeconds: item.durationSeconds || 0,
      difficulty: item.difficulty,         // IntelligenceRecord.difficulty
      estimatedTime: item.estimatedLearningTime || this.formatDuration(item.durationSeconds),
      collectionName: item.collectionName, // Assigned by Collection Assembly
      tags: item.topics.slice(0, 5),       // IntelligenceRecord.topics (subset)
    };
  }
}
```

---

## 12. Authentication & Authorization

### 12.1 API Authentication

All Feed API endpoints require Firebase Authentication tokens (SDS §22.2).

```typescript
class AuthMiddleware {
  async verify(req: Request, res: Response, next: NextFunction): Promise<void> {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing or invalid Authorization header' });
      return;
    }
    
    const token = authHeader.split('Bearer ')[1];
    
    try {
      const decoded = await admin.auth().verifyIdToken(token);
      req.userId = decoded.uid;
      next();
    } catch (error) {
      res.status(401).json({ error: 'Invalid authentication token' });
    }
  }
}
```

### 12.2 Authorization Rules

| Resource | Rule |
|---|---|
| Feed data | User can only read their own feed (`userId` from token must match) |
| User signals | User can only write their own signals |
| User profile | User can only read/write their own profile |
| Admin endpoints | Require custom claim `admin: true` on the Firebase token |
| Content data | Read-only by Layer 3; no user-facing read access |
| Intelligence data | Read-only by Layer 3; no user-facing read access |

### 12.3 Rate Limiting (SDS §22.2)

```typescript
class RateLimiter {
  // Per-user: 60 requests/minute
  private perUserLimiter = new Map<string, { count: number; windowStart: number }>();
  
  async check(userId: string): Promise<boolean> {
    const now = Date.now();
    const window = this.perUserLimiter.get(userId);
    
    if (!window || now - window.windowStart > 60_000) {
      this.perUserLimiter.set(userId, { count: 1, windowStart: now });
      return true;
    }
    
    if (window.count >= 60) return false;
    
    window.count++;
    return true;
  }
}
```

---

## 13. Configuration Management

### 13.1 Configuration Files

All configuration files live in `config/` and are loaded at service startup. They are **not** environment variables — they are structured data files that define system behavior.

| File | Purpose | Hot-reloadable? |
|---|---|---|
| `identity-catalog.json` | Identity + goal definitions | Yes (publishes `catalog.updated` event) |
| `ontology.json` | Universal Identity Ontology | Yes (publishes `ontology.updated` event) |
| `quality-weights.json` | Stage 5 scoring formula weights | Yes |
| `prs-weights.json` | PRS ranking weights (α through κ) | Yes |
| `feed-constraints.json` | Feed size, diversity rules | Yes |
| `ingestion-schedules.json` | Per-source cron + channel lists | Requires restart |
| `model-registry.json` | AI model metadata | Yes |
| `model-tiering-rules.json` | Content → model routing | Yes |
| `safety-blocklists.json` | Blocked channels/domains/keywords | Yes |
| `trust-weights.json` | Trust Score formula weights | Yes |

### 13.2 Environment Variables

```bash
# === Firebase ===
GOOGLE_CLOUD_PROJECT=sayno-production
FIREBASE_CONFIG=<auto-set by Cloud Functions>

# === AI Providers ===
OPENAI_API_KEY=<from Secret Manager>
GEMINI_API_KEY=<from Secret Manager>
ANTHROPIC_API_KEY=<from Secret Manager>

# === External APIs ===
YOUTUBE_API_KEY=<from Secret Manager>

# === Database (Growth tier) ===
DATABASE_URL=postgresql://user:pass@host:5432/uce
REDIS_URL=redis://host:6379

# === Feature Flags ===
UCE_TIER=seed                        # "seed" | "growth" | "scale"
SHADOW_EVALUATION_ENABLED=false
LEARNING_PATHS_ENABLED=false         # v2 feature flag
RECOMMENDATION_MEMORY_ENABLED=false  # v2 feature flag

# === Operational ===
LOG_LEVEL=info                       # "debug" | "info" | "warn" | "error"
FEED_CACHE_TTL_HOURS=4
CANDIDATE_POOL_SIZE=500
MIN_QUALITY_THRESHOLD=0.4
```

### 13.3 Secrets Management

All secrets are stored in **Google Cloud Secret Manager** and accessed at runtime:

```typescript
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

class SecretProvider {
  private client = new SecretManagerServiceClient();
  private cache = new Map<string, { value: string; expiresAt: number }>();

  async get(secretName: string): Promise<string> {
    const cached = this.cache.get(secretName);
    if (cached && Date.now() < cached.expiresAt) return cached.value;
    
    const [version] = await this.client.accessSecretVersion({
      name: `projects/${process.env.GOOGLE_CLOUD_PROJECT}/secrets/${secretName}/versions/latest`,
    });
    
    const value = version.payload?.data?.toString() || '';
    this.cache.set(secretName, { value, expiresAt: Date.now() + 300_000 }); // 5-min cache
    return value;
  }
}
```

---

## 14. Caching Strategy

### 14.1 Feed Cache (SDS §9.3, Phase 5)

| Property | Value |
|---|---|
| Cache key | `feed:{userId}` |
| TTL | 4 hours (configurable via `FEED_CACHE_TTL_HOURS`) |
| Invalidation triggers | Identity change, explicit refresh, significant new content |
| Seed tier | Firestore document (`feed_cache/{userId}`) |
| Growth tier | Redis key with TTL |
| Scale tier | Redis Cluster + CDN edge cache |

### 14.2 Intelligence Query Cache

Layer 3's candidate selection queries against the Intelligence Store are cached per identity configuration hash:

| Property | Value |
|---|---|
| Cache key | `candidates:{identityConfigHash}` |
| TTL | 1 hour |
| Invalidation | New `content.analyzed` event |

### 14.3 Graph Traversal Cache

Knowledge Graph traversals (prerequisites, similarity) are expensive. Results are cached:

| Property | Value |
|---|---|
| Cache key | `graph:{queryType}:{nodeId}` |
| TTL | 24 hours |
| Invalidation | `ontology.updated`, `content.retired` events |

---

## 15. Logging & Monitoring

### 15.1 Structured Logging

All logs are emitted as structured JSON using a common schema:

```typescript
interface LogEntry {
  timestamp: string;
  level: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
  service: string;        // "layer1" | "layer2" | "layer3" | "semantic" | "api"
  operation: string;      // "ingestion.fetch" | "analysis.stage2" | "feed.generate"
  contentId?: string;
  userId?: string;
  eventId?: string;
  durationMs?: number;
  error?: {
    message: string;
    stack?: string;
    code?: string;
  };
  metadata?: Record<string, unknown>;
}
```

### 15.2 Key Metrics (SDS §23.1)

Metrics are emitted to Google Cloud Monitoring (Stackdriver):

```typescript
// Metric emission example
class MetricsEmitter {
  async recordIngestion(sourceId: string, status: 'success' | 'error' | 'skipped'): Promise<void> {
    await this.writeMetric('uce/ingestion/items', 1, {
      source_id: sourceId,
      status,
    });
  }

  async recordAnalysisLatency(stage: string, durationMs: number): Promise<void> {
    await this.writeMetric('uce/intelligence/latency_ms', durationMs, {
      stage,
    });
  }

  async recordFeedLatency(durationMs: number, cacheHit: boolean): Promise<void> {
    await this.writeMetric('uce/feed/latency_ms', durationMs, {
      cache_hit: String(cacheHit),
    });
  }

  async recordAICost(modelId: string, tokenCount: number, costUSD: number): Promise<void> {
    await this.writeMetric('uce/ai/cost_usd', costUSD, {
      model_id: modelId,
    });
    await this.writeMetric('uce/ai/tokens', tokenCount, {
      model_id: modelId,
    });
  }
}
```

### 15.3 Alert Thresholds (SDS §23.1)

| Alert | Condition | Severity | Action |
|---|---|---|---|
| Ingestion stalled | Items/hour < 50% expected for 2 consecutive hours | HIGH | Page on-call |
| Analysis backlog | Pending items > 1,000 for > 30 minutes | MEDIUM | Auto-scale workers |
| Feed latency | P99 > 200ms for 5 minutes | HIGH | Investigate cache hit rate |
| AI error rate | > 3% in 15-minute window | HIGH | Check AI provider status; consider failover |
| DLQ depth | > 50 items | MEDIUM | Investigate and manually process |
| Cost anomaly | Daily AI cost > 2× rolling average | MEDIUM | Review ingestion volume; check for loops |
| Safety anomaly | Safety flag rate > 20% for new source | HIGH | Pause source adapter; review content |

---

## 16. Error Handling & Retry Strategy

### 16.1 Circuit Breaker Pattern (SDS §21.3)

```typescript
class CircuitBreaker {
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  private failureCount = 0;
  private lastFailureAt = 0;
  private readonly threshold = 5;            // Consecutive failures to trip
  private readonly resetTimeout = 60_000;    // 60 seconds before half-open

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureAt > this.resetTimeout) {
        this.state = 'HALF_OPEN';
      } else {
        throw new CircuitOpenError('Circuit is open');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }

  private onFailure(): void {
    this.failureCount++;
    this.lastFailureAt = Date.now();
    if (this.failureCount >= this.threshold || this.state === 'HALF_OPEN') {
      this.state = 'OPEN';
    }
  }
}
```

### 16.2 Retry Strategy per Operation

| Operation | Max Retries | Backoff Strategy | DLQ After |
|---|---|---|---|
| Source API fetch | 5 | Exponential with jitter (1s, 2s, 4s, 8s, 16s) | 5 failures |
| AI analysis call | 3 | Exponential (2s, 4s, 8s) + circuit breaker | 3 failures |
| Database write | 3 | Linear (500ms, 1s, 2s) | 3 failures |
| Event publishing | 3 | Exponential (1s, 2s, 4s) | 3 failures |
| Feed generation | 2 | Immediate retry, then fail to client | N/A (returns error to client) |

### 16.3 Error Classification

```typescript
enum ErrorSeverity {
  TRANSIENT,    // Network timeout, rate limit → retry
  PERMANENT,    // Invalid data, schema violation → DLQ, don't retry
  CRITICAL,     // Auth failure, config error → alert immediately
}

function classifyError(error: Error): ErrorSeverity {
  if (error instanceof RateLimitError) return ErrorSeverity.TRANSIENT;
  if (error instanceof NetworkError) return ErrorSeverity.TRANSIENT;
  if (error instanceof SchemaValidationError) return ErrorSeverity.PERMANENT;
  if (error instanceof AuthenticationError) return ErrorSeverity.CRITICAL;
  return ErrorSeverity.TRANSIENT;  // Default: assume transient
}
```

---

## 17. Testing Strategy

### 17.1 Test Structure

```
tests/
├── unit/
│   ├── normalizers/
│   │   ├── youtube-normalizer.test.ts
│   │   ├── podcast-normalizer.test.ts
│   │   └── article-normalizer.test.ts
│   ├── deduplication/
│   │   └── deduplication-engine.test.ts
│   ├── pipeline/
│   │   ├── quality-scorer.test.ts
│   │   ├── trust-score-calculator.test.ts
│   │   └── identity-mapper.test.ts
│   ├── scoring/
│   │   ├── prs-calculator.test.ts
│   │   ├── identity-relevance.test.ts
│   │   ├── freshness-boost.test.ts
│   │   └── exploration-bonus.test.ts
│   ├── diversity/
│   │   └── diversity-enforcer.test.ts
│   ├── collection/
│   │   └── collection-assembler.test.ts
│   └── learning-paths/
│       └── topological-sort.test.ts
│
├── integration/
│   ├── adapters/
│   │   ├── youtube-adapter.integration.test.ts
│   │   └── gemini-adapter.integration.test.ts
│   ├── database/
│   │   ├── content-store.integration.test.ts
│   │   ├── intelligence-store.integration.test.ts
│   │   └── graph-store.integration.test.ts
│   ├── events/
│   │   └── event-flow.integration.test.ts
│   └── api/
│       └── feed-api.integration.test.ts
│
├── e2e/
│   └── full-pipeline.e2e.test.ts
│
├── quality/
│   ├── golden-set.test.ts           # Recommendation regression tests
│   ├── identity-coverage.test.ts    # Every identity has sufficient content
│   ├── diversity-scoring.test.ts    # Feed diversity constraints
│   ├── cold-start.test.ts           # Feeds for new users
│   └── safety-regression.test.ts    # Known-bad content always blocked
│
└── fixtures/
    ├── raw-payloads/
    │   ├── youtube-video-standard.json
    │   ├── youtube-video-short.json
    │   ├── youtube-video-private.json
    │   └── podcast-episode-standard.json
    ├── intelligence-records/
    │   ├── entrepreneur-video.json
    │   └── student-article.json
    ├── user-profiles/
    │   ├── cold-start-entrepreneur.json
    │   ├── active-student.json
    │   └── multi-identity-user.json
    └── golden-sets/
        └── recommendation-golden-v1.json
```

### 17.2 Golden Set Testing (SDS §25.4)

```typescript
// Golden Set: curated (user profile → expected top-5) pairs
interface GoldenSetEntry {
  userId: string;
  profile: UserProfile;
  expectedTopContentIds: string[];  // In priority order
  expectedCollectionTypes: string[];
  forbiddenContentIds: string[];    // Known-bad content that must never appear
}

describe('Golden Set Regression', () => {
  const goldenSet: GoldenSetEntry[] = loadFixture('golden-sets/recommendation-golden-v1.json');
  
  for (const entry of goldenSet) {
    it(`generates correct feed for ${entry.userId}`, async () => {
      const feed = await feedGenerator.generateFeed(entry.userId);
      const contentIds = feed.collections.flatMap(c => c.items.map(i => i.id));
      
      // Top-5 expected content should appear in feed
      for (const expected of entry.expectedTopContentIds) {
        expect(contentIds).toContain(expected);
      }
      
      // Forbidden content must never appear
      for (const forbidden of entry.forbiddenContentIds) {
        expect(contentIds).not.toContain(forbidden);
      }
      
      // Expected collection types present
      const types = feed.collections.map(c => c.type);
      for (const expectedType of entry.expectedCollectionTypes) {
        expect(types).toContain(expectedType);
      }
    });
  }
});
```

---

## 18. CI/CD Pipeline

### 18.1 Pipeline Definition

```yaml
# .github/workflows/uce-ci.yml (or equivalent Cloud Build config)
name: UCE CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm typecheck

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm test:unit --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

  integration-tests:
    runs-on: ubuntu-latest
    needs: [unit-tests]
    services:
      firestore-emulator:
        # Firebase Emulator Suite
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm test:integration
    env:
      FIRESTORE_EMULATOR_HOST: localhost:8080

  quality-tests:
    runs-on: ubuntu-latest
    needs: [integration-tests]
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm test:quality

  deploy-staging:
    runs-on: ubuntu-latest
    needs: [quality-tests]
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - run: firebase deploy --only functions --project sayno-staging

  deploy-production:
    runs-on: ubuntu-latest
    needs: [quality-tests]
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - run: firebase deploy --only functions --project sayno-production
```

### 18.2 Quality Gates

| Gate | Threshold | Blocks Merge? |
|---|---|---|
| TypeScript compilation | Zero errors | Yes |
| ESLint | Zero errors (warnings allowed) | Yes |
| Unit test coverage | ≥ 80% line coverage | Yes |
| All unit tests pass | 100% | Yes |
| Integration tests pass | 100% | Yes |
| Golden set regression | 100% pass | Yes |
| Safety regression | 100% pass | Yes |

---

## 19. Deployment Strategy

### 19.1 Seed Tier Deployment

| Component | Platform | Deployment Method |
|---|---|---|
| All Cloud Functions | Firebase Cloud Functions v2 | `firebase deploy --only functions` |
| Firestore rules | Firebase Firestore | `firebase deploy --only firestore:rules` |
| Config files | Bundled with functions | Deployed with code |
| Secrets | Google Cloud Secret Manager | `gcloud secrets versions add` |

### 19.2 Growth Tier Deployment

| Component | Platform | Deployment Method |
|---|---|---|
| Ingestion Service | Cloud Run | Docker container from Artifact Registry |
| Intelligence Service | Cloud Run | Docker container from Artifact Registry |
| Recommendation Service | Cloud Run | Docker container from Artifact Registry |
| Semantic Service | Cloud Run | Docker container from Artifact Registry |
| Feed API | Cloud Run | Docker container from Artifact Registry |
| PostgreSQL | Cloud SQL | Managed; migrations via `db-migrate` |
| Redis | Memorystore | Managed; no deployment needed |
| Pub/Sub | Google Cloud Pub/Sub | Terraform-managed topics and subscriptions |

### 19.3 Rollback Strategy

| Scenario | Rollback Method | Time to Rollback |
|---|---|---|
| Bad function deployment | `firebase functions:delete` + redeploy previous | < 5 minutes |
| Bad database migration | Reverse migration script | < 15 minutes |
| AI model regression | Update `model-registry.json` active pointer | < 2 minutes |
| Configuration error | Revert config file, redeploy | < 5 minutes |

---

## 20. Development Roadmap & Sprint Plan

### 20.1 Phase Overview

| Phase | Name | Duration | Focus |
|---|---|---|---|
| Phase 1 | Foundation | 3 weeks | Monorepo setup, shared types, adapter interfaces, database schemas |
| Phase 2 | Ingestion | 3 weeks | YouTube adapter, normalization, deduplication, verification |
| Phase 3 | Intelligence | 4 weeks | AI pipeline, trust scoring, identity mapping, quality scoring |
| Phase 4 | Recommendation | 4 weeks | Feed generation, PRS, diversity, collection assembly, caching |
| Phase 5 | API & Integration | 2 weeks | Feed API, Flutter integration, signal collection |
| Phase 6 | v2 Features | 4 weeks | Knowledge Graph, Learning Paths, Recommendation Memory, AI Governance |
| Phase 7 | Hardening | 2 weeks | Golden set testing, load testing, monitoring, documentation |

### 20.2 Sprint Breakdown

#### Phase 1 — Foundation (Sprints 1–3)

**Sprint 1: Monorepo & Shared Types**
- Initialize monorepo with pnpm workspaces and Turborepo
- Define all TypeScript types in `packages/shared`
- Configure ESLint, Prettier, tsconfig
- Set up CI pipeline (lint + typecheck)
- Create Firestore collections and security rules

**Sprint 2: Adapter Interfaces & Event System**
- Implement all adapter interfaces
- Implement `FirestoreEventBus`
- Implement idempotency helpers
- Implement structured logging
- Write unit tests for shared utilities

**Sprint 3: Database Layer**
- Implement Firestore storage adapters for all stores
- Implement schema validation
- Implement fingerprint generation (SHA-256 + SimHash)
- Seed initial test data
- Write integration tests for storage layer

#### Phase 2 — Ingestion (Sprints 4–6)

**Sprint 4: YouTube Adapter**
- Implement `YouTubeAdapter` with cursor-based fetching
- Implement `YouTubeNormalizer`
- Implement `YouTubeTranscriptAdapter`
- Write unit tests with fixture data

**Sprint 5: Ingestion Pipeline**
- Implement `IngestionPipeline` orchestrator
- Implement `DeduplicationEngine` (exact + fuzzy)
- Implement `SchemaValidator`
- Implement ingestion Cloud Function (scheduled)
- Integration test: full ingestion from YouTube mock

**Sprint 6: Content Lifecycle**
- Implement `VerificationPipeline`
- Implement weekly dedup rerun worker
- Implement content state transitions (FRESH → AGING → STALE → RETIRED)
- Implement `content.retired` event publishing

#### Phase 3 — Intelligence (Sprints 7–10)

**Sprint 7: Stage 1 & Stage 2**
- Implement `MetadataExtractor` (Stage 1)
- Implement `AIAnalyzer` (Stage 2) with Gemini adapter
- Implement prompt template and AI output validation
- Implement `ModelTierRouter`

**Sprint 8: Stage 3 — Trust & Credibility**
- Implement `BlocklistManager`
- Implement `TrustScoreCalculator`
- Implement three-tier safety evaluation
- Write unit tests for trust score formula

**Sprint 9: Stage 4 & Stage 5**
- Implement `IdentityMapper` (deterministic graph-based mapping)
- Implement `QualityScorer` with configurable weights
- Integration test: full 5-stage pipeline

**Sprint 10: Pipeline Integration**
- Wire analysis pipeline to `content.ingested` event trigger
- Implement `content.analyzed` event publishing
- Implement re-analysis triggers (model upgrade, catalog update)
- End-to-end test: ingest → analyze → store intelligence

#### Phase 4 — Recommendation (Sprints 11–14)

**Sprint 11: Candidate Selection & Ranking**
- Implement `UserContextLoader`
- Implement `CandidateSelector`
- Implement `PRSCalculator` with all 10 factors
- Unit tests for each scoring factor

**Sprint 12: Diversity & Collections**
- Implement `DiversityEnforcer` with all constraints
- Implement `CollectionAssembler` (4 collection types)
- Unit tests with predefined ranked lists

**Sprint 13: Feed Caching & Cold Start**
- Implement `FeedCacheManager`
- Implement cold-start strategy
- Implement `FeedbackProcessor` (consumption/dismissal/save)
- Integration test: generate feed for cold-start user

**Sprint 14: Identity Evolution & Exploration**
- Implement `IdentityEvolution` (drift detection, goal saturation)
- Implement exploration vs. exploitation strategy
- Implement `identity.evolution.detected` event
- Quality tests: golden set, diversity scoring, cold start

#### Phase 5 — API & Integration (Sprints 15–16)

**Sprint 15: Feed API**
- Implement HTTP routes (feed, signals, health)
- Implement `AuthMiddleware` (Firebase token verification)
- Implement `RateLimiter`
- Implement `FeedResponseMapper`
- API integration tests

**Sprint 16: Flutter Integration**
- Implement `UceContentCatalogProvider` in Flutter app
- Wire signal emission (consumed, dismissed, saved)
- Test end-to-end: Flutter app → API → UCE → response
- Ensure `SeedContentCatalogProvider` fallback works

#### Phase 6 — v2 Features (Sprints 17–20)

**Sprint 17: Knowledge Graph (Seed Tier)**
- Implement `FirestoreGraphStore`
- Implement `GraphEnrichmentPipeline`
- Seed ontology from configuration
- Integration test: graph traversals

**Sprint 18: Learning Path Engine**
- Implement `LearningPathEngine` (path generation, topological sort)
- Implement `PathRerouter` (dynamic rerouting on content retirement)
- Implement `learningPath` collection type in feed assembly

**Sprint 19: Recommendation Memory**
- Implement `RecommendationMemory` (anti-fatigue, dismissal propagation)
- Wire to feed generation pipeline
- Implement κ (repetition penalty) factor in PRS

**Sprint 20: AI Governance**
- Implement `ModelRegistry` CRUD
- Implement `ShadowEvaluator` (parallel ingestion, comparison metrics)
- Implement automated rollback logic

#### Phase 7 — Hardening (Sprints 21–22)

**Sprint 21: Quality & Load Testing**
- Create and run golden set test suite
- Create and run safety regression suite
- Load test feed API (target: P99 < 200ms)
- Verify all monitoring dashboards

**Sprint 22: Documentation & Launch Prep**
- Finalize API documentation
- Create operations runbook
- Verify rollback procedures
- Deploy to production (Seed tier)

---

## 21. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-1 | YouTube API quota exhaustion | Medium | High | Monitor quota usage; implement backoff; apply for higher quota before Growth tier |
| R-2 | AI provider outage during ingestion | Medium | Medium | Circuit breaker + retry queue; configure backup AI provider |
| R-3 | AI model produces invalid JSON | Medium | Medium | Strict schema validation; automatic retry with simplified prompt; fallback to metadata-only intelligence |
| R-4 | Firestore cost explosion from high read volume | Low | High | Monitor read counts; implement application-level caching; migrate to PostgreSQL before cost becomes critical |
| R-5 | Firestore trigger reliability for event processing | Medium | Medium | Implement idempotency; monitor event_log for gaps; periodic reconciliation job |
| R-6 | Content safety miss (harmful content reaches user) | Low | Critical | Three-tier safety screening; admin review queue; user reporting mechanism; immediate content retirement on report |
| R-7 | Knowledge Graph traversal performance at scale | Medium | Medium | Cache traversal results; limit traversal depth; migrate to Neo4j at Scale tier |
| R-8 | Seed tier Firestore limitations for complex queries | High | Medium | Design queries to work within Firestore constraints; plan Growth tier migration early |
| R-9 | Cold start produces poor recommendations | Medium | Medium | Rely on identity + goal signals; aggressive exploration ratio; manual curation of default collections |
| R-10 | AI analysis costs exceed budget | Medium | Medium | Monitor per-item costs; use model tiering; set daily spending caps |
| R-11 | Ontology schema becomes stale or inaccurate | Medium | High | Schedule quarterly ontology reviews; track identity coverage metrics; allow admin ontology updates |
| R-12 | Flutter app compatibility issues with new API | Low | Medium | Backward-compatible API responses; version the API; keep `SeedContentCatalogProvider` as fallback |

---

## 22. Future Enhancements

These are architectural capabilities from the SDS (§26) that are not implemented in the initial release but are architecturally prepared.

| Enhancement | SDS Reference | Architectural Readiness | Implementation Notes |
|---|---|---|---|
| Podcast content source | §26.1 | ✅ Ready | Implement `PodcastRSSAdapter` + `PodcastNormalizer`. Zero pipeline changes. |
| Article/blog source | §26.1 | ✅ Ready | Implement `ArticleAdapter` + `ArticleNormalizer`. Zero pipeline changes. |
| Multi-language support | §26.1 | ✅ Ready | Language-specific prompt templates in `stage2-ai-analysis.ts`. Filter by `language` in candidate selection. |
| A/B testing framework | §26.2 | ✅ Ready | PRS weights are config. Add variant selector that loads different `prs-weights.json` per user cohort. |
| Content embedding search | §26.2 | ⚠️ Partial | Requires vector database (pgvector at Growth tier). `AIAnalysisAdapter` already supports embedding output. |
| Local/on-device inference | §26.3 | ⚠️ Interface exists | `LocalModelAdapter` interface defined but not implemented. Requires ONNX/TFLite export of analysis model. |
| PostgreSQL migration | §20.2 | ✅ Ready | Storage adapters abstract Firestore. `migrate-firestore-to-pg.ts` script planned. |
| Kafka migration | §20.2 | ✅ Ready | `EventBusAdapter` abstracts message queue. Implement `KafkaEventBus`. |

---

## 23. Implementation Review Notes

During the translation of the SDS into this implementation specification, the following ambiguities, missing details, or potential concerns were identified. These do **not** modify the architecture. They are documented here for the Lead Architect's review.

### IRN-1: Truncated Recommendation Memory Section (SDS §19.6)

**Issue:** The SDS text in §19.6 (Recommendation Memory) is truncated mid-sentence. The paragraph beginning with "Dismissal Propagation" cuts off abruptly and merges into the §20 header:

> "...If a user explicitly dismisses an item (`content.dismissed`), its topic and author IDs are recorded. S## 20. Scalability Strategy"

**Impact:** The full dismissal propagation logic is not specified. This EIS implements a reasonable interpretation: dismissed topics receive a 7-day downweight; dismissed authors receive a 14-day downweight. The dismissed content item itself is permanently excluded.

**Recommendation:** Restore the full §19.6 text in the SDS and confirm the dismissal propagation rules.

---

### IRN-2: Misnumbered Subsections in Chapter 18 (AI Strategy)

**Issue:** Chapter 18 is titled "AI Strategy" but its subsections are numbered as §14.2, §14.3, §14.4, §14.5, §14.6 instead of §18.2, §18.3, §18.4, §18.5, §18.6.

**Impact:** No functional impact. This EIS references these sections by their content description rather than number.

**Recommendation:** Renumber §14.2–§14.6 to §18.2–§18.6 in the SDS.

---

### IRN-3: Candidate Selection Query — Firestore Limitations

**Issue:** The SDS (§9.3, Phase 1) defines candidate selection as:
```
SELECT content WHERE identityMappings OVERLAPS user.identityIds AND qualityScore >= THRESHOLD
```
Firestore does not support `OVERLAPS` on nested arrays of maps (e.g., `stage4.identityMappings[].identityId IN user.identityIds`). This is a multi-value `array-contains-any` on a nested field, which Firestore does not support.

**Impact:** At Seed tier, candidate selection must use a denormalized approach. This EIS implements a workaround: a top-level `matchedIdentityIds` array field is added to the `intelligence` collection at write time, containing just the identity IDs (extracted from `identityMappings`). This field supports `array-contains-any` queries.

**Recommendation:** Acknowledge this denormalization as an acceptable Seed-tier trade-off. The Growth-tier PostgreSQL schema uses proper JSONB queries with no denormalization needed.

---

### IRN-4: SimHash Fuzzy Deduplication in Firestore

**Issue:** The SDS specifies fuzzy deduplication using SimHash with Hamming distance ≤ 3 (§7.4). Computing Hamming distance requires bitwise operations on fingerprints, which Firestore cannot perform as a query.

**Impact:** At Seed tier, fuzzy dedup must be performed in application code by fetching all fingerprints and computing distances in memory. This is acceptable at Seed scale (<5,000 items) but would not scale.

**Recommendation:** Accept this limitation at Seed tier. At Growth tier, PostgreSQL supports `BIT` types and `bit_count()` for efficient Hamming distance queries.

---

### IRN-5: Graph Traversal Performance at Seed Tier

**Issue:** The SDS (§10.2) specifies Personalized PageRank and Graph Embedding similarity search (Node2Vec/GraphSAGE). These are computationally intensive operations that require either a graph database (Neo4j) or a vector database.

**Impact:** At Seed tier with Firestore, these operations are not feasible. This EIS implements simplified graph operations at Seed tier: BFS-based prerequisite traversal and tag-overlap similarity instead of embedding similarity. Full graph operations are deferred to Growth tier.

**Recommendation:** Confirm that simplified graph operations are acceptable at Seed tier. The SDS implies this with the Neo4j reference being Scale-tier, but does not explicitly state the Seed-tier simplification.

---

### IRN-6: `content.consumed` Event — Missing `userId` in SDS §12.1

**Issue:** The SDS event catalog (§12.1) includes `userId` in the `content.consumed` payload, but the Flutter app integration section (§28.3) does not include `userId` in the payload definition for the same event. The event catalog is treated as authoritative.

**Impact:** This EIS includes `userId` in all user-originated event payloads, consistent with the event catalog.

**Recommendation:** Update §28.3 to include `userId` in all app event payloads for consistency.

---

### IRN-7: `learningPath` Collection Type Not in Existing Flutter Enum

**Issue:** The SDS (§16.4) specifies injecting learning path steps as a `learningPath` collection type. However, the existing Flutter `CollectionType` enum only contains: `continueLearning`, `curated`, `featured`, `explore`. The `learningPath` type does not exist.

**Impact:** When Learning Paths are enabled (v2), the Flutter app's `CollectionType` enum must be extended to include `learningPath`. Until then, learning path steps can be served as a `continueLearning` collection.

**Recommendation:** Plan a Flutter app update to add `learningPath` to the `CollectionType` enum before enabling the Learning Path feature.

---

### IRN-8: User History Store Technology at Seed Tier

**Issue:** The SDS (§14.2) specifies ClickHouse for the User History Store at Growth tier. At Seed tier, the technology is not explicitly stated.

**Impact:** This EIS stores user history as a Firestore subcollection (`user_history/{userId}/events/{eventId}`) at Seed tier. This is appropriate for low-volume writes but would need migration to ClickHouse or BigQuery at Growth tier.

**Recommendation:** Confirm Firestore subcollection as the Seed-tier user history store.

---

### IRN-9: Recommendation Memory Store Partitioning at Seed Tier

**Issue:** The SDS (§14.2) specifies a 12-month rolling partition for the Recommendation Memory Store (PostgreSQL). At Seed tier with Firestore, partitioning is not natively supported.

**Impact:** This EIS implements a TTL-based cleanup Cloud Function that deletes `recommendation_memory` documents older than 12 months. At Growth tier, PostgreSQL range partitioning handles this natively.

**Recommendation:** Confirm TTL-based cleanup as an acceptable Seed-tier alternative to partitioning.

---

### IRN-10: Double Horizontal Rule Before Chapter 28

**Issue:** There are two consecutive `---` horizontal rules between Chapter 27 (Engineering Decisions) and Chapter 28 (Integration with Existing SAYNO App) in the SDS.

**Impact:** Cosmetic only. No functional impact.

**Recommendation:** Remove the duplicate horizontal rule.

---

> [!NOTE]
> This specification is a companion document to the UCE Architecture & Software Design Specification (v2.0). The SDS defines the architecture. This document defines the implementation. Both are living documents that will be updated as implementation progresses. All changes to this document must be reviewed by the Lead Architect.

---

**End of Document**
