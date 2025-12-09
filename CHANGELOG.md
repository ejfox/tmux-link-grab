# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-09

### Added
- Cross-platform clipboard detection (pbcopy, xclip, wl-copy)
- Comprehensive dependency validation
- Configurable scrollback lines, flash count, and flash duration
- Detailed error messages
- Full troubleshooting documentation
- Better code organization with clear sections

### Changed
- Improved URL/IP regex patterns for better accuracy
- Enhanced error handling with proper exit codes
- Refactored to use bash parameter expansion instead of sed (performance)
- Better function isolation and modularity

### Fixed
- Removed unused variables
- Fixed shellcheck linting warnings
- Improved signal handling with `set -euo pipefail`
- Proper quoting of variables throughout

### Security
- Input validation for all parameters
- Safe piping with error propagation

## [1.0.0] - 2025-12-09

### Added
- Initial release
- Basic URL and IPv4 extraction
- fzf-based number selection
- Visual flash confirmation on copy
- GNU GPL v3 licensing
