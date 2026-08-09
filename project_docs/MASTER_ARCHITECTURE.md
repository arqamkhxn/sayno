# SAYNO MASTER ARCHITECTURE

Version: 2.0

---

# Product Vision

SayNO is not a simple website blocker.

SayNO is a Digital Discipline Platform designed to help users reduce pornography consumption, social media addiction, impulsive digital behavior, and attention fragmentation.

The goal is not to remind users.

The goal is to make disciplined behavior easier than impulsive behavior.

SayNO should evolve from a blocker application into a complete digital self-control system.

---

# Mission

Help users choose long-term goals over short-term impulses.

---

# Core Philosophy

Most blockers fail because they are easy to disable.

Most productivity apps fail because they depend entirely on motivation.

Motivation is temporary.

Systems are permanent.

SayNO is built around systems.

---

# Protection Model

SayNO consists of four protection layers.

Layer 1:
Active Protection

Layer 2:
Usage Limits

Layer 3:
Commitment Contracts

Layer 4:
Accountability & Security

Each layer should strengthen the next.

---

# Design Principles

## Visual Style

Premium Minimalism

Inspired By:

* Apple
* Linear
* Notion

Avoid:

* Gaming UI
* Hacker UI
* Neon Effects
* Aggressive Animations

---

## Theme

Dark Mode Only

No Light Theme.

Reason:

* Better visual consistency
* Stronger brand identity
* Reduced maintenance

---

## Color System

Background:
#0A0A0A

Cards:
#111111

Primary Text:
#FFFFFF

Secondary Text:
#9CA3AF

Success:
#22C55E

Warning:
#F59E0B

Danger:
#EF4444

Colors should communicate status only.

Never use colors for decoration.

---

## Tone of Voice

Professional

Calm

Disciplined

Avoid:

* Shaming
* Fear tactics
* Guilt messaging
* Aggressive language

Example:

Use:

"Limit Reached"

Instead of:

"Failure Detected"

---

# Technical Architecture

## Frontend

Flutter

---

## State Management

Riverpod

---

## Navigation

GoRouter

---

## Architecture Pattern

Feature-First Architecture

Shared Component Layer

Core Utilities Layer

Reusable Design System

---

## Platform Support

Primary:

Android

Future:

iOS

---

## Local Storage

Room Database

Used For:

* Usage Tracking
* Daily Statistics
* App Daily Limits
* Contract State
* Cached Data

---

## Backend

Firebase

Services:

* Authentication
* Firestore
* Cloud Functions
* Push Notifications

---

## Security Layer

Android Accessibility Service (Native-First Protection Engine)

### Core Native Components
The protection engine runs entirely on the native Android side (Kotlin) to ensure high reliability, reboot recovery, and resistance to app killing:
1. **Config Manager (`SayNoConfigManager`)**: Reads and writes monitored packages, high-risk apps, keywords, and limit configurations directly to/from native `SharedPreferences` (`sayno_config`), which serves as the native persistence layer.
2. **Limit Manager (`SayNoLimitManager`)**: 
   - Tracks accumulated daily app usage durations in `SharedPreferences` (`sayno_usage`).
   - Implements a chronological midnight reset checker: resets usage when `today.compareTo(lastResetDate) > 0`, and detects/ignores backward clock drift manipulation.
3. **Keyword Engine (integrated in `SayNoAccessibilityService`)**:
   - Scans active window content only when the active app belongs to a high-risk application whitelist (browsers and communication apps).
   - Recursively traverses the active window's `AccessibilityNodeInfo` tree to extract all visible text and content descriptions.
   - Implements strict node recycling (`AccessibilityNodeInfo.recycle()`) to prevent system-level memory leaks.
   - Performs case-insensitive matching against user-defined keywords stored in `SayNoConfigManager`.
   - Dispatches structured detection results (`content_scan`) without passing raw traversed text across the MethodChannel.
4. **Intervention Engine (`SayNoInterventionManager`)**: 
   - Coordinates native responses when limits are reached or keywords matched.
   - For restricted content, attempts up to 2 `GLOBAL_ACTION_BACK` actions (separated by 250ms delay and window rescans) before displaying the blocking overlay.
   - For daily limits, displays the blocking overlay immediately.
5. **Overlay Manager (`SayNoOverlayManager`)**: 
   - Dynamically adds a custom, native accessibility overlay layout (`R.layout.block_overlay_layout`) directly to the system `WindowManager` via layout parameter `TYPE_ACCESSIBILITY_OVERLAY`.
   - Binds click listeners on the overlay to trigger global actions (`GLOBAL_ACTION_BACK` or `GLOBAL_ACTION_HOME`) and dismiss the overlay.
