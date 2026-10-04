// The Go-built tools the shared recipes run, pinned as tool directives
// in a module of their own so their dependency graph never reaches the
// project's go.mod (book/tooling.md).
module tools

go 1.27.1

tool (
	github.com/farcloser/godolint/cmd/godolint
	github.com/forkcloser/dot/cmd/dot
	github.com/vbatts/git-validation
)

require (
	github.com/containerd/typeurl/v2 v2.3.0 // indirect
	github.com/disintegration/imaging v1.6.2 // indirect
	github.com/farcloser/godolint v0.1.0 // indirect
	github.com/fatih/color v1.18.0 // indirect
	github.com/flopp/go-findfont v0.1.0 // indirect
	github.com/fogleman/gg v1.3.0 // indirect
	github.com/forkcloser/dot v1.0.1 // indirect
	github.com/goccy/go-graphviz v0.2.10 // indirect
	github.com/golang/freetype v0.0.0-20170609003504-e2365dfdc4a0 // indirect
	github.com/hashicorp/go-version v1.6.0 // indirect
	github.com/magefile/mage v1.15.0 // indirect
	github.com/mattn/go-colorable v0.1.14 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/moby/buildkit v0.31.1 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/planetscale/vtprotobuf v0.6.1-0.20240319094008-0393e58bdf10 // indirect
	github.com/rs/zerolog v1.34.0 // indirect
	github.com/sirupsen/logrus v1.9.4 // indirect
	github.com/tetratelabs/wazero v1.12.0 // indirect
	github.com/urfave/cli/v3 v3.9.0 // indirect
	github.com/vbatts/git-validation v1.2.2 // indirect
	golang.org/x/image v0.46.0 // indirect
	golang.org/x/sys v0.48.0 // indirect
	golang.org/x/text v0.42.0 // indirect
	google.golang.org/protobuf v1.36.11 // indirect
	mvdan.cc/sh/v3 v3.12.0 // indirect
)
