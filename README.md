# Mumbrew

Mumbrew is very simple, easy to use auto-updater for brew.

The service by default runs at 2AM, and will upgrade everything that is not pinned.

This is similar in principle to https://github.com/Homebrew/homebrew-autoupdate
albeit much simpler and also quite dumber.

## Install

Install with brew:

```bash
brew tap farcloser/brews
brew trust farcloser/brews
brew install farcloser/brews/mumbrew
brew services start mumbrew
```

Trusting the tap covers both mumbrew and the tap's own build of
terminal-notifier, which mumbrew depends on.

## Configure

You can tweak the service behavior by editing the launch agent plist file:

```bash
vi ~/Library/LaunchAgents/homebrew.mxcl.mumbrew.plist
```

# Audit

Log files:

```bash
cat $(brew --prefix)/var/log/farcloser.mumbrew.out.log
cat $(brew --prefix)/var/log/farcloser.mumbrew.err.log
```

## Development

The toolchain is pinned by [limen](https://github.com/farcloser/limen) and installed by aqua.

```bash
just lint
just test
```
