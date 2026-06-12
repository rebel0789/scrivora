# Scrivora Paste QA

Date: 2026-06-12

Automated paste QA is limited because it depends on real focused apps and macOS Accessibility permission. Scrivora V0.3 uses clipboard paste as the reliable path:

1. Preserve pasteboard items.
2. Put final transcript on the clipboard.
3. Activate the target app if needed.
4. Send Cmd+V.
5. Restore the previous clipboard after the configured delay when enabled.
6. If Accessibility paste cannot run, leave the transcript copied for manual paste.

Default restore delay: 600 ms.

V0.3 status:

- The insertion service copies the final transcript before attempting Command-V.
- If Accessibility paste fails, the transcript remains copied for manual paste.
- Clipboard restoration still defaults to 600 ms and is part of user-facing stop-to-insert latency.
- Full app-by-app verification is still pending after the V0.3 privacy changes.

V0.3 note:

- If Accessibility paste fails, text has already been copied to the clipboard for manual paste.
- The app now documents Accessibility usage in the first-run privacy screen and Dashboard permissions panel.
- Paste substep timing is still not implemented; Debug currently shows cleanup-to-paste and final stop-to-inserted timing.

| App | Direct AX insertion | Clipboard paste | Clipboard restore | Suggested delay | Status |
| --- | --- | --- | --- | ---: | --- |
| Notes | Not implemented as primary path | Needs manual QA | Needs manual QA | 600 ms | Pending |
| TextEdit | Not implemented as primary path | Needs manual QA | Needs manual QA | 600 ms | Pending |
| Safari | Not implemented as primary path | Needs manual QA | Needs manual QA | 600-1000 ms | Pending |
| Chrome | Not implemented as primary path | Previously worked through paste path, needs V0.2 retest | Needs manual QA | 600-1000 ms | Pending |
| Arc | Not implemented as primary path | Needs manual QA | Needs manual QA | 600-1000 ms | Pending |
| Gmail | Not implemented as primary path | Needs manual QA | Needs manual QA | 1000 ms | Pending |
| Google Docs | Not implemented as primary path | Needs manual QA | Needs manual QA | 1000 ms | Pending |
| Notion | Not implemented as primary path | Needs manual QA | Needs manual QA | 1000 ms | Pending |
| Slack | Not implemented as primary path | Needs manual QA | Needs manual QA | 600-1000 ms | Pending |
| Discord | Not implemented as primary path | Needs manual QA | Needs manual QA | 600-1000 ms | Pending |
| VS Code | Not implemented as primary path | Needs manual QA | Needs manual QA | 600 ms | Pending |
| Cursor | Not implemented as primary path | Needs manual QA | Needs manual QA | 600 ms | Pending |
| Xcode | Not implemented as primary path | Needs manual QA | Needs manual QA | 600 ms | Pending |
| Terminal | Not implemented as primary path | Needs manual QA; shell focus is risky | Prefer copy-only if command context is unclear | 1000 ms | Pending |

## Manual QA Script

For each app:

1. Open `/Applications/Scrivora.app`.
2. Select `Parakeet V2 English`.
3. Set trigger mode to Hold Control.
4. Focus a text field.
5. Hold Control.
6. Speak: `this is a paste test`.
7. Release Control.
8. Confirm final text appears.
9. Confirm prior clipboard restores after the configured delay.
10. Repeat with copy-only mode.
