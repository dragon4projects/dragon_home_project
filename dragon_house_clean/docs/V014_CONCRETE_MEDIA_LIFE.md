# Dragon House v0.14 — concrete media life

**Status:** CI candidate  
**Branch:** `dev/dragon-house-v014-concrete-media`  
**Base:** CI-accepted v0.13  
**Engine:** Godot 4.7.2 Compatibility

## Truth contract

A resident may browse a catalogue entry without owning/playing it.

A resident may claim to read/watch/listen only when a concrete usable object
exists:

- **READ_BOOK** — one physical book is borrowed and its exact ID is stored;
- **WATCH_FILM** — one compatible existing local film file is selected and its
  exact catalogue ID is stored;
- **LISTEN_MUSIC** — one compatible existing local audio file is selected and
  its exact catalogue ID is stored.

Entering the library/cinema/music room alone is not enough.

Autonomous resident activity never starts global UI audio/video playback. The
media panel remains explicit user-controlled playback.

## Resident state

Concrete consumption stores:

- `activity_media_category`
- `activity_media_id`
- `activity_media_title`

The normal status surface can therefore say:

- `читает «…»`
- `смотрит «…»`
- `слушает «…»`

Catalogue browsing remains distinct:

- `смотрит в каталоге «…»`
- `выбирает фильм «…»`
- `выбирает музыку «…»`

## Save/load reconciliation

At setup, concrete media state is checked again.

Safe migration:
- a legacy held physical book may recover its exact media identity from the
  book's real `holder_id`.

Never guessed:
- legacy film/music activity with no exact media ID is cancelled;
- missing film/audio bytes cancel the resident activity and release its station;
- an invalid/missing book identity is not presented as a real held object.

## Visible life

ROOM HUD now lists up to three residents currently performing in the selected
merged room using truthful status text. This replaces the old temptation to put
floating labels over residents/furniture.

Example:
`Мора — смотрит «Название»`

Additional residents are summarized as `…ещё N`.

## Pose selection

Concrete WATCH_FILM/LISTEN_MUSIC requests the authored station pose when the
station is a seat; otherwise it requests VIEW. Existing sprite-bank fallback to
IDLE remains unchanged when that pose is not available.

## Regression

Local Godot 4.7.2:

- `CONCRETE_MEDIA_V014_PASS film=id_bound track=id_bound book=physical browse=catalog_only reload_missing_file=cancelled`
- `ROOM_ACTIVITY_HUD_V014_PASS concrete_title=visible floating_labels=unused`
- `MEDIA_CATALOG_BROWSE_V08_PASS ... no_fake_consumption`
- `MEDIA_LIFECYCLE_TEST_PASS ... persisted=yes`
- `LOCOMOTION_TEST_PASS path=11 waypoints=31 lift=1`
- `SOCIAL_PAIR_TEST_PASS`
- `CORRIDOR_PASSING_V013_PASS min_distance=0.501 lane_sep=0.512 following=yield_resume`

The full LFS/Godot/Windows/macOS workflow remains final acceptance.


## Fresh-branch acceptance trigger

The v0.14 candidate was fast-forwarded to `dragon-house-fallout-fresh` after
local Godot 4.7.2 regressions and deterministic QA capture passed. This commit
exists to trigger the branch-scoped full LFS/Godot/Windows/macOS workflow; it
does not change art approval state or media catalogue contents.
