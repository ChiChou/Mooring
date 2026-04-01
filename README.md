# Mooring

A macOS menu bar util for managing [iproxy](https://libimobiledevice.org/) instances.

![](images/menu.png)

## Features

- Create new iproxy port forwarding instances
- View all running iproxy processes
- Stop instances with one click
- Target specific devices by UDID
- USB and network connection modes
- iproxy and its dependencies are bundled — no Homebrew install needed at runtime

## Build from Source

Mooring bundles iproxy by downloading the latest nightly builds from [libimobiledevice](https://github.com/libimobiledevice) GitHub Actions during the Xcode build phase. This requires a few dev tools on the build machine.

### Dev Dependencies

| Tool | Purpose |
|---|---|
| `gh` | GitHub CLI — downloads nightly artifacts from Actions |
| `jq` | JSON processor — parses GitHub API responses |
| Xcode | Provides `tar`, `install_name_tool`, `codesign`, Swift toolchain |

### Quick Setup

```bash
brew install gh jq
gh auth login
```

Then open `Mooring.xcodeproj` in Xcode and build. The first build will download the latest [libplist](https://github.com/libimobiledevice/libplist), [libimobiledevice-glue](https://github.com/libimobiledevice/libimobiledevice-glue), and [libusbmuxd](https://github.com/libimobiledevice/libusbmuxd) macOS artifacts. Subsequent builds use a cache in Xcode's derived data — clean the build folder to force a re-download.

## Licenses

Mooring bundles the following LGPL-2.1 licensed libraries from the libimobiledevice project:

- libplist
- libimobiledevice-glue
- libusbmuxd (includes `iproxy`)

The full license text is included in the app bundle at `Contents/Resources/usbmuxd/LGPL-2.1.txt`. Source code is available from the links above.
