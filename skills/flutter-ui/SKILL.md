---
name: flutter-ui
description: Build or update MediVoice Flutter screens and shared widgets while preserving its accessibility and linear scan workflow.
---

# MediVoice Flutter UI

Read `AGENTS.md`, `docs/PROJECT_SPEC.md`, and `docs/SAFETY.md`. Keep widgets presentational and send workflow actions to `ScanController`.

- Use the existing high-contrast theme, readable text, 48dp minimum targets, semantic labels, and one primary action per state.
- Preserve the linear Home → capture/review → processing → confirmation → result flow.
- Reuse shared buttons, error panels, disclaimers, and medicine cards.
- Show loading, empty, retry, and rescan states explicitly. Never hide safety warnings to reduce clutter.
- Do not add business logic, live-provider calls, persistence, a routing framework, or a second state-management system.

Run formatting, analyzer, widget tests, and a text-scaling/TalkBack check for material UI changes.
