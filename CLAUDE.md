# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI Assistant plugin for DankMaterialShell - an integrated AI chat assistant with support for multiple AI providers (OpenAI, Anthropic, Google Gemini, custom OpenAI-compatible APIs), streaming responses, and markdown rendering.

**Repository**: <https://github.com/devnullvoid/dms-ai-assistant>

## Development Commands

No build system - this is a QML/JavaScript plugin. Changes take effect after DMS restart.

### Testing Plugin Changes

```bash
# Run DMS manually in terminal with debug logging (recommended for development)
QS_FORCE_STDERR_LOGGING=1 DMS_LOG_LEVEL=debug dms run

# If running as systemd service, restart to reload plugin
dms restart

# Test plugin toggle
dms plugin toggle aiAssistant
```

### Manual Testing

```bash
# Create symlink for development
ln -s $(pwd) ~/.config/DankMaterialShell/plugins/AIAssistant

# Check settings persistence
cat ~/.config/DankMaterialShell/plugin_settings.json | jq .aiAssistant

# Check session data
cat ~/.local/state/DankMaterialShell/plugins/aiAssistant/session.json | jq .
```

## Architecture

### Plugin Structure (DankMaterialShell Plugin System)

This plugin follows the DMS daemon+slideout pattern:

1. **AIAssistantDaemon.qml** (Entry point)
   - Plugin lifecycle controller
   - Exposes `toggle()` method for IPC control
   - Creates per-screen slideout instances via Variants
   - Instantiates global AIAssistantService

2. **AIAssistantService.qml** (Singleton service)
   - Backend logic shared across all screens
   - Manages API communication via curl + Process
   - Handles streaming response parsing
   - Session persistence (chat history)
   - Settings management via PluginService

3. **AIAssistant.qml** (UI)
   - Chat interface (per-screen instance)
   - Consumes AIAssistantService as data source
   - No direct API calls - delegates to service

### Key Architectural Patterns

**Service-UI Separation**: One global service (AIAssistantService) serves multiple UI instances (one per screen). This ensures chat history and state are consistent across all screens.

**Process-based HTTP**: Uses `Process` with `curl` for HTTP requests instead of QML networking APIs. Output is streamed through `StdioCollector.onTextChanged` for incremental parsing.

**Provider Abstraction**: AIApiAdapters.js handles provider-specific request formatting and response parsing. Each provider (OpenAI, Anthropic, Gemini) has different API schemas but is normalized to common interface.

**Session Management**: Chat history stored in `~/.local/state/DankMaterialShell/plugins/aiAssistant/session.json`. Invalidated when provider config changes (provider/baseUrl/model) to prevent mixing incompatible conversation contexts.

**Streaming Response Parsing**:

- Stream chunks arrive incrementally via StdioCollector
- Buffered line-by-line parsing handles partial SSE frames
- Provider-specific delta extraction (different JSON schemas)
- Real-time UI updates via ListModel property changes

### File Responsibilities

- **AIApiAdapters.js**: Provider adapters, curl command building, request/response formatting
- **markdown2html.js**: Markdown → HTML conversion with support for headers, bold, italic, strikethrough, code blocks with language labels, tables, task lists, links, blockquotes, and horizontal rules
- **MessageBubble.qml**: Individual message rendering (user/assistant)
- **MessageList.qml**: ScrollView container for message list
- **AIAssistantSettings.qml**: Settings panel UI with PluginService persistence

## Provider-Specific Details

### Adding a New Provider

1. Add provider to dropdown in AIAssistantSettings.qml
2. Implement request builder in AIApiAdapters.js `buildRequest()`:
   - Return {url, headers, body} object
   - Handle authentication (header format varies)
3. Implement response parser in AIAssistantService.qml `parseProviderDelta()`:
   - Extract text delta from SSE JSON chunks
   - Detect stream completion signal
4. Add API key environment variable fallback in `resolveApiKey()`:
   - Scoped: `DMS_<PROVIDER>_API_KEY`
   - Common: `<PROVIDER>_API_KEY`

### Current Providers

