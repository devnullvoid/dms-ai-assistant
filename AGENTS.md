# AGENTS.md

This file provides guidance for AI coding agents working with this repository.

## Project Summary

DMS AI Assistant - A QML/JavaScript plugin for DankMaterialShell providing multi-provider AI chat with streaming responses and markdown rendering.

**Repository**: https://github.com/devnullvoid/dms-ai-assistant
**Language**: QML + JavaScript (Qt 6.x)
**Runtime**: Quickshell (no build system - interpreted at runtime)

## Quick Start

```bash
# Run with debug logging (recommended for development)
QS_FORCE_STDERR_LOGGING=1 DMS_LOG_LEVEL=debug dms run

# Restart DMS to reload plugin changes
dms restart

# Check plugin settings
cat ~/.config/DankMaterialShell/plugin_settings.json | jq .aiAssistant
```

## Architecture Overview

**Pattern**: Daemon + Slideout (singleton service + per-screen UI instances)

**Key Files**:
- `AIAssistantDaemon.qml` - Plugin lifecycle and screen management
- `AIAssistantService.qml` - Singleton backend service (API calls, streaming, state)
- `AIAssistant.qml` - UI component (chat interface)
- `AIApiAdapters.js` - Provider adapters and curl command building
- `markdown2html.js` - Markdown to HTML converter

**HTTP Method**: Uses `Process` + `curl` instead of QML networking APIs. Output streamed via `StdioCollector.onTextChanged`.

## Critical Implementation Notes

### Streaming Behavior (IMPORTANT)

**curl --compressed flag issue (fixed in v1.1.1)**:
- The `--compressed` flag was interfering with `StdioCollector` stdout capture
- Removed from `AIApiAdapters.js` - only `-N` and `--no-buffer` are needed
- Without this fix, streaming responses appear empty

**Why there's no "typing effect"**:
- Stream chunks ARE processed incrementally (thousands per response)
- QML batches property updates per render frame (~60fps) for performance
- Chunks arrive faster than UI can render individual updates
- Content appears "all at once" but is captured correctly
- **This is intentional QML behavior, not a bug**

### Provider Configuration

