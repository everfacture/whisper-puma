# Whisper Puma v1.3.0 Task Checklist

- [x] Enforce Fn hold-only runtime policy.
- [x] Keep double-tap mode for non-Fn keys with deterministic stop behavior.
- [x] Lock public model policy to `mlx-community/whisper-large-v3-mlx`.
- [x] Preserve hidden turbo rescue fallback for empty primary finals.
- [x] Keep full-final decode path for normal/long dictation accuracy.
- [x] Implement deterministic punctuation and list formatting pass.
- [x] Add bounded local polish (`qwen2.5:3b-instruct`) with adaptive timeout and drift safety checks.
- [x] Integrate direct typing first with clipboard fallback.
- [x] Refresh Settings and History UI for production readability.
- [x] Add local punctuation restoration service with confidence/sanity gating.
- [x] Add punctuation artifact cleanup pass.
- [x] Add no-terminal release packaging (`.zip` + `.dmg`) and CI release workflow.
- [x] Update README, CHANGELOG, and release notes for v1.3.0.
- [x] Build and validate app + backend compile checks.

## Deferred (Future Work)

- [ ] Improve long-form punctuation quality beyond current bounded local polish.
- [ ] Expand named-entity robustness in noisy background conditions.
- [ ] Add configurable punctuation profiles per writing style.
