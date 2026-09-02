# Security policy

## Supported versions

Security fixes are made against the latest published Quikanva release and `main`.

## Report a vulnerability

Do not open a public issue for a suspected vulnerability.

Use GitHub's private vulnerability reporting flow:

<https://github.com/mikr13/quikanva/security/advisories/new>

Include the affected version, macOS version, impact, reproduction steps, and any proof-of-concept files or logs. Remove personal sketch data and unrelated system information before attaching evidence.

You should receive an acknowledgment within seven days. A fix timeline depends on severity and reproducibility. Please avoid public disclosure until a patched release is available or the maintainer agrees that disclosure is safe.

## Security boundary

Quikanva stores sketches locally and does not operate a network service. The highest-risk surfaces are file/image decoding, pasteboard and drag-and-drop input, URL routing, local persistence, global shortcuts, and the unsigned distribution path.
