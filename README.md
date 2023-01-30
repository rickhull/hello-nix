# Hello Nix

## Intro

*This is my revised version of the instructions here:
https://christine.website/blog/how-i-start-nix-2020-03-08*

## Update

This approach within this repo has changed significantly within the last 2
years.

I have made drastic changes and simplifications thanks to Nix Flakes.  We will
now depart greatly from Christine's approach, but with the same goal.

## Rationale

Use Nix Flakes and `direnv` to craft a shell environment optimized for Nix
workflows, on a per-directory basis.

### Direnv

* **Direnv** maintains a project-specific shell environment, triggered by
  entering the project directory.

`direnv` is not necessary for this, at all.  It's just handy.

## Procedure

`direnv` is optional, but very hand.

### Install `direnv`

If using NixOS, edit `/etc/nixos/configuration.nix` to add `direnv`:

```
  environment.systemPackages = with pkgs; [
    # ...
    direnv
  ];
```

Otherwise, make sure your system has `direnv` available.

Add the direnv shell hook, e.g. in `~/.bashrc` for bash shells:

```shell
eval "$(direnv hook bash)"`
```

### Create Project

Create a project directory and do some initialization:

```shell
$ mkdir -p hello
$ cd hello
$ touch .envrc  # if using direnv
```

Direnv works via the presence of `.envrc`.
Changing the current dir to a project dir triggers direnv behavior.
However, direnv is blocked from operating unless it is specifically allowed.
You will see a message like:

```
$ cd .
direnv: error /path/to/.envrc is blocked. Run `direnv allow` to approve its content
```

Run `direnv allow`.
Now direnv should give positive output when changing to a project dir.

### Create `flake.nix`

...

### Provide `hello` package from nixpkgs

### Add environment variable

## Create Rust project
