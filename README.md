# Mumbrew

Mumbrew is very simple, easy to use auto-updater for brew.

The service by default runs at 7AM and 10PM, and will upgrade everything that is not pinned.

This is similar in principle to https://github.com/Homebrew/homebrew-autoupdate
albeit much simpler and also quite dumber.

## Install

Install with brew:

```bash
brew install farcloser/brews/mumbrew
brew services start mumbrew
```

## Configure

You can tweak the service behavior by editing the launch agent plist file:

```bash
vi Library/LaunchAgents/homebrew.mxcl.mumbrew.plist
```

# Audit

Log files:

```bash
cat $(brew --prefix)/var/log/mumbrew.out
cat $(brew --prefix)/var/log/mumbrew.err
```

## Development

You need shellcheck (`brew install shellcheck`).
