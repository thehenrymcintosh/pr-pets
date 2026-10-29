# Architecture

PR Pets is a Swift package. Most of it is plain Swift with no UI framework, so it's fast to test and runs anywhere. A thin AppKit shell puts it on screen.

```
                 ┌──────────────────────────── PRPetsCore (pure) ────────────────────────────┐
 PullRequestSource│                                                                           │
 ┌─────────────┐  │  PullRequestSnapshot ──▶ ReviewQueue ──▶ PetPresence ──▶ PetRoster ──▶ Yard │
 │ PRPetsGitHub│──┼─▶   (what's open)        (3 lanes,      (who gets a      (desired)   (simulation)
 │ PRPetsDemo  │  │                          stacks)         pet, and why not)                    │
 └─────────────┘  │                              ▲               ▲                                 │
                  │                   QueuePolicy │   TriageLedger, PetIdentityRegistry, Preferences│
                  └───────────────────────────────┴─────────────────────────────────────────────────┘
                                                                          │
                     PRPetsArt: PetGenome ──▶ PetSpriteSheet (raw RGBA)    │
                                                     │                     ▼
                     PRPetsRender: YardScene + YardRenderer (CoreGraphics) ──▶ PRPetsApp (AppKit/SwiftUI)
                                                                          └──▶ pr-pets-preview (PNG/GIF)
```

## Modules

| Target | Owns | Depends on |
| --- | --- | --- |
| `PRPetsCore` | Domain types, every business decision, the pet simulation | Foundation |
| `PRPetsArt` | Turning a `PetGenome` into pixel frames; the doghouse | Core |
| `PRPetsRender` | Laying out and drawing a frame; hit testing | Core, Art, CoreGraphics |
| `PRPetsGitHub` | `PullRequestSource` over the `gh` CLI | Core |
| `PRPetsDemo` | Fixture builders and a scripted, looping `PullRequestSource` | Core |
| `PRPetsUpdates` | Version comparison, the GitHub Releases feed, verified in-place install | Foundation, CryptoKit |
| `PRPetsApp` | Windows, mouse, polling, persistence | all of the above |
| `pr-pets-preview` | Headless sprite sheets, scenario GIFs, the app icon | Core, Art, Render, Demo |

## Where decisions live

Each decision is made in exactly one place:

- **Which column a PR goes in:** `ReviewQueue.placement(of:)`. A `QueuePlacement` carries its reason (`needsMyAction(.merge)`), and the dashboard only displays it.
- **Which PRs are stacked, and in what order:** `StackIndex`. It follows base-to-head branch links within a repository. Forks never stack, and branch cycles degrade to stacks of one.
- **Whether a PR has a pet:** `PetPresence.absence(of:)` returns nil (pet out) or why not (`.suppressed`, `.approvedByOthers`). The dashboard shows the same reason.
- **What a pet looks like:** `GenomeFactory` turns a `Seed` into a genome. `PetIdentityRegistry` remembers each PR's seed, so a pet keeps its look across restarts, and a stack keeps its look when its bottom PR merges.
- **What a pet does next:** `PetBehaviour`. It holds the weights, speeds and spacing preference. `Yard` holds the mechanics (moving, timers, arrivals, holding) and makes no choices of its own.

## The yard is told, it never decides

`Yard.reconcile(with: PetRoster)` is the only way presence changes. Every reason a pet might come or go goes through that one call: a poll, mute or dismiss, double-clicking the doghouse, or a setting change. The yard then animates towards the roster: newcomers queue at the door, missing pets run home, and returning pets that are wanted again turn around.

The simulation is a value type advanced with an injected random source. Tests replay it deterministically and check properties over minutes of simulated time: pets stay inside the bounds, every departure completes, pets spread out more than random placement would, and every pose gets used.

## Pixel art

Sprites are drawn in two passes:

1. **`SpeciesAnatomy`** paints *semantic* pixels into a `PaintCanvas`. Each pixel records the body region it belongs to and the ink it uses (`region: .ear, ink: .coatShade`). The `PetSkeleton` for the current pose decides where the parts go.
2. **`CoatResolver`** turns those into colours. It applies the coat pattern per region (tabby stripes, tuxedo chest and paws, Siamese-style points), then outlines the silhouette.

Patterns therefore never need to know about poses, and new poses get every pattern for free. Tests check that no frame clips at the edge of its canvas and that grounded poses touch the ground row.

To add a species: add a case to `Species`, give it traits in `SpeciesCatalogue`, then add its head, face, ear and tail shapes in `SpeciesAnatomy`. Run `make preview` and look at `previews/species-<name>.png`.

## The overlay

The app's overlay is a transparent, borderless `NSPanel` that spans the width of the screen. It ignores the mouse except when the cursor is over a pet or the doghouse; a 30 Hz tracker toggles `ignoresMouseEvents` using the same `YardScene.hitTest` the renderer uses. The display link pauses whenever the yard is empty.

`YardRenderer` draws into any top-left-origin `CGContext`, so the app's `YardView.draw` and the preview tool's GIF frames are the same code.

## Fetching

`GhCliPullRequestSource` runs `gh api graphql` with two queries:

1. Search for open PRs with `review-requested:@me`, and for open PRs with `author:@me`.
2. If stack context is on, one aliased search per (repository, author) pair from step 1, so the whole stack comes back even when only one member involves you.

Failures become `GitHubSourceError` cases with actionable messages, shown verbatim in the dashboard.

## Persistence

Three JSON files live in `~/Library/Application Support/PR Pets/`:

- `settings.json`: `Preferences`. Decoding tolerates missing keys, so adding a setting never breaks an old file.
- `triage.json`: mutes and dismissals.
- `pets.json`: seed assignments.

Both `triage.json` and `pets.json` are pruned to open PRs on every poll. An unreadable file is moved aside as `.corrupt` and replaced with defaults.

## Releases and updates

Pushing a `v*` tag runs `.github/workflows/release.yml`. It runs the tests, then `make dist UNIVERSAL=1`, which builds arm64 and x86_64 separately and merges them with `lipo`. That works with only the Command Line Tools. The workflow then publishes `PR-Pets.zip` and `PR-Pets.zip.sha256`. These two asset names are the contract shared by the workflow, `install.sh` and `Release` in `PRPetsUpdates`.

The in-app updater, `UpdateController` wrapping `GitHubReleaseFeed` and `UpdateInstaller`, works in these steps:

1. Reads `releases/latest` anonymously.
2. Compares the release with the bundle's `CFBundleShortVersionString`.
3. Downloads the zip and checks it against the published SHA-256. A mismatch installs nothing.
4. Unzips with `ditto` and checks the bundle identifier.
5. Swaps the app with `FileManager.replaceItemAt` and relaunches.

Builds run from `swift build` rather than an installed `.app` report updates as unavailable, so a development binary is never replaced.
