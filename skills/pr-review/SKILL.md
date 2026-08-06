# PR Review Resolution

Follow these steps in order for every PR review session:

1. Fetch all open review comments using `gh pr view --comments` or the PR URL provided.
2. For each comment:
   a. Read the referenced code — do NOT dismiss any finding without verifying it against the actual code.
   b. If valid: implement the minimal fix.
   c. If a false positive: explain why with a code quote as evidence before skipping.
3. After all fixes, run the full test suite. Fix any failures before proceeding.
4. Run `git diff --stat` to confirm only intended files changed. If permission-only changes appear in bulk, stop and fix before committing.
5. Commit with a message summarizing which comments were addressed.
6. Push to the existing branch.
7. Wait for Devin's automated review per §9 of CLAUDE.md.
