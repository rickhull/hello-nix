I'd like to come up with some NixOS recipes for different box roles:

* dev - for human users. includes editors and IDEs.  prioritizes
        convenience and openness at the expense of  strictness
* build - for machine users. includes expansive sets of build tools, like
          gcc, make, clang, llvm, rust stuff, ruby, python, java, etc.
	  no dev tools like editors and IDEs.
* app   - for machine users. execution and runtime environment.
          strict and minimal.  no build tools or dev tools.


I'm mostly playing with dev environments but ultimately looking to cook up
build and app environments.

For dev environments:

* https://christine.website/blog/how-i-start-nix-2020-03-08

Except install lorri and direnv via configuration.nix using stable packages.  e.g.

```
  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    # basics
    busybox
    tree
    git

    # editors
    (emacs.override {
      withX = false;
      withGTK2 = false;
      withGTK3 = false;
    })

    # nix style dev environments, lorri below as a service
    direnv
    niv

    # languages
    ruby
    perl
    python
    python3
    elixir

    # build tools
    gcc
    gnumake

    # ruby stuff
    chruby
  ];

  # Enable lorri for building dev environments
  services.lorri.enable = true;
```

We'll be using direnv, niv, and lorri to craft a shell environment optimized
for Nix workflows, on a per-directory basis.  First, add the direnv shell
hook, e.g. for bash: `eval "$(direnv hook bash)"` in ~/.bashrc

Now let's make hello world:

```
mkdir -p hello
cd hello
niv init # creates nix/sources.json
lorri init # creates shell.nix and .envrc
```

Direnv gives us a way to maintain a project-specific shell environment,
just by entering the project directory.  Niv helps us manage dependencies.
Lorri integrates direnv with Nix workflows, maintaining some state to avoid
costly unnecessary rebuilds.

Direnv works via the presence of .envrc, which you can see is created by
`lorri init`.  Now we should be able to just `cd .` to trigger direnv
behavior.  However, direnv is blocked from operating unless it is specifically
allowed.  You will see a message like:

```
cd .
direnv: error /path/to/.envrc is blocked. Run `direnv allow` to approve its content
```

So just `direnv allow` and you should see some direnv output whenever you
change into the `hello` directory.

Now, let's add the `hello` package to our project environment by editing
the `shell.nix` created by `lorri init`:

```
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

Here, we are pinning the source packages that are specified in `sources.nix`
and `sources.json`, rather than depending on the external state of nixpkgs.

With lorri running as a service, you should now be able to run `hello`:

```
Hello, world!
```

Add an environment variable to `shell.nix`:

```
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

`echo $HELLO`:

```
world
```

lorri is running a service on the machine, and whenever direnv notices
changes, lorri will rebuild what is necessary in the background.  Note
that this will take some time before your changes are apparent.

OK, now we can make a demo project using Rust.  Since we are managing
our dependencies with niv, let's make niv aware of Rust packages
directly from mozilla via github:

`niv add mozilla/nixpkgs-mozilla`

Now, create `nix/rust.nix`:

```
# nix/rust.nix
{ sources ? import ./sources.nix }:

let
  pkgs =
    import sources.nixpkgs { overlays = [ (import sources.nixpkgs-mozilla) ]; };
  channel = "nightly";
  date = "2020-06-10";
  targets = [ ];
  chan = pkgs.rustChannelOfTargets channel date targets;
in chan
```

Now, we can reference `rust.nix` in our `shell.nix` so that lorri will
pick up the changes:

```
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

lorri will start building in the background.  You can just `lorri shell`
if you want to see the process.  It will take a few minutes before
your new environment is ready.

`rustc --version`

```
rustc 1.46.0-nightly (feb3536eb 2020-06-09)
```

