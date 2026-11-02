# Security

The custom plugin and native helper were reviewed locally. This is not an independent audit or a guarantee of no vulnerabilities.

- No account tokens, messages or audio are collected. No network listener is opened.
- Avatar requests use HTTPS Discord image hosts, validate redirects, disable cookies and stop at 1 MB. Decoding checks image dimensions and uses only the first frame.
- Volume commands are restricted to 0–200 and current, non-self participants in the active channel. Native packets and command buffers are bounded.
- The plugin starts the helper at a fixed local path and communicates through standard input/output.

Protocol, avatar and volume-command checks passed. The avatar popup was checked in a live overlay; actual volume changes and exclusive fullscreen remain unverified.

The helper is ad-hoc signed, not Apple-notarized. Vencord/Discord dependencies were not fully audited. Discord changes may break compatibility. Report concerns through GitHub issues without including private data.
