# ADR-0004: auth topology

**Status:** accepted.

**Context.** Upstream signs in with email and password (cookie and bearer tokens) plus API keys. It has no
single sign-on to wire the platform's directory into, and no mail.

**Decision.** No sign-on addon and no `proxyAuth`: agents, MCP clients and API keys must reach the API directly.
Self-registration is closed at the front proxy, the interface routes that need a session answer 401 without one,
and telemetry is off. The generated administrator password is kept in the data directory.

**Consequences.** There is no password reset by email: an administrator with access to the app resets passwords.
Creating further users has not been verified in this package; only the administrator account is supported.
