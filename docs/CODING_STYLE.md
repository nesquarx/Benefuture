# Coding Style & Development Methodology

Standard Operating Procedures & Engineering Guidelines for AI-Assisted Development

## 1. Professional Background & Core Philosophy

While grounded in three to five years of foundational professional software development experience, this methodology reflects a highly structured engineering posture applied when directing and collaborating with AI engineering agents.

The core architecture of this workflow is centered on **Full-Circle Testing**, operating directly at the intersection of Behavior-Driven Development (BDD) and Test-Driven Development (TDD).

## 2. Collaborative Problem Formulation & Methodology Dialogue

- **Outcome Specification:** Every development task initiates by explicitly defining the expected functional outcome, user-facing behavior, and system constraints.
- **Methodological Proposal & AI Agency:** The human principal articulates their baseline understanding of the technical architecture and implementation strategy to be applied. However, the AI agent is explicitly empowered and expected to critique the proposed approach, surface edge cases, and suggest superior, more efficient, or more maintainable architectural alternatives before implementation begins.

## 3. The Red Phase: Dual-Suite Pre-Build Test Verification

- Before drafting or modifying any application code, the AI operates under a **Red QA Persona** to author two distinct test suites:
  1. **Functional Acceptance Suite (What Must Work):** Captures the expected target behavior, functional user paths, and valid input contracts that the system must satisfy.
  2. **Adversarial & Negative Edge-Case Suite (What Must Break / Fail Gracefully):** An exhaustive suite specifically designed to attack and break the system across the full spectrum of inputs. Tests what must not work, verifying rejection of malformed payloads, out-of-bounds parameters, type violations, null/undefined states, race conditions, and boundary exceptions.
- **Verified Failing State:** Prior to initiating any implementation code, the first test suite must be executed against the current codebase to verify that new assertions fail as expected. Implementation is strictly prohibited until this failing baseline is confirmed.

## 4. Incremental Build & Selective Regression Loops

- **Modular Incrementalism:** Implementation proceeds in small, modular, verifiable increments rather than broad, monolithic code alterations. Once tests are verified, the agent adopts a **Minimalist Implementer Persona** to write the cleanest code that satisfies the assertions.
- **Short Incremental Test Passes (Selective Impact Testing):** During active development, increments run a compact, selective test suite targeting only the modified code, direct dependencies, and immediate round-trip behavioral assertions. This maintains rapid turnaround speed and avoids execution latency bottlenecks.
- **Continuous Invariant Checking:** Incremental passes verify that active local invariants hold before proceeding to subsequent modules.

## 5. Live Environment Testing & Diagnostic Verification

- **The "Not Done Until Live" Rule:** Static code completion and isolated unit test passes do not constitute a finished deliverable. Code is never considered complete based solely on written specifications.
- **Live Diagnostic Execution:** The application must be launched live in a realistic runtime environment. Automated live testing is executed using an appropriate framework-specific diagnostic test runner (with Playwright serving as a primary example for web applications), programmatically exercising all user-facing functions, navigation paths, API handshakes, and state transitions of what was built.
- **Hybrid Deterministic Visual UI Verification:** When user interfaces, styling, or layouts are involved:
  - *Deterministic Visual Regression:* The headless live runner captures viewport screenshots and runs automated pixel-diff algorithms against golden baseline captures.
  - *Semantic Review Pass:* If a pixel delta occurs, the multimodal model evaluates the visual diff to confirm whether the change represents intended design evolution or an unintended visual/CSS regression.
- **Full Historical Regression Gate:** Before a coding round officially concludes and receives a "PASS" rating, the system executes the complete, 100% historical regression suite across all past and current test cases, guaranteeing zero systemic regression.

## 6. Automated Build Harness & Token Efficiency

- **Native Pipeline Integration:** All unit testing, regression suites, and live diagnostic test harnesses must be embedded directly within the project's build configuration and automated test runners.
- **Token Conservation:** The AI agent must not waste prompt context tokens or computational budget repeatedly invoking manual test commands or dumping verbose passing test outputs into chat.
- **Exception-Driven Alerts:** The test harness operates silently in the background during builds. The AI agent is alerted exclusively when an assertion fails or a regression occurs, surfacing the targeted stack trace, failing expectation, and exact failure context so it can diagnose the issue and apply an immediate fix.

## 7. Two-Part Planning Protocol & Asymmetric Context Ingestion

The AI engineering agent is required to maintain a centralized, two-part project plan document (or partitioned planning file):

- **Part 1: Historical Log (What Was Done):** A cumulative record of completed increments, implemented features, and resolved milestones.
  - *Selective Reference Rule (Token Conservation):* To preserve context window capacity, the AI agent does not read the completed history on routine turns. It accesses this record strictly as a reference when specifically needed (e.g., investigating regressions, checking past architectural decisions, or tracing dependencies).