- **OpenAI**: `/v1/chat/completions` endpoint, `Authorization: Bearer` header
- **Anthropic**: `/v1/messages` endpoint, `x-api-key` header, `anthropic-version` header required
- **Gemini**: `/v1beta/models/{model}:streamGenerateContent?key=` endpoint, API key in URL
- **Custom**: Treated as OpenAI-compatible (same request format)

## Critical Implementation Details

### Settings Persistence Race Condition

**Issue**: Plugin settings must use hardcoded `pluginId` instead of relying on injected `pluginService.pluginId` because PluginService injection happens after Component.onCompleted, causing settings to not load/save correctly.

**Solution**: Both AIAssistantService and AIAssistantSettings hardcode `property string pluginId: "aiAssistant"` matching plugin.json id.

### Message Context Building

`buildPayload()` in AIAssistantService.qml builds conversation context by:

- Walking backwards through messagesModel
- Including last 20 turns (user+assistant pairs) with status="ok"
- Alternating user/assistant to maintain valid conversation structure
- Appending current user message at end

### Session Invalidation

Chat history is cleared when provider config changes because:

- Different models have different context windows
- Switching providers mid-conversation causes API errors
- Provider-specific message formats may be incompatible

Config hash: `provider|baseUrl|model` stored in session.json and validated on load.

## Common Tasks

### Debugging Streaming Issues

1. Run DMS manually with debug logging:

   ```bash
   QS_FORCE_STDERR_LOGGING=1 DMS_LOG_LEVEL=debug ./bin/dms run
   ```

2. Watch terminal output for AIAssistantService logs:
   - `request provider=` lines (verify URL/provider)
   - `request body(preview)=` lines (verify message format)
   - `response finalized chars=` lines (verify streaming completion)
3. Check HTTP status: `lastHttpStatus` property in service

### Testing Different Providers

Each provider requires different base URLs and API key environment variables. See README.md Configuration section for provider-specific setup.

### Modifying UI Layout

- MessageBubble.qml: Individual message appearance
- MessageList.qml: Message list container and scrolling
- AIAssistant.qml: Overall chat interface layout

### Adding Settings

1. Add property to AIAssistantSettings.qml
2. Add to `load()` function using `PluginService.loadPluginData()`
3. Add to `save()` function using `PluginService.savePluginData()`
4. Add UI control (DankToggle, DankTextField, etc.)
5. Connect setting to AIAssistantService via PluginService.onPluginDataChanged signal

## Plugin System Integration

### Required for DMS Core

This plugin requires DMS core PR <https://github.com/AvengeMedia/DankMaterialShell/pull/1407> which adds:

- `togglePlugin(pluginId)` method to PluginService
- `plugin toggle <pluginId>` IPC command
- `pluginService` property injection for daemon/launcher plugins
- Persistent launcher plugin instances

**Note**: Plugin will not function correctly without this PR merged into DankMaterialShell.

### IPC Control

```bash
# Toggle plugin visibility
dms plugin toggle aiAssistant

# Can be bound to keyboard shortcuts in DMS settings
```

## Important Constraints

- No build tooling - pure QML/JS runtime
- Qt 6.x QML APIs (Quickshell environment)
- No Node.js - JavaScript is QML's QJSEngine
- HTTP via curl subprocess, not XMLHttpRequest
- Settings stored in DMS global plugin_settings.json (not per-plugin file)
- Session data separate from settings (different persistence requirements)

## Testing Checklist

When making changes:

- [ ] Settings persist across `dms restart`
- [ ] Chat history survives restart (if same provider config)
- [ ] All providers work (test with actual API keys)
- [ ] Streaming displays incrementally (not all-at-once)
- [ ] Error messages appear for invalid API keys
- [ ] Config changes clear chat history appropriately
- [ ] Markdown renders correctly:
  - [ ] Headers (h1-h6) with proper spacing
  - [ ] Bold, italic, strikethrough formatting
  - [ ] Code blocks with language labels
  - [ ] Tables with borders and proper cell alignment
  - [ ] Task lists with checkbox symbols
  - [ ] Links, blockquotes, horizontal rules
  - [ ] Consistent spacing between all elements
- [ ] Settings panel sliders display correct values
- [ ] No QML warnings/errors in terminal output (when running with `QS_FORCE_STDERR_LOGGING=1`)
