# Contributing

## Branches

Work happens on a branch, not directly on `main`. Name it
`<type>/<short-description>`, matching the commit types below:

```
feat/status-item-tooltip
fix/graphql-rate-limit-backoff
docs/update-roadmap
refactor/beacon-state-polling
```

Open a pull request into `main` when it's ready for review — even for
solo work, this keeps history reviewable and CI (once added) gated on
the diff rather than on `main` directly.

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <short summary>

<optional body>
```

Types used in this repo:

| Type       | For |
|------------|-----|
| `feat`     | a new feature |
| `fix`      | a bug fix |
| `docs`     | documentation only (README, CLAUDE.md, comments) |
| `refactor` | code change that neither fixes a bug nor adds a feature |
| `perf`     | a change that improves performance |
| `test`     | adding or correcting tests |
| `chore`    | tooling, dependency, or config changes with no source impact |

Examples:

```
feat(graphql): batch watched-repo queries with per-repo aliases
fix(indicator): stop spinner animation when polling fails
docs: document Keychain token seeding for local runs
```

Keep the summary under ~72 characters, imperative mood ("add", not
"added"/"adds"). Use the body for the *why* when it isn't obvious from
the diff alone.

## Pull requests

- Title follows the same `type: summary` convention as commits.
- Keep PRs scoped to one `type` — a `feat` PR shouldn't carry unrelated
  `refactor` changes along with it.
- Squash-merge into `main`; delete the branch afterward.
