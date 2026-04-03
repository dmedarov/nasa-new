## Summary

- What changed?
- Why now?

## Scope

- In scope:
- Out of scope:

## Screenshots / Video

- Add before/after visuals for UI work.
- If not applicable, write `N/A`.

## Verification

- [ ] `xcodebuild -scheme 'NASA New' -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' build`
- [ ] Relevant automated tests passed
- [ ] Relevant manual QA passed

List the exact tests or manual checks you ran:

```text
- 
```

## Playbook Checklist

Reference: [`docs/engineering-playbook.md`](docs/engineering-playbook.md)

### Architecture Before Growth

- [ ] I kept route logic, app state, service behavior, and UI presentation in the right layer
- [ ] I did not grow a shell or router file just because it was the fastest place to wire the feature
- [ ] New logic can be tested without depending on screen rendering, or I have explained why not

### Shared Screen Primitives

- [ ] If this repeated a screen/layout pattern, I extracted or reused a shared primitive
- [ ] I did not introduce one-off spacing, width, or chrome rules without a clear reason
- [ ] iPhone and iPad hierarchy still feel like the same product

### Offline and Media State

- [ ] If this touched saved/offline/media flows, the domain state is explicit and not hidden in boolean combinations
- [ ] UI copy, badges, and actions match the underlying state model
- [ ] Fallback, degraded, and failure behavior are covered by tests or clearly called out
- [ ] Not applicable

### Localization and QA

- [ ] All new user-facing strings landed in `en`, `bg`, and `es`
- [ ] `python3 scripts/check_localizations.py` passed
- [ ] I checked fit risk for compact UI like badges, segmented controls, search/filter bars, or settings rows

### CI and Release Hardening

- [ ] If this touched CI or simulator coverage, it avoids brittle device assumptions and prints useful diagnostics
- [ ] If this touched release behavior, docs and release gates were updated where needed
- [ ] I called out any remaining risk, follow-up work, or rollout dependency

## Risks / Follow-ups

- Risk:
- Follow-up:

