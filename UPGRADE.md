# Upgrade Guide

## Upgrading from 0.2 to 0.3

In previous versions, `find` attempted to detect failures by searching for a `security: ` prefix in the output. This approach was unreliable: certain errors (like ACL issues) produced no output, while others (like malformed requests) returned a usage banner. These cases would incorrectly result in a `Password` object with `nil` attributes, making it impossible for callers to distinguish a failed request from a successful one. Additionally, failures that *did* have the prefix returned `nil`, which was indistinguishable from a missing item.

Starting with version 0.3, both cases now raise a `Security::Error`. If your code relies on `nil` to handle missing keychain items, you should now rescue `Security::Error` to prevent a locked or misconfigured keychain from being treated as empty.
