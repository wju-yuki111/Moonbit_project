# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-28
### Added
- Core `Money` and `Currency` structs backed by `Int64` for maximum precision.
- Predefined major currencies: `USD`, `CNY`, `EUR`, `JPY`.
- Safe math operations: `add`, `sub`, `mul` with strict currency validation.
- Smart `allocate` algorithm to divide money without remainder loss.
- Implementation of standard MoonBit traits: `Eq`, `Compare`, `Show`.
- Extensive unit testing for allocation and math boundaries.
