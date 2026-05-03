# PostgreSQL Learning Repo Prompt Pack

Copy these files into the root of your target GitHub repository.

Then ask your coding agent to start with:

```text
Read AGENT_BOOTSTRAP.md and CURRENT_STAGE.md.

Work only on the current stage.

Do not continue to the next stage.

Run validation for this stage.

Update .learning-session files.

Stop after the stage report.
```

## Recommended usage

1. Copy all files into your repo.
2. Commit them as prompt/control files.
3. Ask the coding agent to execute Stage 0 only.
4. Review the output.
5. Say `Proceed to Stage 1` only after you are satisfied.
6. Continue stage by stage.

## Operating model

- `MASTER_SPEC.md` is the constitution.
- `STAGES.md` is the roadmap.
- `CURRENT_STAGE.md` is the command.
- `STAGE_PROMPTS/` are work orders.
- `.learning-session/` is memory.
- `DONE_CRITERIA.md` is the gatekeeper.
