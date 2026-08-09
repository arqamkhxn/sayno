# SAYNO Universal Content Engine (UCE)
## Technical Task Breakdown & Execution Plan (TTB)

**Status:** Final  
**Source of Truth:** `uce_architecture.md` (v2.0), `Engineering_Implementation_Specification.md` (v1.0)  

This document translates the architectural and engineering specifications into a sequential, actionable task breakdown optimized for AI-assisted development. It focuses on the Seed Tier (Firebase Cloud Functions + Node.js + Firestore).

---

## Development Phases
- **Phase 1: Foundation (Sprints 1-3)** - Scaffolded Monorepo, Shared Types, and Firestore Storage.
- **Phase 2: Ingestion (Sprints 4-6)** - Automated content retrieval from YouTube into Normalized Store.
- **Phase 3: Intelligence (Sprints 7-10)** - AI processing pipeline and intelligence enrichment.
- **Phase 4: Recommendation (Sprints 11-14)** - Ranking logic, candidate selection, and feed generation.
- **Phase 5: API & Integration (Sprints 15-16)** - HTTP API and Flutter integration.
- **Phase 6: v2 Features (Sprints 17-20)** - Knowledge Graph and Learning Paths.
- **Phase 7: Hardening (Sprints 21-22)** - Quality gating, regression testing, and deployment.

---

## Phase 1: Foundation

### Epic 1.1: Repository Setup & Shared Packages
#### Task 1.1.1: Initialize Turborepo Workspace
- **Task ID:** TSK-1.1.1
- **Title:** Initialize Turborepo Monorepo
- **Objective:** Create the base workspace and package structure.
- **Description:** Initialize `pnpm` workspace in `sayno-uce/`, set up `turbo.json`, ESLint, Prettier, and basic TypeScript configs. Scaffold empty package folders (`shared`, `layer1-ingestion`, `layer2-intelligence`, `layer3-recommendation`, `semantic-layer`, `api`, `functions`).
- **Dependencies:** None
- **Deliverables:** Root package configs, workspace scaffolding.
- **Acceptance Criteria:** `pnpm install` and `pnpm build` run successfully across all packages.
- **Definition of Done:** PR approved and merged.
- **Estimated Complexity:** Small
- **Estimated Effort:** 2 hrs
- **Parallelizable:** No
- **Blocking Tasks:** TSK-1.1.2
- **Testing Requirements:** Run workspace compilation commands.
- **Notes:** Use Node.js 20 LTS.

#### Task 1.1.2: Define Shared Domain Types
- **Task ID:** TSK-1.1.2
- **Title:** Define Shared Types in `packages/shared`
- **Objective:** Establish the common vocabulary across layers.
- **Description:** Create strictly-typed TypeScript interfaces for `UniversalContentItem`, `IntelligenceRecord`, `UCEEvent`, `FeedResponse`, `LearningPath`, and `ModelMetadata`.
- **Dependencies:** TSK-1.1.1
- **Deliverables:** Populated `packages/shared/src/types/`.
- **Acceptance Criteria:** All domain objects from the EIS are strictly typed and exported.
- **Definition of Done:** No compile errors; types exported via `index.ts`.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 4 hrs
- **Parallelizable:** No
- **Blocking Tasks:** TSK-1.1.3
- **Testing Requirements:** Type-check validation.

#### Task 1.1.3: Core Utilities
- **Task ID:** TSK-1.1.3
- **Title:** Implement Core Utilities (Logger, Hashers, Errors)
- **Objective:** Provide common utilities to all packages.
- **Description:** Implement structured JSON logger, SHA-256 and SimHash generators (for fingerprints), and typed error base classes.
- **Dependencies:** TSK-1.1.2
- **Deliverables:** Logger utility, hash functions, `UceErrors`.
- **Acceptance Criteria:** Hash functions are deterministic. Logger formats to JSON.
- **Definition of Done:** Unit tested and exported.
- **Estimated Complexity:** Small
- **Estimated Effort:** 3 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-2.2.1
- **Testing Requirements:** Unit tests for hash generators.

