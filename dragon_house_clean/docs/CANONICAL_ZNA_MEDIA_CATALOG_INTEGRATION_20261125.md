# ZNA004 media catalog integration — 2026-11-25

Owner baseline: DRAGON_HOUSE_OWNER_CORRECTED_REQUIREMENTS_20261123.md §§17–24, 52–55. Source branch art/znaechka-characters-ZNA_CHAR_NPC_20261123_001 (3f7a9f831588a342ecdaec4df40c6775cfe59f5a), source asset integration commit 3cef9bec0441724d71b738e949bdd3c10b76b8b6; source QA run 45198277472.

All four preview directory tree SHAs and both media manifest blob SHAs are identical on source and destination (baseline 8fd22a9cea100dfa019ef59fc138a570c4851e15). No duplicate binary merge or old runtime overwrite is needed. Audio tree contains exactly 203 files; every classified audio manifest path resolves to a tree entry. Source QA reports 698 decoded real PDF-derived WebP images: 203 audio, 495 unclassified, 0 film. No confirmed film list or film preview directory on source; do not classify unknown entries by guess. Source PDF gap: 234 playlist positions. Source QA is historical; binary LFS pull and engine verification on this head pending.

Implementation: additive startup import of classified preview records from existing media_preview_index.json. Existing user media records, local file links and preview overrides preserved; missing preview filled by matching ID. No unknown-video promotion, network downloads, synthetic film entries or fabricated playback. Metadata-only tracks can be inspected/assigned as cover art; autonomous listening and explicit local playback still require supported media bytes. UI loads imported resources via viewer loader. Regression covers 203 entries, no film mutation, idempotency and no fake playback.

Status: CODE_AND_MANIFEST_VERIFIED; engine tests and visual QA pending. No Actions dispatch.
