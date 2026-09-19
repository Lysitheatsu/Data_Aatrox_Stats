# Mock-data development

Version 1 workflows can be developed before the client endpoints are ready.
The frontend reads shared product data through `AppDataProvider`, which receives
an `AppRepository`. The default `mockRepository` has the same asynchronous
`load`, `save`, and `reset` boundary that a remote implementation will use.

## Current behaviour

- Web persists mock changes in `localStorage` under `elly.mock-data.v1`.
- Native keeps mock changes for the current app session.
- The map shows connected people with live sharing and coordinates as circular
  default profile icons, and initially frames them above the journey panel. Select a map icon or
  Live Sharing avatar to open the person sheet and centre their location at street-level zoom. A bottom card displays their name,
  location, and update time; swipe down or close it to return to the journey panel. The sheet uses the original
  location-sharing spring entrance and 220 ms slide-out animation. These positions are static fixtures.
- Assistant suggestions live inside the relevant map and journey screens. The
  separate ELLY AI tab was removed after that product area was folded into the
  rest of the app. Keep future assistant work contextual instead of restoring a
  standalone tab.
- Emergency actions run a visibly labelled simulation by default and never
  claim that emergency help was contacted.
- Set `EXPO_PUBLIC_DATA_SOURCE=api` only when testing a configured emergency
  dispatch backend. This permits the existing voice trigger to call the API;
  manual SOS still requires confirmation.

Call `resetDemo()` from a future developer settings screen to restore fixtures.

## Replacing fixtures with client endpoints

1. Add a remote implementation of `AppRepository` in `frontend/src/data/`.
2. Map endpoint responses to the types in `frontend/src/data/types.ts`.
3. Select the repository at the app composition root (`frontend/App.tsx`).
4. Keep screen components unchanged; they consume `useAppData()`, not fixtures.
5. Add contract tests using captured client responses before enabling the remote
   repository by default.

Fine-grained endpoint calls can later be added to the repository interface as
the client contracts settle. Mutations currently update the complete local data
snapshot to keep the temporary implementation small and predictable.
