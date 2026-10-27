# Project Guidelines

## Scope

Presenter Assistant is a Delphi 12.3 Athens VCL Windows application. Read
`docs/ENVIRONMENT_AUDIT.md`, `docs/PROJECT_SPEC.md`, and
`docs/ARCHITECTURE.md` before changing architecture or platform behavior.

## Architecture

Keep domain and sequence/volume logic independent of VCL, COM, HWNDs, and
hardware. The VCL/controller thread owns application state. Worker services
publish typed messages; hook and OS callbacks must remain short and must not
perform blocking COM, audio, UI, configuration, or disk work.

PowerPoint attaches to an existing instance and uses polling as the baseline.
Never fabricate slide or sequence state when observations are unknown or stale.
Input hooks are disabled by default. Hook callbacks use a safely published
binding snapshot for any synchronous suppression decision; they never await the
controller. Capture-only and unsafe/unknown states must pass through. Do not
persist HWNDs.

Use the version-1 JSON contract exactly: unknown properties and unsupported
schema versions are errors. Volume delta mode is
`Clamp(NominalVolume + DeltaOffset, 0, 100)`; use Core Audio event context to
distinguish PA-origin changes from manual changes.

## Build and test

The intended initial target is Win64. Use the installed RAD Studio environment
and record exact compiler commands and results. Follow `docs/TEST_PLAN.md`;
separate deterministic tests from runtime tests requiring PowerPoint, Core Audio,
browser windows, or presenter hardware. Do not claim runtime verification from
unit tests or from the PA-001 WMI audio probe.

## Change safety

Do not add startup registration, registry writes, administrator requirements,
automatic PowerPoint launch, or external dependencies without an explicit
architecture decision and documentation update. Preserve safe-mode and explicit
failure behavior. Redact URL query strings and unnecessary local information
from logs.
