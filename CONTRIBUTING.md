# Contributing

Thanks for helping the pets. Start with [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): it explains where each decision lives, which tells you which file to change.

## Setup

macOS 14+ with either Xcode or just the Command Line Tools (`xcode-select --install`). The `Makefile` detects which you have and passes the right flags.

```sh
make test      # always run before opening a PR
make preview   # if you touched art, behaviour or rendering, look at ./previews
make demo      # try the real app on scripted PRs
```

## Common changes

- **A new setting:** add a field with a default to `Preferences`. Add it to `init(from:)` so old settings files keep loading. Read it where the decision is made (usually via `queuePolicy`, `presencePolicy` or `pullRequestQuery`), and add a control to `SettingsView`.
- **A new species, ear or tail:** see "Pixel art" in the architecture doc. The sprite tests catch clipping. Include the updated `previews/species-*.png` in your PR description.
- **A new pet activity:** add a `PetActivity` case. Give it a weight in `PetBehaviour.nextActivity`, and a pose in `YardPet.pose(at:)` (plus new `PetPose` frames if needed). `YardTests.petsDoAVarietyOfThings` checks that every pose is reachable.
- **Another forge (GitLab, Gitea…):** implement `PullRequestSource` in a new target and add a `DataSourceKind`.

## Releasing

1. Make sure `main` is green.
2. Run `git tag vX.Y.Z && git push --tags`.

The release workflow does the rest. Installed copies pick the release up within a day, or immediately via **Check for Updates**.

## Style

Match the surrounding code:

- Value types and pure functions in Core.
- Side effects only in `PRPetsGitHub` and `PRPetsApp`.
- Names that say what they mean, even when they're long.
- Doc comments that explain why, not what.

Tests describe behaviour (`dismissedPullRequestsComeBackWhenTheAuthorPushes`), not methods.
