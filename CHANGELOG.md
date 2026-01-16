# Changelog

All notable changes to the AI Assistant plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of AI Assistant plugin
- Support for multiple AI providers (OpenAI, Anthropic, Gemini, Custom)
- Streaming response support with real-time rendering
- Markdown rendering with syntax highlighting
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

## [1.0.0] - 2026-01-16

### Added
- Initial public release

[Unreleased]: https://github.com/yourusername/dms-ai-assistant/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/dms-ai-assistant/releases/tag/v1.0.0