### Epic 1.2: Database & Event System
#### Task 1.2.1: Firestore Adapters (Layer 1 & 2)
- **Task ID:** TSK-1.2.1
- **Title:** Implement Firestore Storage Adapters
- **Objective:** Create data access layer for content and intelligence stores.
- **Description:** Write generic repository interfaces and Firestore implementations for `RawContentStore`, `NormalizedContentStore`, and `IntelligenceStore`.
- **Dependencies:** TSK-1.1.2
- **Deliverables:** Storage interfaces and Firestore implementations.
- **Acceptance Criteria:** Standard CRUD operations work against a local Firestore emulator.
- **Definition of Done:** Integration tests pass on the emulator.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 6 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-2.1.1
- **Testing Requirements:** Integration tests using Firebase Emulator Suite.

#### Task 1.2.2: Event Bus Implementation
- **Task ID:** TSK-1.2.2
- **Title:** Implement FirestoreEventBus & DLQ Wrapper
- **Objective:** Enable async cross-layer communication for Seed Tier.
- **Description:** Build `FirestoreEventBus` which writes to an `events` collection. Implement idempotency checking and Dead Letter Queue (DLQ) retry wrappers.
- **Dependencies:** TSK-1.1.3
- **Deliverables:** `EventBusAdapter` interface, `FirestoreEventBus`, `processWithDLQ` utility.
- **Acceptance Criteria:** Events are correctly written. DLQ wrapper catches errors and increments retry counts.
- **Definition of Done:** Unit/Integration tests pass.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 5 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-2.2.2
- **Testing Requirements:** Mock failures to verify DLQ behavior.

---

## Phase 2: Ingestion

### Epic 2.1: Adapters & Normalization
#### Task 2.1.1: YouTube Source Adapter
- **Task ID:** TSK-2.1.1
- **Title:** Implement YouTube Data API Adapter
- **Objective:** Fetch raw video metadata from YouTube.
- **Description:** Create `YouTubeAdapter` with cursor-based batch fetching handling rate limits and pagination.
- **Dependencies:** TSK-1.2.1
- **Deliverables:** `YouTubeAdapter` in `layer1-ingestion`.
- **Acceptance Criteria:** Authenticates with API and returns `FetchResult` of raw items.
- **Definition of Done:** Mock-based tests pass.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 5 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-2.2.2
- **Testing Requirements:** Unit tests using stubbed YouTube JSON.

#### Task 2.1.2: YouTube Normalizer
- **Task ID:** TSK-2.1.2
- **Title:** Implement YouTube Metadata Normalizer
- **Objective:** Convert raw YouTube data to Universal Content Schema.
- **Description:** Map raw JSON to `UniversalContentItem`. Handle missing fields safely.
- **Dependencies:** TSK-1.1.2
- **Deliverables:** `YouTubeNormalizer`.
- **Acceptance Criteria:** Accurately maps properties based on standard YouTube API payloads.
- **Definition of Done:** Passed unit tests covering normal and edge case videos.
- **Estimated Complexity:** Small
- **Estimated Effort:** 2 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-2.2.2
- **Testing Requirements:** Unit testing.

### Epic 2.2: Pipeline Orchestration
#### Task 2.2.1: Deduplication & Validation
- **Task ID:** TSK-2.2.1
- **Title:** Implement Deduplication Engine & Validator
- **Objective:** Prevent duplicate content and invalid schemas.
- **Description:** Build `DeduplicationEngine` (exact + fuzzy match) and `SchemaValidator` (using Zod or AJV).
- **Dependencies:** TSK-1.1.3, TSK-1.2.1
- **Deliverables:** Deduplication logic and validation schemas.
- **Acceptance Criteria:** Returns accurate deduplication flags and strict validation errors.
- **Definition of Done:** Comprehensive tests passing.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 6 hrs
- **Parallelizable:** No
- **Blocking Tasks:** TSK-2.2.2
- **Testing Requirements:** Unit tests mock finding existing duplicates.

