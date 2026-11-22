# House-life autonomy specification v0.1

No AI, external event stream, chat scraping, or fake social biography.

Each active resident has: stable ID, owner-approved appearance link, current room, purpose/phase, needs (rest/social/curiosity), traits (reading/music), bounded learned habits, route and commitment time.

## Decision model
At action completion or due time, compute utility:
`base + need_weight + daypart_bonus + trait_bonus + habit_bonus - travel_cost + bounded variance`.
Choose only actions with existing compatible public stations/rooms and available content. The character reserves a route, travels, performs, then commits until its activity interval ends.

A camera change **never** wakes the behavior planner. Ordinary movement does not mean chat activity or consent. Private rooms are inaccessible without owner permission.

## Dayparts
Morning: coffee, work prep, reading if books exist.
Day: work/create, private rest, art and purposeful exploration.
Evening: hearth, music and film only if available; low-key social opportunities.
Night: sleep/rest; quieter interactions.
These are preferences, not rigid choreography.

## Movement classes
Resident: human-scale rooms, authored station paths later.
Manka: privileged autonomous whole-house roaming, different speed and art, not a generic idle rat.
Dragon: user observing the House; no independently roaming Dragon body.
Unidentified resident slots: dormant; they do not perform invented actions.

## Actions in current executable slice
REST/SLEEP, WORK_CREATE, GET_COFFEE, WATCH_FIRE, VIEW_ART, PURPOSEFUL_EXPLORE.
READ_BOOK, WATCH_FILM and LISTEN_MUSIC become eligible only when imported catalog entries exist. TALK_PAIR is a rare **candidate** here, not yet a genuine paired reservation: must not be presented as confirmed social dialogue. This feature requires a later two-participant scheduler.

## Media semantics to implement next
Book: one physical inventory object with ownership separate from holder and shelf; borrow/free shelf slot immediately; reading progress; return to any compatible shelf; 24-hour overdue cleanup across restarts.
Film: explicit title/file identity, available TVs + seats, watch duration/tracking, no phantom playback.
Audio: explicit track/title/file, listening devices in common and audio rooms, no silent invented playlist.
Poster/book/track previews are derived from verified catalog art or created originals with provenance, never random covers assigned to canonical media.

## Determinism and persistence
Each local autonomous plan has a bounded duration and cooldown; no re-plan every visual frame. Significant state snapshots persist to `user://`, independent of camera pose. Current prototype needs further reservation/event-log tests before being called full house-life behavior.

