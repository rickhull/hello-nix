This is my revised version of the instructions here:
https://christine.website/blog/how-i-start-nix-2020-03-08

Let's use direnv, niv, and lorri to craft a shell environment optimized
  for Nix workflows, on a per-directory basis.
**Direnv** maintains a project-specific shell environment, triggered by
  entering the project directory.
**Niv** helps manage dependencies in the Nix realm.
**Lorri** integrates direnv with Nix workflows, maintaining some state to avoid
  costly unnecessary rebuilds.

Christine's workflow works with any Nix install, whereas we'll be running on
  NixOS, using the power of Nix to maintain system state.

## Install system tools

Use NixOS packages for direnv, niv, and lorri, installed at the
  system level.
Edit `/etc/nixos/configuration.nix`:

```
  # /etc/nixos/configuration.nix
  # ...
  environment.systemPackages = with pkgs; [
    direnv
    niv
  ];
  services.lorri.enable = true;
  # ...
```

The lorri daemon should be running after `nixos-rebuild switch`, but
  there is currently a known issue where you may need to manually start or
  restart the lorri daemon via `systemctl` after the install.

## Setup direnv, niv, and lorri

Add the direnv shell hook, e.g. in `~/.bashrc` for bash shells:

```shell
eval "$(direnv hook bash)"`
```

Create a project directory and do some initialization:

```shell
$ mkdir -p hello
$ cd hello
$ niv init # creates nix/sources.json and nix/sources.nix
$ lorri init # creates shell.nix and .envrc
```

Direnv works via the presence of `.envrc`, which you can see is created by
  `lorri init`.
`cd .` should trigger direnv behavior.
However, direnv is blocked from operating unless it is specifically allowed.
You will see a message like:

```
$ cd .
direnv: error /path/to/.envrc is blocked. Run `direnv allow` to approve its content
```

Run `direnv allow` and you should now see some direnv output whenever you
  change into the `hello` directory.

## Update project environment

### Provide a package from nixpkgs

Add the `hello` package (from nixpkgs) to our project environment by
  editing the `shell.nix` created by `lorri init`:

```nix
# shell.nix
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.hello
  ];
}
```

Here, we pin the source packages (specified in `sources.nix`
and `sources.json`), rather than depending on the external state of nixpkgs.
With lorri running as a service, you should now be able to run `hello`:

```
$ hello
Hello, world!
```

### Add environment variable

Add `HELLO` to `shell.nix`:

```nix
# shell.nix
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.hello
  ];
  
  # Environment variables
  HELLO="world";
}
```

Whenever direnv notices changes, lorri will rebuild what is necessary in the
  background.
Note that this may take some time before your changes are apparent.
You will see some direnv output coming from the lorri service when the
  environment is updated.

```
$ echo $HELLO
world
```

OK, now we have direnv, niv, and lorri working for us.

## Create Rust project

### Install Rust

Let's make a demo project using Rust.
Since we are managing our dependencies with niv, make niv aware of
  Rust packages directly from mozilla (via github):

```shell
$ niv add mozilla/nixpkgs-mozilla`
```

Create `nix/rust.nix`:

```nix
# nix/rust.nix
{ sources ? import ./sources.nix }:

let
  pkgs =
    import sources.nixpkgs {
      overlays = [ (import sources.nixpkgs-mozilla) ];
    };
  channel = "nightly";
  date = "2020-06-10";
  targets = [ ];
  chan = pkgs.rustChannelOfTargets channel date targets;
in chan
```

Reference `rust.nix` in `shell.nix` so that lorri will pick up the changes:

```nix
# shell.nix
let
  sources = import ./nix/sources.nix;
  rust = import ./nix/rust.nix { inherit sources; };
  pkgs = import sources.nixpkgs { };
in
pkgs.mkShell {
  buildInputs = [
    rust
  ];
}
```

lorri will start building in the background.
`lorri shell` will bring this activity to the foreground if you want to see it.
It will take a few minutes before your new environment is ready.

```
$ rustc --version
rustc 1.46.0-nightly (feb3536eb 2020-06-09)
```

Confirmed! 
Create a new Rust project:

```shell
$ cargo init --vcs git .
```

This creates `src/main.rs` and `Cargo.toml`.
It will also initiate a git repo.
Build the default hello world program:

```shell
$ cargo build
```

This will build `src/main.rs`, producing `target/debug/$name_of_proj_dir`.
Try it:

```
$ target/debug/hello
Hello, world!
```

### Add HTTP functionality

Let's serve some HTTP with Rocket.
Add Rocket as a dependency to `Cargo.toml`:

```ini
# Cargo.toml
[dependencies]
rocket = "0.4.3"
```

```shell
$ cargo build
```

This will download all dependencies and precompile Rocket.
Now let's make a dumb HTTP server.
Edit `src/main.rs`:

```rust
# src/main.rs
#![feature(proc_macro_hygiene, decl_macro)] // language features needed by Rocket

// Import the rocket macros
#[macro_use]
extern crate rocket;

// Create route / that returns "Hello, world!"
#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

fn main() {
    rocket::ignite().mount("/", routes![index]).launch();
}
```

```shell
$ cargo build
```

This will create a binary at `target/debug/hello`

```
$ target/debug/hello &
$ curl http://localhost:8000
Hello world!
$ fg # (control-c to kill the server)
```

## Create Nix package

### Use naersk for packaging

```shell
$ niv add nmattia/naersk
```

Create `hello.nix`:

```nix
# hello.nix
# import niv sources and the pinned nixpkgs
{ sources ? import ./nix/sources.nix, pkgs ? import sources.nixpkgs { }}:
let
  # import rust compiler
  rust = import ./nix/rust.nix { inherit sources; };
  
  # configure naersk to use our pinned rust compiler
  naersk = pkgs.callPackage sources.naersk {
    rustc = rust;
    cargo = rust;
  };
  
  # tell nix-build to ignore the `target` directory
  src = builtins.filterSource
    (path: type: type != "directory" || builtins.baseNameOf path != "target")
    ./.;
in naersk.buildPackage {
  inherit src;
  remapPathPrefix =
    true; # remove nix store references for a smaller output package
}
```

Build it:

```shell
$ nix-build hello.nix
```

Run it:

```shell
$ result/bin/hello
```
