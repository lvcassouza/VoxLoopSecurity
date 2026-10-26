# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- Create an issue: `gh issue create --title "..." --body-file <file>`.
- Read an issue: `gh issue view <number> --comments`, including its labels.
- List issues: `gh issue list --state open --json number,title,body,labels,comments`, with appropriate label and state filters.
- Comment on an issue: `gh issue comment <number> --body-file <file>`.
- Apply or remove labels: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- Close an issue: `gh issue close <number> --comment "..."`.

Infer the repository from `git remote -v`; `gh` does this automatically inside the clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** Set this to `yes` if the repo later treats external PRs as feature requests.

When enabled, use `gh pr` equivalents to read, list, comment on, label, and close PRs. For external PRs, include authors with `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE`. GitHub shares issue and PR numbers, so resolve an ambiguous number with `gh pr view <number>` before falling back to `gh issue view <number>`.

## Skill operations

- "Publish to the issue tracker": create a GitHub issue.
- "Fetch the relevant ticket": run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. A map is one issue labelled `wayfinder:map`, with child issues as tickets.

- Create child tickets as GitHub sub-issues when available. Otherwise, add each child to a task list in the map and put `Part of #<map>` at the top of its body.
- Label child tickets `wayfinder:<type>` (`research`, `prototype`, `grilling`, or `task`).
- Use native GitHub issue dependencies for blockers when available. Otherwise, add `Blocked by: #<n>` to the child body.
- The frontier is the first open, unassigned child in map order with no open blockers.
- Claim a ticket with `gh issue edit <n> --add-assignee @me`.
- Resolve it by commenting with the answer, closing it, and adding a context pointer to the map's Decisions-so-far.
