# Security review

Reviewed the custom plugin, native overlay, avatar loading and updater for a single local Mac user. This is a code review, not an independent penetration test or a guarantee of no vulnerabilities.

## Fixed before publication

- Avatar downloads now stop at 1 MB while streaming. Redirects are checked before following them and remain restricted to HTTPS Discord image hosts. Cookies are disabled. Images are checked for dimensions and only the first frame is decoded, preventing small compressed files from allocating huge images.
- Full updates stage files first and roll back both the overlay and Vencord if either replacement fails. Overlay updates use the same transaction. Linked installation folders are rejected, updates are locked against concurrent writers, and receipts are written within the transaction.

## Checked

- No token/message/audio collection, shell commands from call data, network listener, embedded credentials or automatic code downloads.
- Native volume commands are bounded to 0–200 and checked against the current channel and current non-self participants in both bridge and renderer.
- Update subprocesses use fixed program paths or argument arrays. The patch app asks before quitting Discord; overlay-only updates restart only the matching helper process.
- Packet, image/URL, volume-command and installer rollback checks cover these boundaries. The avatar popup was checked in a live overlay without changing a participant's volume.

## Limits

- GitHub's verified commit signature authenticates the published commit, not Apple Developer identity. Ad-hoc Mac signatures detect changed bundle contents but do not authenticate the publisher. Check the release SHA256SUMS and source; no private signing keys are included.
- Vencord and Discord run with your user account's privileges. This review does not audit all upstream Vencord/Discord dependencies or protect against malware already running as your user.
- Actual volume changes and exclusive-fullscreen behavior remain unverified. Discord updates may break the plugin.

Report a concern through GitHub issues without including account tokens or other private information.
