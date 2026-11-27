# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-22

This release changes how errors are reported. Code written against 0.1.x that
matches on `{:error, reason}` tuples needs to be updated.

### Breaking changes

- Navigation, editing and query functions now raise `ExZipper.Error` instead
  of returning `{:error, reason}` tuples. The error's `:reason` field holds the
  same atom the tuple used to (for example `:down_from_leaf`), and its
  `:focus` field holds the node the zipper was focused on when it failed. A
  pipeline now stops at the step that failed instead of crashing with a
  `FunctionClauseError` at the next step.
- The `error` and `maybe_zipper` types on `ExZipper.Zipper` have been removed.
- `remove/1` now moves focus to the previous node in a depth-first walk, as
  documented. When the removed node's left sibling is a branch, focus moves to
  the deepest rightmost node inside it, instead of to the sibling itself.
- Once a depth-first walk reaches its end, every function that moves or
  changes the zipper raises `ExZipper.Error` with a new reason such as
  `:down_from_end` or `:next_of_end`. Call `root/1` to start again.
  - `down/1`, `up/1`, `left/1`, `right/1`, `leftmost/1`, `rightmost/1`,
    `lefts/1`, `rights/1`, `path/1`, `insert_left/2`, `insert_right/2` and
    `remove/1` used to crash with a `FunctionClauseError` or
    `UndefinedFunctionError`.
  - `next/1` used to return the same zipper again, and `insert_child/2`,
    `append_child/2`, `replace/2` and `edit/2` used to change the root while
    staying at the end. These now raise too.
  - The new `map/2` also raises when called at the end.
  - `node/1`, `branch?/1`, `children/1`, `end?/1`, `to_list/1`, `find/2` and
    `find_all/2` still work at the end.
- Elixir 1.17 or later is required.
- The license has changed from MIT to the [Unlicense](https://unlicense.org/).

### Added

- `ExZipper.Error`, with a readable message for each failure reason.
- `find/2`, which returns a zipper focused on the first node matching a
  function, or `nil` if nothing matches.
- `find_all/2`, which returns a zipper for each matching node.
- `map/2`, which replaces every node in a depth-first walk with the result of
  calling a function on it.
- `root/1` now leaves the end state of a depth-first walk.
- The `ExZipper.Tree` behaviour, with `branch?/1`, `children/1` and
  `make_node/2` callbacks, for defining a kind of tree in a module.
- `new/2`, which returns a zipper for a tree using the callbacks of a module
  that implements `ExZipper.Tree`.
- An `Inspect` implementation for `ExZipper.Zipper` that shows the focused
  node, with `...` marking whether there is more of the tree before or after
  it, instead of the raw struct with its stored functions and crumbs.

### Fixed

- Typespecs referred to a `Zipper` module that did not exist.
- The docs for `rights/1` and `rightmost/1` described the wrong thing.

### Changed

- All functions are documented on `ExZipper.Zipper`, including the
  navigation, editing and traversal functions that were previously documented
  only on internal modules.

## [0.1.3] - 2017-12-11

### Added

- `to_list/1`, which returns every node in depth-first order.

## [0.1.2] - 2017-11-25

### Changed

- Documentation updates.

## [0.1.1] - 2017-11-21

- Initial release on Hex.

[1.0.0]: https://github.com/mikowitz/ex_zipper/compare/v0.1.3...v1.0.0
[0.1.3]: https://github.com/mikowitz/ex_zipper/compare/0.1.2...v0.1.3
[0.1.2]: https://github.com/mikowitz/ex_zipper/compare/v0.1.1...0.1.2
[0.1.1]: https://github.com/mikowitz/ex_zipper/releases/tag/v0.1.1
