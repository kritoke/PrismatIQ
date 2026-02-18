Agents guidelines for PrismatIQ repository

- Purpose: document how agents (including automated assistants) should behave when making
  changes in this repository.

- Rule (strict): Do NOT modify `todo.md` or other project planning artifacts unless the user
  explicitly asks for a change. If the user requests an update to `todo.md`, only then modify
  `/workspaces/PrismatIQ/todo.md` and include a brief changelog entry at the top of the file.

- Scope: Changes should be Crystal-only for PrismatIQ. Do not add frontend/browser code,
  JavaScript, TypeScript, or files for other projects in this repo.

- Commit policy: Agents MUST NOT create git commits in this repository unless explicitly
  instructed by the user. Draft files or suggested patches are OK; do not push or commit.

- When unsure: If a requested change might affect other repos/projects (Quickheadlines, etc.),
  ask one targeted question before making edits. Default to keeping changes inside PrismatIQ.
