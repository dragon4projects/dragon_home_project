# Runtime content import (Iteration 2)

Use the existing HUD import button and select a JSON file. Media arrays retain the existing books/films/tracks format and merge by stable ID. Object arrays add new persistent records through the object-event gate; duplicate IDs are refused.

- `artifacts`, `cups`: `home_anchor` is room-local [x,z].
- `paintings`, `posters`: `home_anchor` is room-local [x,y,z], with rear wall z=-1.52.
- Use an existing public non-lift room ID. `preview_path` is a sibling PNG/JPEG/WebP or explicit res:// or user:// texture. Images are copied to user://imported_content.
- Only an artifact explicitly classified as small_artifact is eligible for ambient pickup. Cups and wall art are not.
- Shift+left drag changes the object home, not its canonical owner.
- Records are validated before registration. A storage/gate failure during registration may leave previously committed records intact; the UI reports the added count. Mixed media and object imports are not atomic.

Example (replace room ID with actual ID and provide image):

```json
{"posters":[{"id":"MY_POSTER_01","title":"Poster","home_room_id":"ROOM_ID","home_anchor":[0.3,1.4,-1.52],"preview_path":"poster.png"}]}
```

This is a local owner import format, not the TEEA008 geometry package format. Final shelf/table surface placement and decor validation remain separate.
