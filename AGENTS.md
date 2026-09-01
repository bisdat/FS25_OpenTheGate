# Codex Working Rules

## Repository workflow

- Treat `main` as the last accepted and tested state; do not commit directly to `main`.
- Make changes on a short-lived branch and open a pull request for review.
- Do not merge pull requests automatically unless explicitly instructed.

## Release constraints

- Do not change the mod version unless explicitly instructed.
- The current release candidate version is `1.0.0.0`.
- For the initial `1.0.0.0` release, do not add changelog text to localized descriptions.
- Keep `descVersion="111"` unless explicitly instructed otherwise.
- Preserve CDATA blocks in `modDesc.xml`.
- Do not modify `icon_openTheGate.dds` unless explicitly instructed.

## Implementation rules

- Keep all debug flags disabled by default.
- Do not introduce hardcoded gate or placeable names when behaviour-based detection can solve the problem generically.
- Prefer native FS25/GIANTS behaviour, including `AnimatedObject:setDirection(0)`, over forced animation driving.
- Preserve server-authoritative gate selection and toggling, and client-side horn gesture detection.
- Use the complete vehicle combination, including attached implements and trailers, as the basis for targeting geometry.
- Preserve close-gate priority behaviour for large vehicles.
- Keep fixes generic and constructive; do not tailor them only to one reported fixture.

## Validation

Before completing a change:

- Run Lua syntax checks on all Lua files.
- Run `git diff --check`.
- Inspect `git status`.
- Do not leave temporary files, logs, ZIPs, test artefacts, or OS files in the repository.

## Provenance/licensing

- Do not modify `LICENSE` unless explicitly instructed.
- Preserve MPL-2.0 SPDX headers in Lua source files.
- Preserve the README provenance wording that Open The Gate is an independent implementation inspired by Honk To Open The Gates by 50keda.
- Do not describe Open The Gate as derived from, adapted from, or based on 50keda's source code.
