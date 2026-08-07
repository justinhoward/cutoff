# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-08-07

### Fixed

- The Mysql2 patch now finds the first `SELECT` when a statement begins with a
  parenthesized query block, as in `(SELECT ...) UNION (SELECT ...)`.
  Previously the leading `(` was treated as an unrecognized token and the
  parser bailed out, so `MAX_EXECUTION_TIME` was silently never inserted and
  the query ran with no server-side ceiling. MySQL applies a hint in the first
  query block to the whole statement, so these queries are now capped
  correctly.
- Fixed a check in the Mysql2 patch that used `String#casecmp` where a boolean
  was expected. Because `casecmp` returns `0` for a match (which is truthy in
  Ruby), the guard never fired and any leading token merely *starting with*
  `select` (such as `selections`) had a hint comment spliced into it,
  producing invalid SQL. It now uses `casecmp?`.

### Upgrading

Queries beginning with a parenthesized query block were previously never given
a `MAX_EXECUTION_TIME` hint, so they ran unbounded on the server even with an
active cutoff. They are now capped, which means a query that used to slowly
succeed may instead raise `Mysql2::Error`. That is the intended behavior of the
patch, but it can surface as new errors on upgrade. If you have queries in this
shape, check that their callers handle the error, or give them a longer cutoff.

Statements beginning with `WITH` (common table expressions) are still not
given a hint.

## [1.1.0] - 2026-05-12

### Fixed

- Net::HTTP patch now also re-applies on `begin_transport`, so internal retries
  (Net::HTTP retries idempotent requests once by default on transient errors
  like Net::ReadTimeout) respect the cutoff instead of silently doubling the
  effective deadline.

## [1.0.0] - 2026-05-12

This release marks Cutoff's API as stable. There are no behavior changes
since 0.5.2.

### Breaking

- Drop support for Ruby < 3.1. The minimum supported Ruby is now 3.1.
  `required_ruby_version` in the gemspec has been raised accordingly. #21
  justinhoward

### Changed

- Modernize CI matrix to Ruby 3.1, 3.2, 3.3, 3.4, jruby-head, and
  truffleruby-head, and update gem dependencies that had rotted out of
  CI in the interim. #21 justinhoward

## [0.5.2] - 2022-09-06

### Changed

- Switch http URLs in specs to https #15 justinhoward
- Switch CI to support jruby and truffleruby head #18 justinhoward

### Added

- Add Rails 6 support #17 maksymst

## [0.5.1] - 2022-09-06

### Changed

- Upgrade rubocop to latest version #12 justinhoward
- Add codecov.io code coverage #11 justinhoward
- Complete yard documentation and fix warnings #13 justinhoward

### Fixed

- Pull cutoff option from job, not worker #14 mperham

## [0.5.0] - 2022-08-10

### Changed

- Use CLOCK_MONOTONIC instead of CLOCK_MONOTONIC_RAW #10 justinhoward
- Change CutoffExceededError to inherit from Timeout::Error #9 justinhoward

### Breaking

PR #9 changes the parent class of `Cutoff::CutoffExceededError` from `CutoffError`
to `Timeout::Error`. `CutoffError` changes from a class to a module.

## [0.4.2] - 2021-10-14

### Added

- Add sidekiq middleware
- Select checkpoints to enable or disable

## [0.4.1] - 2021-10-02

### Fixed

- Fix Net::HTTP patch to override timeouts given to start

## [0.4.0] - 2021-10-01

### Added

- Add benchmarks and slight performance improvements
- Add Rails controller integration

## [0.3.0] - 2021-08-20

### Added

- Allow timers to be disabled globally with `Cutoff.disable!`

## [0.2.0] - 2021-07-22

### Added

- Net::HTTP patch

## [0.1.0] - 2021-07-19

### Added

- Cutoff class
- Mysql2 patch

[Unreleased]: https://github.com/justinhoward/cutoff/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/justinhoward/cutoff/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/justinhoward/cutoff/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/justinhoward/cutoff/compare/v0.5.2...v1.0.0
[0.5.2]: https://github.com/justinhoward/cutoff/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/justinhoward/cutoff/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/justinhoward/cutoff/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/justinhoward/cutoff/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/justinhoward/cutoff/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/justinhoward/cutoff/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/justinhoward/cutoff/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/justinhoward/cutoff/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/justinhoward/cutoff/releases/tag/v0.1.0
