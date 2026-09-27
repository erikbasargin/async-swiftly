---
name: tdd
description: Run a review-gated test-first workflow where the agent and developer inventory and rank behavior, then advance one test through red, green, and refactor with explicit approval at every phase. Use when explicitly requested or when adding or changing application-owned behavior for which test-first development is practical.
---

# Agent-Led Test-First

Act as the implementing agent and treat the developer as an active reviewer. Either participant may edit files. When the developer changes files or gives feedback, inspect and incorporate it, revalidate the current checkpoint, and present that checkpoint again.

Each approval authorizes only the next named phase. Never infer approval for the rest of the cycle.

## 1. Agree on the Slice

Before editing, inspect the repository instructions, relevant production and test code, existing coverage, worktree state, and available test runner.

Present one concrete slice:

- Observable goal and success condition.
- System under test and architectural boundary.
- Included behavior, deferred adjacent work, and prerequisites.
- Relevant current implementation and coverage.

Stop for approval. Approval advances only to inventory design.

## 2. Agree on the Behavior Inventory

Sketch the likely implementation flow: prerequisites, guards, validation or error exits, successful path, and resulting state changes.

Search existing tests for the same action and observable outcome. Present three to five application-owned behaviors, the test that would demonstrate each, and a recommended order with its tradeoffs. Exclude tests that merely restate compiler, generated, standard-library, or dependency guarantees.

Stop for approval and ranking. If more than five behaviors are needed, split the slice and return to the scope checkpoint. If feedback changes the system under test or architectural boundary, rebuild the inventory.

## 3. Reach Reviewed Red

After the inventory order is approved, select only its first behavior. State the test's observable contract and why the current implementation should let it fail naturally.

Add or strengthen one behavioral test. Introduce at most one new test function; parameterized examples are allowed only when they share the same setup, action, and outcome. Do not add tests for later inventory items.

Add only enough production scaffold for the test to compile and execute. A missing type, compile error, crash, setup failure, unrelated regression, or globally red suite is not an acceptable red state. The selected test itself must fail on the intended behavioral assertion.

Format changed files according to the project, then run the smallest reliable test selection. If selection or parameter expansion is unreliable, broaden the run and report only what actually executed.

Present:

- The behavior and test under review.
- Changed files and any scaffold.
- The exact intended failure.
- Commands and executed, passed, failed, skipped, and not-run counts.
- Deferred inventory items.

Stop for review. Feedback keeps the workflow at red until the developer approves it. Approval authorizes committing red and beginning green.

## 4. Reach Reviewed Green

First commit the approved red state.

Before implementation, state the minimum contract: the path required by the current test, guards or branches already covered, and adjacent cases that must remain neutral or deferred.

Implement only enough behavior to satisfy the current test and preserve existing behavior. Do not implement later inventory items merely because the current structure makes them convenient. If syntax requires deferred cases to compile, give them the simplest neutral behavior compatible with existing tests.

Format changed files, run focused tests for feedback, then run the project's entire active test plan. Green requires zero failures, zero unexpected skips or not-run tests, and the expected parameterized result count. If full validation is unavailable, report the gap and remain at this checkpoint.

Inspect every new branch, boundary, transformation, and special case. Report which parts were forced by the test and flag accidental or premature behavior.

Stop for review. Approval authorizes committing green, squashing red and green into one behavior commit, and beginning refactor analysis. Do not begin another test.

## 5. Complete the Refactor Checkpoint

After green approval, commit green and squash the red and green commits into one behavior commit.

Inspect the changed production and test code for unclear names, duplication, unnecessary branches or state, misplaced responsibilities, nearby duplicate coverage, and invariants better expressed by types.

Present either:

- One small behavior-preserving refactor candidate with its value and boundary.
- A concrete reason no refactor is warranted.

Stop for approval. A refactor may improve surrounding code within the approved architectural slice and may change test names, setup, or structure only when observable cases, assertions, and coverage stay unchanged. Any changed behavior or expectation requires a new test-first cycle.

When a refactor is approved, apply only that refactor, format the changes, run the entire active test plan, and present the diff and actual results. Stop again before committing. Approval commits the refactor separately.

The refactor checkpoint may contain several separately reviewed, validated, and committed improvements. It remains open until the developer explicitly moves to the next behavior. An approved no-refactor rationale completes the checkpoint without a commit.

## 6. Reconsider Before the Next Test

After the refactor checkpoint closes, restate the completed observable behavior and reassess the remaining inventory using what the implementation revealed. Search nearby tests again and present the current three-to-five-item inventory with any revised ordering or boundary.

Classify the recommended next behavior:

- **Naturally red:** Proceed normally after approval.
- **Already covered:** Identify the existing test and consolidate or strengthen it instead of adding duplicate coverage.
- **Not application-owned:** Remove it from the inventory rather than testing a compiler, generated, standard-library, or dependency guarantee.
- **Untested but already implemented:** Explain where the premature behavior entered and present the tradeoffs among removing it in a behavior-preserving refactor, rolling back to the smallest safe point, or adding an explicitly justified starting-green characterization test.

Stop for the developer's decision. Never omit an intended application-owned behavior merely because the current code already passes it. If the system under test or architectural boundary changed, return to the scope checkpoint.

## Feedback, Blockers, and Scope Changes

Treat developer feedback as part of the current checkpoint. Inspect any developer-authored file changes before editing, preserve them, apply agreed corrections, rerun the checkpoint's required validation, and present the same checkpoint again. Feedback does not implicitly approve advancement.

If feedback changes the intended behavior, system under test, or architectural boundary, stop the current cycle and return to the appropriate scope or inventory checkpoint.

When a crash, infrastructure failure, unreliable runner, unrelated regression, or other problem prevents a valid checkpoint, perform read-only and safely contained diagnosis. Report the evidence, validation gap, and smallest viable choices. Do not modify code outside the approved slice or broaden the task without explicit approval.

Treat compile-error cascades across architecture layers as evidence that the slice may be too broad. Do not update every consumer merely to force compilation.

## Checkpoint Reports

At every stop, use this compact structure:

- **Checkpoint:** Current phase and whether it is awaiting review.
- **Artifact:** Behavior, test, implementation, refactor, or inventory under review; link changed files when useful.
- **Evidence:** Exact commands or tools used and actual executed, passed, failed, skipped, and not-run counts.
- **Open issue:** Any validation gap, premature behavior, scope concern, or deferred item relevant to the decision.
- **Approval advances to:** The single next phase and its associated Git action.

Lead with the checkpoint outcome. Keep reports concise and never combine the next checkpoint's work into the current report.
