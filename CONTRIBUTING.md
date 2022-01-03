Work-in-progress.

How to create a PR
---
Keep commits atomic

1 commit or very few in each PR. Each PR should be doing only 1 thing

Don't introduce unnecessary, unintentional changes, especially adding/removing of whitespace unless it's really part of the PR

Write a clear 1-sentence commit message explaining what the commit is for. If there are important details such as the rationale for doing things in a certain way, add additional lines. `git log --pretty=oneline` should make sense

Draw attention to anything that the reviewer should look out for

If it's a simple UI change, include screenshots like this https://github.com/AlphaWallet/alpha-wallet-ios/pull/3399

If the PR closes an issue, use [GitHub keywords](https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue) (eg. Closes #123) so GitHub will automatically close the issue when the PR is merged.

Commits introduced by PR should be based on the current `master`. Sometimes reviewers will request author to rebase master (`git rebase master`) if `master` has moved significantly since

If the PR is still a work-in-progress, make it a draft (GitHub feature), or use the "WIP. Don't Merge" label

If changes are needed after review, commit changes, rebase into a single (or a few) commits and force push

Code Style
---
CamelCase, including abbreviations (some older code might not observe this)

Leave empty lines empty, without whitespace/indentation

Group private let/var before others in a type

Don't include unnecessary `self.` references. It suggests that `self` is strongly held in a closure.

Avoid using `switch-default`

Others
---
Hide changes behind a flag in `Features.swift` if the change isn't ready yet but should be merged first. For example, maybe it needs more testing, but would be benefit to merge earlier to avoid merge conflicts.

How to Add a New Chain
---
1. Open RPCServers.swift
2. Add a new case to the enum
3. Build and fix the errors. Do not use `switch-default:`
