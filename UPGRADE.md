# Upgrade Guide

## Upgrading from 0.3 to 0.4

Ruby 3.2 is now the minimum.

`Security::Command.run` and `Security::Command.relay` no longer go through a shell. They take the program and its arguments separately, so nothing needs escaping:

```ruby
# 0.3
Security::Command.run("security show-keychain-info #{path.shellescape}")

# 0.4
Security::Command.run("security", "show-keychain-info", path)
```

A single string is now the name of the program to run, so a 0.3 command line fails as a missing command, with exit status 127.

Passwords no longer appear in the arguments of the `security` process, where any local user could read them with `ps`: the commands that take one (adding a password, creating, unlocking or setting the partition list of a keychain, importing with a passphrase) are sent to `security -i` on stdin. A password or other argument containing a line break now raises `ArgumentError`, and so does a command longer than `security -i` reads (4096 bytes, 32 arguments).

## Upgrading from 0.2 to 0.3

In previous versions, `find` attempted to detect failures by searching for a `security: ` prefix in the output. This approach was unreliable: certain errors (like ACL issues) produced no output, while others (like malformed requests) returned a usage banner. These cases would incorrectly result in a `Password` object with `nil` attributes, making it impossible for callers to distinguish a failed request from a successful one. Additionally, failures that *did* have the prefix returned `nil`, which was indistinguishable from a missing item.

Starting with version 0.3, both cases now raise a `Security::Error`. If your code relies on `nil` to handle missing keychain items, you should now rescue `Security::Error` to prevent a locked or misconfigured keychain from being treated as empty.
