# Portly

A tiny macOS menu bar app for seeing what's listening on your ports, and killing it when it gets in the way.

## How it works

Portly asks the kernel directly through libproc, the same source `lsof` uses, without starting a separate process. A full scan takes a few milliseconds, so it rescans every couple of seconds.

For each process it picks up the name, path, working folder, arguments and start time. The working folder is how a random `node` turns into "my-blog".

## Building

Needs macOS 27.2+ and Xcode 27.

```sh
open portly.xcodeproj
```

Then hit ⌘R. It shows up in the menu bar, with no Dock icon.
