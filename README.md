# Mumbrew

Mumbrew is a simple auto-updater for brew.

The service by default runs at 7AM and 10PM, and will upgrade everything that is not pinned.

# Install

Install with brew:

```
brew install dubo-dubon-duponey/brews/mumbrew
brew services start mumbrew
```

# Disabling / enabling service

```
brew services stop mumbrew
brew services start mumbrew
```

# Configure

You can tweak the service behavior by editing the launch agent plist file:


```
vi Library/LaunchAgents/homebrew.mxcl.mumbrew.plist
```

# Audit

Log files:

```
cat $(brew --prefix)/var/log/mumbrew.out
cat $(brew --prefix)/var/log/mumbrew.err
```
