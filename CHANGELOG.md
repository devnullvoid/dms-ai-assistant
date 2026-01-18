# Changelog

All notable changes to the AI Assistant plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-01-17

### Added
- Table rendering support in markdown with borders and proper cell alignment
- Task list rendering with checkbox symbols (☑ for checked, ☐ for unchecked)
- Strikethrough text support (`~~text~~` syntax)
- Code block language labels (displays language identifier above code blocks)

### Fixed
- Header spacing issues - now use CSS margins for consistent spacing
- Code block background gaps with proper margin application
- Settings panel sliders showing duplicate values on hover (e.g., "51205120" instead of "5120")
- Regex backreferences in HTML cleanup causing headers to not render properly
- Inconsistent spacing between markdown elements throughout rendered content
- Code block language labels now use padding instead of margin to eliminate gaps

### Changed
- Slider values now display in setting labels instead of tooltips for always-visible feedback
- Updated markdown2html.js header comment to accurately describe supported features

## [1.0.0] - 2026-01-16

### Added
- Initial release of AI Assistant plugin
- Support for multiple AI providers (OpenAI, Anthropic, Gemini, Custom)
- Streaming response support with real-time rendering
- Markdown rendering with headers, bold, italic, code blocks, links, blockquotes
- Persistent chat history across sessions
- Flexible API key management (stored, environment variable, session-only)
- Configurable model parameters (temperature, max tokens)
- Monospace font toggle for technical discussions
- Message retry functionality
- Copy last assistant response to clipboard
- Chat history clearing
- Comprehensive settings panel with live updates

### Fixed
- Settings persistence bug where configuration wouldn't load after restart
- Race condition with pluginId initialization
- Whitespace handling in text input fields

[Unreleased]: https://github.com/devnullvoid/dms-ai-assistant/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/devnullvoid/dms-ai-assistant/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/devnullvoid/dms-ai-assistant/releases/tag/v1.0.0
