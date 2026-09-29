<a id="contract"></a>
# System name

Describe the implemented purpose and observable behavior. Identify intended constraints, inferred rationale, and unresolved discrepancies explicitly.

## Implementation sources

- [module.lua](../../../exotic-space-industries-remembrance/scripts/control/module.lua)

## Ownership and flow

Name owner symbols, authoritative state, derived/cache state, and relevant consumers. Add a focused Mermaid flow or state diagram where useful.

<a id="lifecycle"></a>
## Lifecycle and invariants

Describe initialization, events, rebuild/load, validity, teardown, and cross-system invariants. Use source symbols instead of copied implementations.

<a id="tick-flow"></a>
## Timing

Describe callback tick propagation, no-tick boundaries, cadence/budgets, and origin/due/execution ticks. State explicitly when this module owns no timed work.

<a id="verification"></a>
## Verification and limits

Link existing fixtures and define scenarios that exercise the contract. Distinguish prior reports from checks performed for this change. Link deferred work and state coverage limits.
