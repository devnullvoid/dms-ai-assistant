# Changelog

All notable changes to the AI Assistant plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.3] - 2026-03-01

### Fixed
- Ordered list numbering no longer resets to 1 when a code block, table, or blockquote appears between list items; uses `<ol start="N">` segments to preserve numbering
- Blockquotes inside ordered list items now render correctly instead of appearing as literal `&gt;` text
- Code blocks inside list items no longer display with the list's indentation; common leading whitespace is stripped before rendering
- Chat view now automatically scrolls to the bottom when a response finishes streaming and markdown is rendered

## [1.3.2] - 2026-02-28

### Fixed
- Robust markdown placeholder system to prevent rendering issues with inline code and other elements
- Inline code styling refined to use CSS padding instead of non-breaking spaces
- Improved restoration logic for protected markdown blocks to ensure perfect HTML output

## [1.3.1] - 2026-02-28

### Added
- Copy button for code blocks to easily copy snippets to clipboard (fixes #5)
- Visual feedback hint ("Copied to clipboard") when copying text or code

### Fixed
- Code block layout issues including extra spacing, horizontal overflow, and background gaps
- Settings panel sizing issues by providing implicit dimensions (fixes #3)
- Bug where long code lines could break the message bubble structure

## [1.3.0] - 2026-02-28

### Added
- Per-provider settings profiles via new `providers` persisted object, so switching providers loads each provider's own endpoint/model/token settings
- New chat confirmation dialog when history exists
- Privacy note based on the AI service provider (remote vs. local)
- Temporary hint system for better user feedback
- Message regeneration for specific assistant messages
- Redesigned composer with improved layout and icon buttons

### Changed
- Provider switch in settings now immediately swaps to that provider's saved profile instead of reusing the previous provider's configuration
- Composer layout optimized for better space usage and readability

### Fixed
- Requests using stale custom endpoint/model settings after switching provider from the dropdown
- Chat history being cleared when switching providers (history is now retained per provider configuration)
- Gemini requests failing with HTTP 400 due to unsupported `stream` field in request body
- Gemini responses rendering empty in UI by enabling SSE mode and handling array-shaped streamed/final payloads

## [1.2.0] - 2026-02-24

### Added
- Enter key now sends messages (Shift+Enter inserts newline) - issue #6
- Regenerate button on assistant messages (appears on hover) - issue #6

### Changed
- Send/Stop buttons are now icon-only (40x40) with tooltips - issue #6
- Improved Gemini streaming finalization to handle `usageMetadata` end-of-stream signal

## [1.1.3] - 2026-02-21

### Fixed
- Settings dropdown becoming non-interactive after toggling the plugin off/on from DMS settings while the settings panel was open

## [1.1.2] - 2026-02-18

### Fixed
- Provider dropdown in the settings panel becoming non-interactive after closing and reopening the panel without restarting DMS

## [1.1.1] - 2026-02-12

### Fixed
- Streaming responses appearing empty due to `curl --compressed` interfering with `StdioCollector` stdout capture

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

[Unreleased]: https://github.com/devnullvoid/dms-ai-assistant/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/devnullvoid/dms-ai-assistant/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/devnullvoid/dms-ai-assistant/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/devnullvoid/dms-ai-assistant/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/devnullvoid/dms-ai-assistant/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/devnullvoid/dms-ai-assistant/releases/tag/v1.0.0