**Supported Providers**:
- OpenAI (gpt-5.2 models)
- Anthropic (claude-4.5 models)
- Google Gemini (gemini-2.5-flash, gemini-3-flash-preview)
- Inception / Mercury 2: OpenAI-compatible chat completions plus [API parameters](https://docs.inceptionlabs.ai/get-started/api-parameters) (`reasoning_effort`, `reasoning_summary`, `reasoning_summary_wait`); [streaming](https://docs.inceptionlabs.ai/capabilities/streaming)
- Custom (OpenAI-compatible endpoints)

**Custom Provider Notes**:
- Treated as OpenAI-compatible
- Base URLs ending with `/v4` or `/v1` are handled correctly
- Example: `https://api.z.ai/api/coding/paas/v4` → appends `/chat/completions`
- Authentication via `Authorization: Bearer` header

### Settings Persistence

**IMPORTANT**: Must hardcode `pluginId: "aiAssistant"` instead of using injected `pluginService.pluginId` because PluginService injection happens after `Component.onCompleted`.

**API Key Resolution Order**:
1. Saved key when `saveApiKey` is true, otherwise the current provider's session key (in-memory, not persisted)
2. Custom env var (from `apiKeyEnvVar` setting)
3. Provider-specific env var (`<PROVIDER>_API_KEY`)
4. Scoped env var (`DMS_<PROVIDER>_API_KEY`)

An inactive storage mode must not override the selected mode's key.

## Debug Logging

With `DMS_LOG_LEVEL=debug`, watch for:
- `[AIAssistantService] request provider=` - Verify URL construction
- `[AIAssistantService] request body(preview)=` - Verify message format
- `[AIAssistantService] response finalized chars=` - Verify content capture

**Note**: Stream chunk logging is intentionally disabled (would produce thousands of lines per response).

## Common Pitfalls

1. **Empty responses** → Check if `--compressed` flag was re-added to curl command
2. **"No API key" errors** → DMS daemon doesn't inherit shell environment vars; use saved key or systemd environment.d
3. **401 errors** → Verify API key has no whitespace; check provider authentication format
4. **QtQuick.Controls incompatibility** → Use custom QML implementations (MouseArea + Rectangle) instead of Menu/Popup

## Testing Checklist

- [ ] Settings persist across `dms restart`
- [ ] Chat history survives restart (if provider config unchanged)
- [ ] All providers work with real API keys
- [ ] Streaming displays content (even if all-at-once)
- [ ] Error messages appear for invalid keys
- [ ] Config changes clear chat history appropriately
- [ ] Markdown renders correctly (headers, code blocks, tables, lists, etc.)
- [ ] No QML errors in debug output

## Version History

- **1.1.1** (2026-02-12): Fixed streaming by removing `--compressed` curl flag
- **1.1.0**: Initial release with multi-provider support

## File Modification Guidelines

### Conversation tabs (1.8.0, #10)

- `ConversationTabs.qml` provides the Notepad-style strip. New chat creates a tab; Clear current chat clears only the active tab; closing requires UI confirmation and must leave at least one tab per provider endpoint.
- `conversationGroups` stores `{activeId, tabs}` per `provider|baseUrl`; `conversations` publishes only stable tab summaries. Do not republish summaries for message/draft-only changes, which would destroy inline rename editors.
- Store unsent text in `conversationDraft`; persist the outgoing tab before switching. Message lists reset follow-bottom only on explicit `conversationChanged`.
- Tab operations use `conversationBusy` (including process shutdown and history loading), preventing stream chunks from being routed to another tab. Provider changes cancel a running response before changing its history context.
- Session format v4 lives in the existing session file. `ConversationStore.js` migrates v1/v3 histories and retains every v2 per-model history as a separate tab. Back up the old file before migration; reject invalid/unknown files without overwriting them.
- `tests/conversation-persistence.test.cjs` loads the real service with model discovery disabled, uses only a temporary state directory, and verifies migration, two-process restoration, missing files, and corrupt-file preservation. Tab UI tests use real mouse/key events with minimal Theme/widget fixtures.

### Credential editing and clear history (2026-11-15)

- Keep `apiKeyDraft` independent of settings reloads while dirty; commit on Enter, field blur, explicit Save key, or provider change. Do not persist on each keystroke or log credentials.
- Update Remember mode and its saved key together through `saveActiveFields()`. Use the current draft when toggling; session keys are provider-scoped and updated through `setSessionApiKey()`.
- Turning Remember off removes the active provider's saved key and legacy key copy. Environment variables remain fallbacks when the selected credential is empty.
- More → Clear current chat reuses the New chat confirmation, blocks clearing during streaming, and persists only the active conversation's empty history.
- `node --test tests/*.test.cjs` covers actual settings/service controller methods and key-field handlers in isolated QML fixtures, including synchronous reloads, key storage transitions, provider switching, and history confirmation/isolation. Network, settings storage, and session-file I/O are stubbed; no real credentials or conversations are read or changed.

### Chat scrolling (2026-10-14, #14)

- Keep follow-bottom intent separate from ListView geometry. Variable-height delegates can change `contentY`, `contentHeight`, and `originY` during layout without user input.
- Every deferred/timed scroll must re-check `stickToBottom` and active user interaction when it executes. Do not queue unconditional `positionViewAtEnd()` calls or reset following in a delayed callback.
- Wheel/touchpad/scrollbar navigation cancels pending scrolling; returning to the bottom resumes following. The wheel observer must remain nonblocking.
- Run `node --test tests/scrolling.test.cjs` with Qt 6 Quick Test installed. Set `QML_TEST_RUNNER` if it is not at `/usr/lib/qt6/bin/qmltestrunner`. Tests run the actual MessageList and real wheel/scrollbar input with a variable-height bubble and minimal Theme fixture; they make no API calls and do not reload DMS.

- **No build needed** - Changes take effect after DMS restart
- **Read before editing** - Always read files first to understand context
- **Test with debug logging** - Run `QS_FORCE_STDERR_LOGGING=1 DMS_LOG_LEVEL=debug dms run`
- **Avoid QtQuick.Controls** - Not compatible with Quickshell runtime
