# Backlog Routine

Scheduled routine for working through the Linear backlog of the Squash Court Analyzer project.

## What this does

1. **Fetch** all Linear issues in project `Squash-court-analyzer` with label `claude-ready` and status `Todo`
2. **Work** each issue: implement the change, commit, push to a feature branch, open a PR
3. **Log** start time, end time, duration, and a per-issue summary
4. **Clean up** remote branches that have no commits ahead of `main` (empty/stale branches) after all issues are processed
5. **Notify** via Gmail to `gerdjanvangils@gmail.com` with the run summary

## Requirements

- Linear MCP server must be connected (provides `mcp__Linear__*` tools)
- GitHub MCP server must be connected (provides `mcp__github__*` tools)
- Gmail MCP server must be connected (provides `mcp__Gmail__*` tools)

## Steps

```
START_TIME = now()

issues = linear.getIssues(
  project: "Squash-court-analyzer",
  label: "claude-ready",
  status: "Todo"
)

for each issue in issues:
  - Move issue to "In Progress" in Linear
  - Create branch: claude/<issue-id>-<slug>
  - Implement changes
  - Commit + push
  - Open PR linked to Linear issue
  - Move issue to "In Review"

stale_branches = git branches with 0 commits ahead of main
delete stale_branches (remote)

END_TIME = now()
DURATION = END_TIME - START_TIME

send Gmail summary to gerdjanvangils@gmail.com
```

## Branch cleanup criteria

A branch is considered empty/stale and eligible for deletion when:
- It exists on the remote (`origin/`)
- It is not `main` or the current session branch
- It has **0 commits ahead of `main`** (i.e., it contains no unique work)
