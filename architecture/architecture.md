# Architecture Map: Hackaton2026Org

**Status**: Final

| Field | Value |
|---|---|
| Org alias | `Hackaton2026Org` |
| Org type | Developer Edition (not a sandbox; sandbox rule waived by user) |
| Retrieval date | `2026-11-18` (UTC) |
| API version | `68.0` |
| Manifest | `assets/manifest/package.xml` (curated, bundled with analyze-org) |
| Analysis coverage | `full` for the dependency graph (104 Tooling API edges, 23 groups, 9 isolated components); direct review instead of subagent delegation because total evidence is small (about 6.5k tokens) |
| Subagent model | None used; primary agent analyzed directly. Fallback model would be `claude-haiku-4.5` if delegation is needed later |

## Features

No custom business feature is supported by the retrieved evidence. The org has no custom objects, Apex classes or triggers, Lightning Web Components, Aura components, tabs, or static resources. Candidate observations below are configuration only and are not features.

| Candidate | Purpose | Key metadata | Confidence | Detail |
|---|---|---|---|---|
| Case priority automation | Sets Case priority to High through a legacy workflow field update | `Workflow:Case` (`ChangePriorityToHigh`) | low (rule criteria not reviewed; active state unknown) | none yet |
| Revenue and subscription management configuration | Standard permission set groups for subscription management and sales/billing roles | `PermissionSetGroup:force__SubscriptionManagement*` (12 groups) | low (permission grants only; no related objects or settings retrieved) | none yet |
| Advanced configurator and constraint rules | Permission sets for constraint rules and experience profile management | `PermissionSet:Experience_Profile_Manager`, `PermissionSet:sfdcInternalInt__sfdc_nc_constraints_engine_deploy` | low (permission grants only) | none yet |

## Feature relationships

- None established. No candidate has a direct relationship to another candidate in the evidence.

## Cross-cutting components

- `Flow:sfdc_default_ReportExport_Protection_Flow`: default Transaction Security flow for report export protection. Status is `Draft`, so it is not active. Evidence: `force-app/main/default/flows/sfdc_default_ReportExport_Protection_Flow.flow-meta.xml`.
- `Application` set (31 apps, for example `standard__Sales`, `standard__Service`, `standard__LightningSales`): standard application shells. Evidence: `force-app/main/default/applications/`.
- `FlexiPage` utility bars (14) and `QuickAction` set (21): standard UI configuration for standard apps. Evidence: `force-app/main/default/flexipages/`, `force-app/main/default/quickActions/`.
- `Layout` set (168 files): standard page layouts. Not reviewed individually.

## Analysis coverage and gaps

| First-pass group | Reviewed evidence | Findings or gap |
|---|---|---|
| Apps and screens | `applications/` (31), `flexipages/` (14), `tabs/` (0) | Standard apps and utility bars only. No custom tabs or app. |
| Objects and business variants | `objects/` (0) | No custom or retrieved objects, fields, record types, or validation rules. Gap: standard object customizations are not visible in this retrieve. |
| Processes and automation | `flows/` (1, Draft Transaction Security flow), `workflows/` (1, Case) | No active custom flows. The Case workflow rule criteria were not reviewed (follow-up not run). |
| Feature access | `permissionsets/` (5), `permissionsetgroups/` (22) | Mostly package and standard grants. No custom access model. |
| Custom implementation | `classes/` (0), `triggers/` (0), `lwc/` (0), `aura/` (0) | None present. |
| Enabled products and packages | `sf package installed list` (1 package: `devedapp` Developer Edition v0.9); no `*Settings` types retrieved | Gap: product settings types not retrieved. No custom business metadata justified a settings follow-up. |

- Retrieved: curated manifest; 263 files in `force-app/`. The `sf project retrieve start` run succeeded.
- Failed or unavailable: none reported by the retrieve. Installed-package list succeeded (raw output saved to `architecture/.analysis/installed-packages-2026-11-17.json`).
- Excluded: no follow-up retrieves were run because no candidate required clarification.
- Remaining limitations: rule criteria, active state of the Case workflow, and the enabled state of subscription and constraint products are unknown. Metadata shows configuration, not usage.

## Assumptions

1. The org is a fresh Developer Edition org with sample or packaged configuration; the retrieved metadata reflects that (confidence: medium-high).
2. Permission sets and permission set groups do not prove assignment to users or use (confidence: high).

## Unresolved questions

1. What business process will Hackaton2026 implement? The org has no custom business metadata for the analysis to anchor to. Feature delivery will create its own metadata.
2. Should the Case priority workflow and the subscription/constraint packages be considered part of this project's scope?

## Notes
<!-- manual: content below this marker is preserved -->
