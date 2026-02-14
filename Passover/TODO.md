# Passover-m — Deferred Plans & Future Work

## Next Milestone

### Power Off / Force Stop Recovery
On `start()`, validate all persisted state:
- If `isKeySaved` is `true` in UserDefaults but the key is missing from Keychain → reset to unpaired state
- If any UserDefaults flags are in a half-written state → reset to defaults
- This makes `start()` resilient to unclean shutdowns (battery death, `kill -9`, crashes)

### State Validation on Launch
- Add a `validateState()` method called at the top of `start()`
- Check for orphaned connections or stale listener state
- Log any inconsistencies found for debugging

---

## Phase 2 — Reliability & Media

### Memory Pressure Handling
- Add `DispatchSource.makeMemoryPressureSource` observer in `NetworkManager` or `AppDelegate`
- On `.warning` / `.critical`: nil `ClipboardManager` (stops polling), log warning
- On pressure release: re-create `ClipboardManager`, rewire callbacks

### Big Clipboard Payloads
- Add max-size check before sending clipboard data (e.g., 10MB for text, configurable for images)
- For payloads over the limit: either truncate, chunk, or skip with a log
- When image clipboard is fully enabled, consider compression (JPEG for photos, PNG for screenshots)

### Message Delivery Confirmation
- Add acknowledgement for sent clipboard messages
- Optional retry queue for failed sends (with TTL — stale clipboard data shouldn't retry)

---

## Phase 3 — File Transfer

### Mid-Transfer Cleanup
- Track `fileId` in-progress state (which files are being received/sent)
- On `start()` after an unclean shutdown: delete any partial files from disk
- Ensure the next transfer starts cleanly — no stale `fileId` in memory
- Consider writing transfer state to disk so it survives crashes

### Resumable Transfers
- Use `FileStatusRequest` / `FileStatusResponse` to resume from last known `bytesReceived`
- Handle the case where the sender's file has changed since the transfer started