- **Part 2: Prospective Trajectory (Future Plan, Ideas & Direction):** The forward-looking roadmap detailing upcoming milestones, conceptual ideas, architecture evolution, and strategic direction.
  - *Mandatory Pre-Turn Ingestion & Conflict Prevention:* At the beginning of **every turn**, the AI agent must read the future plan and general project direction. This ingestion ensures that immediate code increments, interface contracts, data models, and architectural decisions do not contradict, constrain, or block planned future requirements, guaranteeing forward-compatibility rather than painting the codebase into a corner.
  - *Fuzzy Scope Clamp & Opportunistic Low-Lift Inclusion:* The agent must not unilaterally build future features from Part 2. However, the scope clamp is fuzzy: if a current instruction directly aligns with or is closely tangential to a future goal, and incorporating that future idea represents an **extremely low lift** (minimal incremental complexity/risk), the agent is permitted and encouraged to incorporate it.
  - *Dynamic Milestone Promotion:* Whenever any current instructions or low-lift additions complete an item from Part 2, the AI agent immediately moves that item into Part 1 (What Was Done), maintaining an accurate, real-time reflection of project state.

## 8. Documentation Style & Technical Writing Guidelines

Documentation within code comments, architectural specifications, and technical notes must adhere to a clean, atemporal standard:

- **Pithy & High-Density:** Reflect the principal's communication style—informative, precise, and free of gratuitous verbosity or filler.
- **First-Time Reader Stance:** Always write documentation assuming the reader is encountering the codebase for the very first time. Documentation must be fully self-contained, explaining how the system works without relying on implicit historical context or unstated assumptions.
- **Atemporal State Focus (Eliminating Decision Churn):** Strictly avoid documenting the conversational, prompt-by-prompt choreography of how the code reached its current state (e.g., avoid comments like *"this was previously implemented as X, but then in prompt 2 we removed red instances"*). Document the present architectural reality and active behavior, not the discarded steps of earlier decisions.
- **Documenting Invariants & Counterfactuals, Not History:** Explicitly document operational invariants and counterfactual risks (e.g., *"If this step is skipped, condition X fails"* or *"Omitting this guard causes memory leak Y"*). Capture the finalized architectural principle and systemic constraints, omitting the narrative history of how that lesson was discovered during development.

## 9. Debugging Protocol & Root-Cause Validation (Zero-Patching Mandate)

When defects, unexpected behaviors, or test failures arise, troubleshooting follows an uncompromising, evidence-based diagnostic cycle designed to eliminate agentic thrash:

- **Prohibition on Speculative Patching:** Modifying application logic, refactoring code, or attempting speculative trial-and-error fixes while a defect's root cause remains unverified is strictly prohibited. An agent must never "try a fix to see if it works."
- **Hypothesis Formulation:** Before touching any code, the agent must formulate and explicitly articulate a testable hypothesis regarding the failure mechanism (e.g., *"Hypothesis: Variable X at line 42 evaluates to null because async handler Y resolves after the DOM render event"*).
- **Console Method as Root-Cause Validation:** Targeted, high-signal console logs are injected specifically to prove or disprove the hypothesis. The live diagnostic runner (e.g., Playwright or runtime test harness) is executed to capture the live console telemetry. Code modification is authorized **only after** the captured logs conclusively confirm the root cause. If disproven, the hypothesis is discarded, and the agent re-instruments without editing application logic.
- **Surgical Implementation & Log Hygiene:** Once the root cause is proven, the agent applies the minimal surgical fix required to resolve the issue. Upon verification that tests pass, all temporary troubleshooting console statements must be immediately excised from the codebase.
- **Flag-Gated Observability (DEBUG Mode):** For permanent diagnostic visibility into core data handling, complex mathematical transforms, or critical state transitions, structured logging must be permanently embedded behind a configurable diagnostic flag (e.g., `DEBUG=true`). When enabled, this flag surfaces rich operational telemetry on demand; when disabled, it remains completely silent without runtime overhead or log pollution.

## 10. Meta-Cognitive Governance: The Orchestrator-Worker Dynamic

This methodology governs the interaction between the principal, the digital twin, and specialized coding models:

- **The Digital Twin as Lead Architect / Orchestrator:** The Digital Twin does not typically perform line-by-line syntax writing. Instead, it operates at the strategic layer as the Engineering Manager and Technical Lead, orchestrating and reviewing specialized coding agents (e.g., Claude Code, Qwen-Coder).
- **SOP Enforcement & Audit:** The Digital Twin holds this specification in its canonical axiomatic graph (`corpus/axioms/N:CODING_METHODOLOGY.md`) and enforces its tenets across all worker agents: demanding dual-suite pre-build tests, auditing PRs for zero-patching compliance, supervising live diagnostic runs, and maintaining the two-part project plan.
