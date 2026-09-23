# Railway Origin Alignment Design

## Goal

Ensure the deployed Flutter and React web clients call the Railway service that serves them, while keeping local development and Android API overrides working.

## Scope

- Resolve the Flutter web API base URL from the current browser origin when no compile-time override is provided.
- Preserve `--dart-define=API_BASE_URL=...` for Android and explicitly configured deployments.
- Replace the React standalone suite's localhost fallback with the same-origin `/api/v1` path.
- Update active deployment/test defaults from the retired Railway hostname to the new Railway hostname.
- Rebuild both tracked Flutter static bundles served by the backend.

## Non-goals

- No database or Redis changes.
- No credential changes or `.env` changes.
- No redesign of Railway's Docker image or worker topology; the existing Dockerfile and `/health` endpoint remain the deployment contract.

## Verification

- Unit-test API URL resolution for explicit overrides, web same-origin fallback, and native local fallback.
- Run Flutter tests and backend tests available in the repository.
- Confirm the built bundles contain the new behavior and no retired Railway hostname.
- Confirm the deployed `/health` endpoint remains HTTP 200 after Railway redeploys.