#### Task 2.2.2: Ingestion Pipeline
- **Task ID:** TSK-2.2.2
- **Title:** Implement IngestionPipeline Orchestrator
- **Objective:** Wire fetch, normalize, dedup, validate, persist, and publish.
- **Description:** Main orchestrator for Layer 1. Coordinates adapters and event bus.
- **Dependencies:** TSK-1.2.2, TSK-2.1.1, TSK-2.1.2, TSK-2.2.1
- **Deliverables:** `IngestionPipeline` class.
- **Acceptance Criteria:** Full ingestion cycle succeeds end-to-end (mocked API -> stored -> event fired).
- **Definition of Done:** Event publishing logic tested successfully.
- **Estimated Complexity:** Large
- **Estimated Effort:** 8 hrs
- **Parallelizable:** No
- **Blocking Tasks:** TSK-3.1.3
- **Testing Requirements:** Integration tests over the full flow.

---

## Phase 3: Intelligence

### Epic 3.1: Analysis Components
#### Task 3.1.1: Gemini AI Adapter
- **Task ID:** TSK-3.1.1
- **Title:** Implement AI Analysis Prompt & Gemini Adapter
- **Objective:** Extract structured topics, skills from transcripts.
- **Description:** Build `GeminiAdapter`, the single-shot analysis prompt, and JSON parser with retries.
- **Dependencies:** TSK-1.1.2
- **Deliverables:** `GeminiAdapter`, prompt definitions.
- **Acceptance Criteria:** Successfully parses AI output into valid `Stage2Output` interface.
- **Definition of Done:** Reliable string to JSON parsing avoiding Markdown wrapper issues.
- **Estimated Complexity:** Large
- **Estimated Effort:** 8 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-3.1.3
- **Testing Requirements:** Integration tests with real/mocked LLM API.

#### Task 3.1.2: Trust & Quality Scorers
- **Task ID:** TSK-3.1.2
- **Title:** Implement Safety, Trust, and Quality Algorithms
- **Objective:** Compute scores and trust tiers.
- **Description:** Implement `BlocklistManager`, `TrustScoreCalculator`, and `QualityScorer` based on SDS weights.
- **Dependencies:** TSK-1.1.2
- **Deliverables:** Scoring classes.
- **Acceptance Criteria:** Correctly applies algorithms for content blocking and scoring.
- **Definition of Done:** Tests written against EIS formula variables.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 6 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-3.1.3
- **Testing Requirements:** Unit tests.

### Epic 3.2: Pipeline Orchestration
#### Task 3.1.3: Intelligence Pipeline
- **Task ID:** TSK-3.1.3
- **Title:** Wire Layer 2 AnalysisPipeline
- **Objective:** Execute 5 analysis stages.
- **Description:** Implement `AnalysisPipeline`, handle `content.ingested` event, process, store intelligence, fire `content.analyzed`.
- **Dependencies:** TSK-2.2.2, TSK-3.1.1, TSK-3.1.2
- **Deliverables:** `AnalysisPipeline`, Cloud Function trigger.
- **Acceptance Criteria:** Fully parses, scores, and stores intelligence payload.
- **Definition of Done:** Event triggers integration tested locally.
- **Estimated Complexity:** Large
- **Estimated Effort:** 8 hrs
- **Parallelizable:** No
- **Blocking Tasks:** TSK-4.2.1
- **Testing Requirements:** End to end layer integration via event payloads.

---

## Phase 4: Recommendation

### Epic 4.1: Feed Algorithms
#### Task 4.1.1: PRS Calculator
- **Task ID:** TSK-4.1.1
- **Title:** Implement PRSCalculator
- **Objective:** Calculate Personalized Relevance Score.
- **Description:** Build the 10-factor formula. Needs mockable contexts.
- **Dependencies:** TSK-1.1.2
- **Deliverables:** `PRSCalculator`.
- **Acceptance Criteria:** Score calculations strictly match SDS definition.
- **Definition of Done:** Edge cases, missing factors are handled smoothly.
- **Estimated Complexity:** Large
- **Estimated Effort:** 10 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-4.2.1
- **Testing Requirements:** Extensive unit testing.

