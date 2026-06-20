# Clean Mac Install Test

This checklist verifies Scrivora from a fresh macOS user profile or separate
Mac. Do not mark it passed from an already-used development account.

## Reset Helper

Dry-run only:

```bash
Scripts/reset_local_test_state.sh
```

Delete selected local test state:

```bash
Scripts/reset_local_test_state.sh --delete --app --app-support
Scripts/reset_local_test_state.sh --delete --fluidaudio-cache
```

The script may remove:

- `/Applications/Scrivora.app`
- `/Applications/LocalVoiceFlow.app`
- `~/Library/Application Support/LocalVoiceFlow`
- `~/Library/Application Support/Scrivora`
- `~/Library/Application Support/FluidAudio/Models`

It should not remove unrelated user data.

## Test Matrix

1. Confirm no old app support folder:

   ```bash
   test ! -d "$HOME/Library/Application Support/LocalVoiceFlow"
   test ! -d "$HOME/Library/Application Support/Scrivora"
   ```

2. Confirm no existing app:

   ```bash
   test ! -d /Applications/Scrivora.app
   ```

3. Install and open:

   ```bash
   Scripts/install_app_bundle.sh
   open /Applications/Scrivora.app
   ```

4. First launch:

   - Verify the first-run privacy choice appears.
   - Select Maximum Privacy.
   - Verify transcript history is off.
   - Verify learning memory is off.

5. Permissions:

   - Grant Microphone.
   - Grant Accessibility.
   - Quit and reopen.
   - Verify permissions do not repeatedly prompt.

6. Offline Mode:

   - Enable Offline Mode before downloading a model.
   - Attempt a model download.
   - Verify the download is blocked.
   - Disable Offline Mode.

7. Model setup:

   - Download Parakeet V2 or V3.
   - Verify the downloaded model is selectable.
   - Verify the app handles a missing model without crashing.

8. Dictation:

   - Open Notes.
   - Focus a note.
   - Hold Control.
   - Speak one sentence.
   - Release Control.
   - Verify final text appears or remains copied for fallback paste.

9. Paste target behavior:

   - Start dictation in Notes.
   - Switch to TextEdit before release.
   - Verify Scrivora does not paste into the wrong app.

10. Privacy export:

    - Export a redacted debug package.
    - Confirm transcript text is absent.
    - Confirm target app metadata is absent.

11. Temp audio audit:

    ```bash
    Scripts/audit_sensitive_files.sh
    ```

    Confirm no `ScrivoraTempAudio-*.wav` files are left behind.

12. Cleanup:

    ```bash
    Scripts/reset_local_test_state.sh --delete --app --app-support
    ```

## Pass Criteria

- App launches from `/Applications/Scrivora.app`.
- First-run privacy choice appears.
- Maximum Privacy is enforced.
- Local model setup works or fails with a clear user-facing error.
- Hold Control dictation works.
- Paste fallback is safe.
- Offline Mode blocks remote downloads.
- Redacted export does not leak private text.
- Sensitive-file audit passes.

## Not Covered

- Separate physical Mac Gatekeeper behavior.
- Developer ID notarized build.
- Long battery or energy test.
