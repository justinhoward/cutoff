# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/justinhoward/cutoff/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/justinhoward/cutoff/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/justinhoward/cutoff/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/justinhoward/cutoff/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/justinhoward/cutoff/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/justinhoward/cutoff/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/justinhoward/cutoff/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/justinhoward/cutoff/releases/tag/v0.1.0
