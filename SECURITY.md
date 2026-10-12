# Security

Security fixes target the latest release and `main`.

Report suspected vulnerabilities through [GitHub's private reporting form](https://github.com/mikr13/quikanva/security/advisories/new), not public issues. Include affected versions, impact, reproduction steps, and relevant evidence; remove personal sketch data and unrelated logs.

Expect acknowledgment within seven days. Coordinate disclosure with the maintainer; fix timing depends on severity and reproducibility.

Quikanva stores sketches locally and runs no network service. Security-sensitive surfaces include image decoding, paste/drop input, URL routing, persistence, and update verification.
