###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run @//bazel/cargo/wasmsign:crates_vendor
###############################################################################
"""
# `crates_repository` API

- [aliases](#aliases)
- [crate_deps](#crate_deps)
- [all_crate_deps](#all_crate_deps)
- [crate_repositories](#crate_repositories)

"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

###############################################################################
# MACROS API
###############################################################################

# An identifier that represent common dependencies (unconditional).
_COMMON_CONDITION = ""

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "workspace_member_package": {

            # Not all dependencies are supported for all platforms.
            # the condition key is the condition required to be true
            # on the host platform.
            "condition": {

                # An alias to a crate target.     # The label of the crate target the
                # Aliases are only crate names.   # package name refers to.
                "package_name":                   "@full//:label",
            }
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for workspace_deps_map in all_dependency_maps:
        for pkg_name, conditional_deps_map in workspace_deps_map.items():
            if pkg_name not in dependencies:
                non_frozen_map = dict()
                for key, values in conditional_deps_map.items():
                    non_frozen_map.update({key: dict(values.items())})
                dependencies.setdefault(pkg_name, non_frozen_map)
                continue

            for condition, deps_map in conditional_deps_map.items():
                # If the condition has not been recorded, do so and continue
                if condition not in dependencies[pkg_name]:
                    dependencies[pkg_name].setdefault(condition, dict(deps_map.items()))
                    continue

                # Alert on any miss-matched dependencies
                inconsistent_entries = []
                for crate_name, crate_label in deps_map.items():
                    existing = dependencies[pkg_name][condition].get(crate_name)
                    if existing and existing != crate_label:
                        inconsistent_entries.append((crate_name, existing, crate_label))
                    dependencies[pkg_name][condition].update({crate_name: crate_label})

    return dependencies

def crate_deps(deps, package_name = None):
    """Finds the fully qualified label of the requested crates for the package where this macro is called.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if not deps:
        return []

    if package_name == None:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _NORMAL_DEPENDENCIES,
        _NORMAL_DEV_DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _PROC_MACRO_DEV_DEPENDENCIES,
        _BUILD_DEPENDENCIES,
        _BUILD_PROC_MACRO_DEPENDENCIES,
    ]).pop(package_name, {})

    # Combine all conditional packages so we can easily index over a flat list
    # TODO: Perhaps this should actually return select statements and maintain
    # the conditionals of the dependencies
    flat_deps = {}
    for deps_set in dependencies.values():
        for crate_name, crate_label in deps_set.items():
            flat_deps.update({crate_name: crate_label})

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in flat_deps:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(flat_deps[crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies,
        ))

    return crate_targets

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_NORMAL_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_PROC_MACRO_DEV_DEPENDENCIES)
    if build:
        all_dependency_maps.append(_BUILD_DEPENDENCIES)
    if build_proc_macro:
        all_dependency_maps.append(_BUILD_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps).pop(package_name, None)

    if not dependencies:
        if dependencies == None:
            fail("Tried to get all_crate_deps for package " + package_name + " but that package had no Cargo.toml file")
        else:
            return []

    crate_deps = list(dependencies.pop(_COMMON_CONDITION, {}).values())
    for condition, deps in dependencies.items():
        crate_deps += selects.with_or({
            tuple(_CONDITIONS[condition]): deps.values(),
            "//conditions:default": [],
        })

    return crate_deps

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Produces a map of Crate alias names to their original label

    If no dependency kinds are specified, `normal` and `proc_macro` are used by default.
    Setting any one flag will otherwise determine the contents of the returned dict.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        dict: The aliases of all associated packages
    """
    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_aliases_maps = []
    if normal:
        all_aliases_maps.append(_NORMAL_ALIASES)
    if normal_dev:
        all_aliases_maps.append(_NORMAL_DEV_ALIASES)
    if proc_macro:
        all_aliases_maps.append(_PROC_MACRO_ALIASES)
    if proc_macro_dev:
        all_aliases_maps.append(_PROC_MACRO_DEV_ALIASES)
    if build:
        all_aliases_maps.append(_BUILD_ALIASES)
    if build_proc_macro:
        all_aliases_maps.append(_BUILD_PROC_MACRO_ALIASES)

    # Default to always using normal aliases
    if not all_aliases_maps:
        all_aliases_maps.append(_NORMAL_ALIASES)
        all_aliases_maps.append(_PROC_MACRO_ALIASES)

    aliases = _flatten_dependency_maps(all_aliases_maps).pop(package_name, None)

    if not aliases:
        return dict()

    common_items = aliases.pop(_COMMON_CONDITION, {}).items()

    # If there are only common items in the dictionary, immediately return them
    if not len(aliases.keys()) == 1:
        return dict(common_items)

    # Build a single select statement where each conditional has accounted for the
    # common set of aliases.
    crate_aliases = {"//conditions:default": dict(common_items)}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        for triple in condition_triples:
            if triple in crate_aliases:
                crate_aliases[triple].update(deps)
            else:
                crate_aliases.update({triple: dict(deps.items() + common_items)})

    return select(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "bazel/cargo/wasmsign": {
        _COMMON_CONDITION: {
            "wasmsign": "@cu__wasmsign-0.1.2//:wasmsign",
        },
    },
}

_NORMAL_ALIASES = {
    "bazel/cargo/wasmsign": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "bazel/cargo/wasmsign": {
    },
}

_NORMAL_DEV_ALIASES = {
    "bazel/cargo/wasmsign": {
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "bazel/cargo/wasmsign": {
    },
}

_PROC_MACRO_ALIASES = {
    "bazel/cargo/wasmsign": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "bazel/cargo/wasmsign": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "bazel/cargo/wasmsign": {
    },
}

_BUILD_DEPENDENCIES = {
    "bazel/cargo/wasmsign": {
    },
}

_BUILD_ALIASES = {
    "bazel/cargo/wasmsign": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "bazel/cargo/wasmsign": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "bazel/cargo/wasmsign": {
    },
}

_CONDITIONS = {
    "cfg(not(windows))": ["@rules_rust//rust/platform:aarch64-apple-darwin", "@rules_rust//rust/platform:aarch64-apple-ios", "@rules_rust//rust/platform:aarch64-apple-ios-sim", "@rules_rust//rust/platform:aarch64-fuchsia", "@rules_rust//rust/platform:aarch64-linux-android", "@rules_rust//rust/platform:aarch64-unknown-linux-gnu", "@rules_rust//rust/platform:arm-unknown-linux-gnueabi", "@rules_rust//rust/platform:armv7-linux-androideabi", "@rules_rust//rust/platform:armv7-unknown-linux-gnueabi", "@rules_rust//rust/platform:i686-apple-darwin", "@rules_rust//rust/platform:i686-linux-android", "@rules_rust//rust/platform:i686-unknown-freebsd", "@rules_rust//rust/platform:i686-unknown-linux-gnu", "@rules_rust//rust/platform:powerpc-unknown-linux-gnu", "@rules_rust//rust/platform:riscv32imc-unknown-none-elf", "@rules_rust//rust/platform:riscv64gc-unknown-none-elf", "@rules_rust//rust/platform:s390x-unknown-linux-gnu", "@rules_rust//rust/platform:thumbv7em-none-eabi", "@rules_rust//rust/platform:thumbv8m.main-none-eabi", "@rules_rust//rust/platform:wasm32-unknown-unknown", "@rules_rust//rust/platform:wasm32-wasi", "@rules_rust//rust/platform:x86_64-apple-darwin", "@rules_rust//rust/platform:x86_64-apple-ios", "@rules_rust//rust/platform:x86_64-fuchsia", "@rules_rust//rust/platform:x86_64-linux-android", "@rules_rust//rust/platform:x86_64-unknown-freebsd", "@rules_rust//rust/platform:x86_64-unknown-linux-gnu", "@rules_rust//rust/platform:x86_64-unknown-none"],
    "cfg(target_os = \"hermit\")": [],
    "cfg(target_os = \"wasi\")": ["@rules_rust//rust/platform:wasm32-wasi"],
    "cfg(target_os = \"windows\")": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc", "@rules_rust//rust/platform:i686-pc-windows-msvc", "@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "cfg(unix)": ["@rules_rust//rust/platform:aarch64-apple-darwin", "@rules_rust//rust/platform:aarch64-apple-ios", "@rules_rust//rust/platform:aarch64-apple-ios-sim", "@rules_rust//rust/platform:aarch64-fuchsia", "@rules_rust//rust/platform:aarch64-linux-android", "@rules_rust//rust/platform:aarch64-unknown-linux-gnu", "@rules_rust//rust/platform:arm-unknown-linux-gnueabi", "@rules_rust//rust/platform:armv7-linux-androideabi", "@rules_rust//rust/platform:armv7-unknown-linux-gnueabi", "@rules_rust//rust/platform:i686-apple-darwin", "@rules_rust//rust/platform:i686-linux-android", "@rules_rust//rust/platform:i686-unknown-freebsd", "@rules_rust//rust/platform:i686-unknown-linux-gnu", "@rules_rust//rust/platform:powerpc-unknown-linux-gnu", "@rules_rust//rust/platform:s390x-unknown-linux-gnu", "@rules_rust//rust/platform:x86_64-apple-darwin", "@rules_rust//rust/platform:x86_64-apple-ios", "@rules_rust//rust/platform:x86_64-fuchsia", "@rules_rust//rust/platform:x86_64-linux-android", "@rules_rust//rust/platform:x86_64-unknown-freebsd", "@rules_rust//rust/platform:x86_64-unknown-linux-gnu"],
    "cfg(windows)": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc", "@rules_rust//rust/platform:i686-pc-windows-msvc", "@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "i686-pc-windows-gnu": [],
    "x86_64-pc-windows-gnu": [],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates"""
    maybe(
        http_archive,
        name = "cu__ansi_term-0.12.1",
        sha256 = "d52a9bb7ec0cf484c551830a7ce27bd20d67eac647e1befb56b0be4ee39a55d2",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/ansi_term/0.12.1/download"],
        strip_prefix = "ansi_term-0.12.1",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.ansi_term-0.12.1.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__anyhow-1.0.86",
        sha256 = "b3d1d046238990b9cf5bcde22a3fb3584ee5cf65fb2765f454ed428c7a0063da",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/anyhow/1.0.86/download"],
        strip_prefix = "anyhow-1.0.86",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.anyhow-1.0.86.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__atty-0.2.14",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/atty/0.2.14/download"],
        strip_prefix = "atty-0.2.14",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__bitflags-1.3.2",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/bitflags/1.3.2/download"],
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__byteorder-1.5.0",
        sha256 = "1fd0f2584146f6f2ef48085050886acf353beff7305ebd1ae69500e27c67f64b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/byteorder/1.5.0/download"],
        strip_prefix = "byteorder-1.5.0",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.byteorder-1.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__clap-2.34.0",
        sha256 = "a0610544180c38b88101fecf2dd634b174a62eef6946f84dfc6a7127512b381c",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap/2.34.0/download"],
        strip_prefix = "clap-2.34.0",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.clap-2.34.0.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__ct-codecs-1.1.1",
        sha256 = "f3b7eb4404b8195a9abb6356f4ac07d8ba267045c8d6d220ac4dc992e6cc75df",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/ct-codecs/1.1.1/download"],
        strip_prefix = "ct-codecs-1.1.1",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.ct-codecs-1.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__ed25519-compact-1.0.16",
        sha256 = "e18997d4604542d0736fae2c5ad6de987f0a50530cbcc14a7ce5a685328a252d",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/ed25519-compact/1.0.16/download"],
        strip_prefix = "ed25519-compact-1.0.16",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.ed25519-compact-1.0.16.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__getrandom-0.2.15",
        sha256 = "c4567c8db10ae91089c99af84c68c38da3ec2f087c3f82960bcdbf3656b6f4d7",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/getrandom/0.2.15/download"],
        strip_prefix = "getrandom-0.2.15",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.getrandom-0.2.15.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__hermit-abi-0.1.19",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/hermit-abi/0.1.19/download"],
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__hmac-sha512-1.1.5",
        sha256 = "e4ce1f4656bae589a3fab938f9f09bf58645b7ed01a2c5f8a3c238e01a4ef78a",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/hmac-sha512/1.1.5/download"],
        strip_prefix = "hmac-sha512-1.1.5",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.hmac-sha512-1.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__libc-0.2.155",
        sha256 = "97b3888a4aecf77e811145cadf6eef5901f4782c53886191b2f693f24761847c",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/libc/0.2.155/download"],
        strip_prefix = "libc-0.2.155",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.libc-0.2.155.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__parity-wasm-0.42.2",
        sha256 = "be5e13c266502aadf83426d87d81a0f5d1ef45b8027f5a471c360abfe4bfae92",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/parity-wasm/0.42.2/download"],
        strip_prefix = "parity-wasm-0.42.2",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.parity-wasm-0.42.2.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__proc-macro2-1.0.86",
        sha256 = "5e719e8df665df0d1c8fbfd238015744736151d4445ec0836b8e628aae103b77",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/proc-macro2/1.0.86/download"],
        strip_prefix = "proc-macro2-1.0.86",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.proc-macro2-1.0.86.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__quote-1.0.36",
        sha256 = "0fa76aaf39101c457836aec0ce2316dbdc3ab723cdda1c6bd4e6ad4208acaca7",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/quote/1.0.36/download"],
        strip_prefix = "quote-1.0.36",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.quote-1.0.36.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__strsim-0.8.0",
        sha256 = "8ea5119cdb4c55b55d432abb513a0429384878c15dde60cc77b1c99de1a95a6a",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/strsim/0.8.0/download"],
        strip_prefix = "strsim-0.8.0",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.strsim-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__syn-2.0.72",
        sha256 = "dc4b9b9bf2add8093d3f2c0204471e951b2285580335de42f9d2534f3ae7a8af",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/syn/2.0.72/download"],
        strip_prefix = "syn-2.0.72",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.syn-2.0.72.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__textwrap-0.11.0",
        sha256 = "d326610f408c7a4eb6f51c37c330e496b08506c9457c9d34287ecc38809fb060",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/textwrap/0.11.0/download"],
        strip_prefix = "textwrap-0.11.0",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.textwrap-0.11.0.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__thiserror-1.0.63",
        sha256 = "c0342370b38b6a11b6cc11d6a805569958d54cfa061a29969c3b5ce2ea405724",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/thiserror/1.0.63/download"],
        strip_prefix = "thiserror-1.0.63",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.thiserror-1.0.63.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__thiserror-impl-1.0.63",
        sha256 = "a4558b58466b9ad7ca0f102865eccc95938dca1a74a856f2b57b6629050da261",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/thiserror-impl/1.0.63/download"],
        strip_prefix = "thiserror-impl-1.0.63",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.thiserror-impl-1.0.63.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__unicode-ident-1.0.12",
        sha256 = "3354b9ac3fae1ff6755cb6db53683adb661634f67557942dea4facebec0fee4b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-ident/1.0.12/download"],
        strip_prefix = "unicode-ident-1.0.12",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.unicode-ident-1.0.12.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__unicode-width-0.1.13",
        sha256 = "0336d538f7abc86d282a4189614dfaa90810dfc2c6f6427eaf88e16311dd225d",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-width/0.1.13/download"],
        strip_prefix = "unicode-width-0.1.13",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.unicode-width-0.1.13.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__vec_map-0.8.2",
        sha256 = "f1bddf1187be692e79c5ffeab891132dfb0f236ed36a43c7ed39f1165ee20191",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/vec_map/0.8.2/download"],
        strip_prefix = "vec_map-0.8.2",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.vec_map-0.8.2.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__wasi-0.11.0-wasi-snapshot-preview1",
        sha256 = "9c8d87e72b64a3b4db28d11ce29237c246188f4f51057d65a7eab63b7987e423",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/wasi/0.11.0+wasi-snapshot-preview1/download"],
        strip_prefix = "wasi-0.11.0+wasi-snapshot-preview1",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.wasi-0.11.0+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        new_git_repository,
        name = "cu__wasmsign-0.1.2",
        branch = "master",
        init_submodules = True,
        remote = "https://github.com/jedisct1/wasmsign",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.wasmsign-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__winapi-0.3.9",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi/0.3.9/download"],
        strip_prefix = "winapi-0.3.9",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__winapi-i686-pc-windows-gnu-0.4.0",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi-i686-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "cu__winapi-x86_64-pc-windows-gnu-0.4.0",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("@proxy_wasm_cpp_host//bazel/cargo/wasmsign/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
