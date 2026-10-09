// The Go-built tools the shared recipes run, pinned as tool directives
// in a module of their own so their dependency graph never reaches the
// project's go.mod (book/tooling.md).
module tools

go 1.27.1

tool (
	github.com/forkcloser/dot/cmd/dot
	github.com/forkcloser/godolint/cmd/godolint
	github.com/vbatts/git-validation
)

require (
	github.com/alecthomas/kong v1.16.1 // indirect
	github.com/containerd/typeurl/v2 v2.3.0 // indirect
	github.com/fatih/color v1.18.0 // indirect
	github.com/forkcloser/dot v1.2.1 // indirect
	github.com/forkcloser/go-graphviz v0.5.1 // indirect
	github.com/forkcloser/godolint v0.2.0 // indirect
	github.com/hashicorp/go-version v1.6.0 // indirect
	github.com/lmittmann/tint v1.2.1 // indirect
	github.com/magefile/mage v1.15.0 // indirect
	github.com/mattn/go-colorable v0.1.14 // indirect
	github.com/mattn/go-isatty v0.0.24 // indirect
	github.com/moby/buildkit v0.33.1 // indirect
	github.com/mycophonic/primordium v0.11.1 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/planetscale/vtprotobuf v0.6.1-0.20240319094008-0393e58bdf10 // indirect
	github.com/sirupsen/logrus v1.10.1 // indirect
	github.com/tetratelabs/wazero v1.12.0 // indirect
	github.com/vbatts/git-validation v1.2.2 // indirect
	golang.org/x/image v0.46.0 // indirect
	golang.org/x/sys v0.48.0 // indirect
	golang.org/x/text v0.42.0 // indirect
	google.golang.org/protobuf v1.36.12 // indirect
	mvdan.cc/sh/v3 v3.14.1 // indirect
)