6. **Accessibility Service (`SayNoAccessibilityService`)**:
   - Acts as the central orchestrator and Android entry point.
   - Detects foreground app package transitions using `TYPE_WINDOW_STATE_CHANGED` events.
   - Listens to system broadcasts for screen state (`ACTION_SCREEN_OFF`/`ACTION_SCREEN_ON`) and keyguard unlock (`ACTION_USER_PRESENT`).
   - Implements a throttled-debounce scanner on `TYPE_WINDOW_CONTENT_CHANGED`: schedules scans with a 150ms debounce window, but triggers an immediate scan if continuous scrolling/typing runs for `1000ms` (max scan delay) to prevent starvation.

### Native ↔ Flutter Synchronization
- **Decoupled Lifecycle**: The core native protection engine has **zero runtime dependencies** on `MainActivity.instance` or the Flutter UI lifecycle. If the Flutter UI is closed or the app process is killed, the Accessibility Service continues running and enforcing limits/keywords natively.
- **MethodChannel binding**: A static `listener` callback is registered when the Flutter UI is running (`MainActivity.instance != null`) to forward status updates (`protection_enabled`/`protection_disabled`), active app transitions (`app_change`), and keyword hits (`content_scan`) to the Flutter state managers.
- **Usage Synchronization Model**:
  - **Flutter side**: Remains the single source of truth for counting/ticking active running session durations in real-time.
  - **Native side**: Remains the single source of truth for overall accumulated usage. When MethodChannel queries `getUsage` or `getAllUsage`, the native side returns only persisted totals. Flutter combines these totals with its active session timer for real-time UI updates, resolving double-counting.

---

## Time Verification

Network Time

Device time should never be trusted for contract enforcement.

---

# System Modules

Module 1:
Dashboard

Module 2:
Silent Guardian

Module 3:
Digital Health

Module 4:
Contract Engine

Module 5:
Credit Bank

Module 6:
Wallet System

Module 7:
Penalty Engine

Module 8:
Accountability Partner

Module 9:
Fortress Mode

Module 10:
Cloud Sync

---

# Development Roadmap

## Phase 1

Foundation & UI System

Objective:

Build the complete interface and design system.

---

## Phase 2

Silent Guardian

Objective:

Build real protection.

Responsibilities:

* Accessibility Service
* App Detection
* Usage Tracking
* Keyword Detection
* Blocking
* Overlay System

---

## Phase 3

Contract Engine

Objective:

Create structured discipline systems.

Responsibilities:

* Contracts
* Daily Limits
* Credit Bank
* Streak Engine
* Progress Tracking

---

## Phase 4

Commitment Economy

Objective:

Introduce consequences.

Responsibilities:

* Wallet
* Borrow Minutes
* Decision Screens
* Penalties
* Financial Analytics

---

## Phase 5

Fortress Mode

Objective:

Prevent impulsive bypass.

Responsibilities:

* Firebase Integration
* Accountability Partner
* OTP Release
* Lockdown System
* Reboot Recovery
* Cloud Sync

---

## Phase 6

AI Protection Layer

Objective:

Enhance protection using on-device intelligence.

Responsibilities:

* Sensitive Image Detection
* Advanced Content Classification
* Local AI Processing
* Intelligent Intervention

---

# Blocking Workflow

Restricted Content

↓

Accessibility Service

↓

BACK Action

↓

Rescan

↓

BACK Action

↓

Rescan

↓

Block Overlay

Fallback:

HOME Action

↓

Block Overlay

---

# Security Workflow

User Requests:

* Disable Protection
* Disable Accessibility
* Uninstall Application

↓

Security Request

↓

Delayed Approval

↓

Partner Verification

↓

Protection Disabled

---

# MVP Definition

SayNO is MVP-ready when:

* Protection Works
* Usage Tracking Works
* Daily Limits Work
* Contracts Work
* Streak System Works

Wallet and Accountability features are not required for MVP launch.

---

# AI Agent Instructions

Before implementing any feature:

1. Read this document.
2. Read PROJECT_STATUS.md.
3. Treat repository code as the source of truth.
4. Never rewrite completed phases.
5. Follow existing architecture patterns.
6. Reuse existing components before creating new ones.

This document defines the intended architecture.

The repository defines the current reality.
