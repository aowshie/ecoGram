import argparse
import sys
from pathlib import Path

from . import lock, workspace
from .paths import UPSTREAM_CHECKOUT


def command_bump(_: argparse.Namespace) -> None:
    before, after = lock.bump()
    print(f"{before.commit or 'unpinned'} -> {after.commit}" if before != after else f"up to date at {after.commit}")


def command_sync(args: argparse.Namespace) -> None:
    workspace.checkout(args.tree, lock.load(), submodules=args.submodules)
    print(f"{workspace.apply_patches(args.tree)} patches applied in {args.tree}")


def command_export(args: argparse.Namespace) -> None:
    print(f"{workspace.export_patches(args.tree)} patches written")


def command_prepare(args: argparse.Namespace) -> None:
    from . import branding

    workspace.checkout(args.tree, lock.load(), submodules=True)
    count = workspace.apply_patches(args.tree)
    workspace.install_sources(args.tree)
    branding.install(args.tree)
    print(f"{count} patches applied, sources and branding installed in {args.tree}")


def command_build(args: argparse.Namespace) -> None:
    from . import build
    build.run_build(args.tree, args.output, args.configuration)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="ecogram")
    commands = root.add_subparsers(dest="command", required=True)
    tree = {"type": Path, "default": UPSTREAM_CHECKOUT}

    commands.add_parser("bump", help="pin the latest upstream commit").set_defaults(handler=command_bump)

    sync = commands.add_parser("sync", help="check out pinned upstream and apply patches")
    sync.add_argument("--tree", **tree)
    sync.add_argument("--submodules", action="store_true")
    sync.set_defaults(handler=command_sync)

    export = commands.add_parser("export", help="write workspace commits back to Patches")
    export.add_argument("--tree", **tree)
    export.set_defaults(handler=command_export)

    prepare = commands.add_parser("prepare", help="full build tree: upstream with submodules, patches, sources, branding")
    prepare.add_argument("--tree", **tree)
    prepare.set_defaults(handler=command_prepare)

    build = commands.add_parser("build", help="build an unsigned IPA on macOS")
    build.add_argument("--tree", **tree)
    build.add_argument("--output", type=Path, default=Path("artifacts"))
    build.add_argument("--configuration", choices=["release_arm64", "debug_arm64"], default="release_arm64")
    build.set_defaults(handler=command_build)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        args.handler(args)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