#### Task 4.1.2: Diversity & Assembly
- **Task ID:** TSK-4.1.2
- **Title:** Implement Diversity Enforcer & Assembler
- **Objective:** Enforce feed constraints and group into collections.
- **Description:** Apply greedy re-ranking and layout logic.
- **Dependencies:** TSK-1.1.2
- **Deliverables:** `DiversityEnforcer`, `CollectionAssembler`.
- **Acceptance Criteria:** Output constraints respected (e.g. max items per author).
- **Definition of Done:** Assorted candidate sets effectively reshuffled properly.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 6 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-4.2.1
- **Testing Requirements:** Unit testing.

### Epic 4.2: Orchestration
#### Task 4.2.1: Feed Generator
- **Task ID:** TSK-4.2.1
- **Title:** Implement FeedGenerator & Cache
- **Objective:** Generate and cache the feed.
- **Description:** Wire the algorithms, candidate selector, memory store, and feed cache (Firestore for Seed).
- **Dependencies:** TSK-3.1.3, TSK-4.1.1, TSK-4.1.2
- **Deliverables:** `FeedGenerator`, `FeedCacheManager`.
- **Acceptance Criteria:** Fast path returns cache; slow path computes correctly.
- **Definition of Done:** Proper integration cache validations.
- **Estimated Complexity:** Large
- **Estimated Effort:** 8 hrs
- **Parallelizable:** No
- **Blocking Tasks:** TSK-5.1.1
- **Testing Requirements:** Cache hit/miss evaluations.

---

## Phase 5: API & Integration

### Epic 5.1: API & Client
#### Task 5.1.1: HTTP API
- **Task ID:** TSK-5.1.1
- **Title:** Implement Feed API & AuthMiddleware
- **Objective:** Expose endpoints for Flutter.
- **Description:** Create Express endpoints (`/feed`, `/signals/*`) deployed as HTTP Cloud Functions, guarded by Firebase Auth.
- **Dependencies:** TSK-4.2.1
- **Deliverables:** API routes, `AuthMiddleware`, `RateLimiter`, `FeedResponseMapper`.
- **Acceptance Criteria:** Authenticated calls return properly mapped feed JSON.
- **Definition of Done:** Secured execution returning accurate mappings.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 6 hrs
- **Parallelizable:** No
- **Blocking Tasks:** TSK-5.1.2
- **Testing Requirements:** Rest API integrations tests.

#### Task 5.1.2: Flutter Client Integration
- **Task ID:** TSK-5.1.2
- **Title:** Implement UceContentCatalogProvider in Flutter
- **Objective:** Integrate UCE into the SAYNO app.
- **Description:** Map API to Flutter `ContentCatalogProvider`, add fallback logic.
- **Dependencies:** TSK-5.1.1
- **Deliverables:** Dart implementation in Flutter codebase.
- **Acceptance Criteria:** Feed displays natively on device.
- **Definition of Done:** Render verification and caching locally.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 5 hrs
- **Parallelizable:** No
- **Blocking Tasks:** None
- **Testing Requirements:** On-device UI integration verification.

---

## Phase 6: v2 Features

### Epic 6.1: Semantic Graph
#### Task 6.1.1: Graph Store & Enrichment
- **Task ID:** TSK-6.1.1
- **Title:** Implement Firestore Graph & Ontology Seed
- **Objective:** Support semantic relationships.
- **Description:** Adjacency list collections in Firestore, `seed-ontology.ts`, `GraphEnrichmentPipeline`.
- **Dependencies:** TSK-3.1.3
- **Deliverables:** Graph store logic.
- **Acceptance Criteria:** Seeding correctly populates DAG nodes.
- **Definition of Done:** Edge traversals successful natively.
- **Estimated Complexity:** Large
- **Estimated Effort:** 10 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** TSK-6.1.2
- **Testing Requirements:** Unit testing queries on emulator.

