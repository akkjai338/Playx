# PlayX Video Player

Premium dark Flutter video player for local Android video libraries.

## Improvements in this revision

- Cooperative asynchronous storage walk that yields between filesystem entries instead of monopolizing the UI event loop.
- Single-stat metadata reads, bounded thumbnail LRU caching, and list `cacheExtent` for smoother scrolling.
- Delete from a video's three-dot menu or long press, with mandatory confirmation and immediate list removal after Android MediaStore deletion succeeds.
- Pointer-down gestures no longer wait for brightness or volume platform calls, reducing touch latency.
- Left/right double-tap seeking by 10 seconds.
- Blue Material 3 PlayX palette and lightweight loading skeleton.

## Build

Follow `AI_AGENT_INSTRUCTIONS.md`. The Android platform folder is generated with Flutter and the manifest is patched by `scripts/patch_manifest.py`.

## Important

Release signing credentials must stay outside Git. Generated `build/` output is ignored; publish the APK as a GitHub Release asset rather than committing it to source history.
