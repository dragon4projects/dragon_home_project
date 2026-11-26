# Dense V2 live QA — not release
Run from the actual Godot project:
```sh
DRAGON_DENSE_V2_QA=1 godot --path .
```
Architecture mode is required. QA uses a separate world checkpoint and
separate wall-holder image paths. The default game and owner world are not
switched. Four private templates remain unassigned; the previously approved
hearth stays active while its V2 contacts are migrated.

The three compiled ZIP partitions contain the 19 plans measured from the
exact source archive and real model bounds. They include the explicit owner
corrections: remove planter boxes, move plants toward walls, clear overlap
pairs, move some shelving toward side walls, install two real monitors,
varied side frames, and a larger hovering gallery orb using the existing
sprite. Rear/side frame holders support explicit local image assignment.
The opening dimensions still need visual acceptance.

QA: 14 live rooms, 850/850 reachable approach routes, 2632 sampled
positions over 60 simulated seconds, no blocked positions. Three unreachable
stations were withheld (not represented as valid seats). Actual graphics
test verified 43 gallery holders, image assignment and aspect ratio, and
hover motion. The 6/4/1 artifact allocation module has atomic replacement
and serialization tests, but is not yet bound to the physical artifact state.
The adopted shape convention is 3x2, 2x2 and 1x1 cells.

RELEASE BLOCKERS: unresolved 562 source placements; library seating 12/10
instead of 16/16; full measured support surfaces; actual multi-size cube
placement; device media hooks on the new carriers and mobile-device logic;
coffee/bar support and old-object migration; full private/guest contact
qualification; hearth V2; sustained graphics performance and export pruning.
Do not remove source assets from the repository merely to reduce the export.
Use a verified dependency allowlist for exports after all rooms are active.
No Windows/macOS release builds generated at this checkpoint.