#### Task 6.1.2: Learning Path Engine
- **Task ID:** TSK-6.1.2
- **Title:** Implement Topological Sort Paths
- **Objective:** Structured learning progress.
- **Description:** Implement Kahn's algorithm over graph nodes to produce `learningPath` collections.
- **Dependencies:** TSK-6.1.1
- **Deliverables:** `LearningPathEngine`.
- **Acceptance Criteria:** Topologies correctly generate linear progress layouts.
- **Definition of Done:** Returns expected step chains dynamically mapped.
- **Estimated Complexity:** Large
- **Estimated Effort:** 8 hrs
- **Parallelizable:** No
- **Blocking Tasks:** None
- **Testing Requirements:** Edge case cycles analysis mapping tests.

---

## Phase 7: Hardening

### Epic 7.1: QA & Deployment
#### Task 7.1.1: Golden Set Testing
- **Task ID:** TSK-7.1.1
- **Title:** Golden Set Regression Framework
- **Objective:** Automated ranking QA.
- **Description:** Regression tests verifying top-5 returned items against predefined profiles.
- **Dependencies:** TSK-4.2.1
- **Deliverables:** Quality test suite.
- **Acceptance Criteria:** Framework executes ranking against manual targets accurately.
- **Definition of Done:** Pass constraints correctly wired in CI.
- **Estimated Complexity:** Medium
- **Estimated Effort:** 4 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** None
- **Testing Requirements:** Standard verification.

#### Task 7.1.2: CI/CD Pipeline
- **Task ID:** TSK-7.1.2
- **Title:** Configure CI/CD & Deploy
- **Objective:** Automated rollout.
- **Description:** GitHub Actions running tests, typechecks, and `firebase deploy`.
- **Dependencies:** All
- **Deliverables:** CI workflow YAML.
- **Acceptance Criteria:** Pull requests build and execute properly before allowing merge.
- **Definition of Done:** Active triggers live.
- **Estimated Complexity:** Small
- **Estimated Effort:** 3 hrs
- **Parallelizable:** Yes
- **Blocking Tasks:** None
- **Testing Requirements:** Integration with live pipelines.

---

## Overall Development Roadmap

### Recommended Implementation Order
1. **Foundation:** TSK-1.1.1 → TSK-1.1.2 → TSK-1.1.3 → TSK-1.2.1 → TSK-1.2.2
2. **Ingestion Layer:** TSK-2.1.1 → TSK-2.1.2 → TSK-2.2.1 → TSK-2.2.2
3. **Intelligence Layer:** TSK-3.1.1 → TSK-3.1.2 → TSK-3.1.3
4. **Recommendation Layer:** TSK-4.1.1 → TSK-4.1.2 → TSK-4.2.1
5. **API & Client:** TSK-5.1.1 → TSK-5.1.2
6. **Advanced Features (v2):** TSK-6.1.1 → TSK-6.1.2
7. **Hardening:** TSK-7.1.1 → TSK-7.1.2

### Critical Path
`Monorepo Setup (1.1.1)` → `Storage Adapters (1.2.1)` → `Ingestion Pipeline (2.2.2)` → `Analysis Pipeline (3.1.3)` → `Feed Generator (4.2.1)` → `Feed API (5.1.1)` → `Flutter Client (5.1.2)`

### Parallel Workstreams
- **Workstream A (Data Pipelines):** Phase 2 (Ingestion) and Phase 3 (Intelligence) can run in series.
- **Workstream B (Algorithms):** Phase 4 (Recommendation Ranking) can be built concurrently with Workstream A by using mocked `IntelligenceRecord` data.
- **Workstream C (Semantic v2):** Phase 6 (Graph) can begin as soon as Phase 3 finishes, running in parallel with Phase 4/5.

### High-Risk Tasks
- **TSK-3.1.1 (Gemini Adapter):** Unreliable JSON parsing from LLMs can halt ingestion. Strict retry schemas and backoffs are critical.
- **TSK-4.1.1 (PRS Calculator):** Scoring weights are sensitive. Requires early testing via Golden Sets (TSK-7.1.1).

### Timeline Estimates
- **Estimated MVP Completion (Phases 1-5):** ~100 engineering hours.
- **Estimated Production Completion (All Phases):** ~130 engineering hours.
