# Contributing to AI Assistant Plugin

Thank you for considering contributing to the AI Assistant plugin! This document provides guidelines and information for contributors.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the bug report template
3. Include:
   - DMS version
   - Plugin version
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant logs/screenshots

### Requesting Features

1. Open an issue with the feature request template
2. Describe the use case clearly
3. Explain why this feature would be valuable
4. Consider implementation complexity

### Submitting Changes

1. **Fork the repository**
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following the code style guide
4. **Test thoroughly** with DMS
5. **Commit with clear messages**:
   ```
   feat: Add support for new AI provider
   fix: Resolve settings persistence issue
   docs: Update installation instructions
   ```
6. **Push to your fork**
7. **Open a Pull Request**

## Development Setup

### Prerequisites

- DankMaterialShell development environment
- Qt/QML knowledge
- Git

### Local Development

1. Clone your fork:
   ```bash
   git clone https://github.com/devnullvoid/dms-ai-assistant.git
   cd dms-ai-assistant
   ```

2. Create a symlink for testing:
   ```bash
   ln -s $(pwd) ~/.config/DankMaterialShell/plugins/AIAssistant
   ```

3. Make changes and test by running DMS manually:
   ```bash
   QS_FORCE_STDERR_LOGGING=1 DMS_LOG_LEVEL=debug dms run
   ```

4. Watch terminal output for plugin logs and errors

## Code Style Guide

### QML Style

- Use 4-space indentation
- `id` should be first property
- Group properties logically (required, then local, then signals)
- Use property bindings over imperative code
- Comment complex logic only (code should be self-documenting)

Example:
```qml
Item {
    id: root

    required property var someService
    property string localValue: "default"

    signal valueChanged(string newValue)

    function doSomething() {
        // Implementation
    }
}
```

### JavaScript Style

- Use `const` for constants, `let` for variables
- Prefer arrow functions for callbacks
- Use descriptive variable names
- Add JSDoc comments for exported functions

Example:
```javascript
/**
 * Formats an API request for the specified provider
 * @param {string} provider - The AI provider name
 * @param {Array} messages - Chat messages array
 * @returns {Object} Formatted request object
 */
function formatRequest(provider, messages) {
    // Implementation
}
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Formatting, no code change
- `refactor:` Code restructuring
- `test:` Adding tests
- `chore:` Maintenance tasks

Examples:
```
feat: Add support for Claude 3.5 Sonnet
fix: Resolve API timeout handling
docs: Update provider configuration guide
refactor: Extract message rendering logic
```

## File Structure

```
AIAssistant/
├── plugin.json              # Plugin manifest - version, metadata
├── AIAssistantDaemon.qml    # Main plugin controller, slideout management
├── AIAssistant.qml          # Chat UI - message list, composer
├── AIAssistantService.qml   # Backend - API calls, state, history
├── AIAssistantSettings.qml  # Settings panel UI
├── AIApiAdapters.js         # Provider API adapters
├── markdown2html.js         # Markdown rendering
├── MessageBubble.qml        # Single message component
└── MessageList.qml          # Message list container
```

## Adding New Features

### Adding a New AI Provider

1. **Update `AIApiAdapters.js`**:
   ```javascript
   PROVIDER_CONFIGS: {
       newProvider: {
           name: "New Provider",
           streamEndpoint: "/v1/chat/completions",
           authHeader: "Authorization",
           authPrefix: "Bearer ",
           supportsStreaming: true
       }
   }
   ```

2. **Add provider to dropdown** in `AIAssistantSettings.qml`:
   ```qml
   DankDropdown {
       options: ["openai", "anthropic", "gemini", "custom", "newProvider"]
   }
   ```

3. **Implement formatRequest** if needed:
   ```javascript
   if (provider === "newProvider") {
       return {
           // Custom request format
       };
   }
   ```

4. **Test thoroughly** with actual API

5. **Update documentation** (README.md)

### Adding New Settings

1. **Add property to `AIAssistantSettings.qml`**:
   ```qml
   property bool newSetting: false
   ```

2. **Add to load() function**:
   ```qml
   newSetting = PluginService.loadPluginData(pluginId, "newSetting", false)
   ```

3. **Add UI control**:
   ```qml
   DankToggle {
       checked: root.newSetting
       onToggled: checked => save("newSetting", checked)
   }
   ```

4. **Use in `AIAssistantService.qml`**:
   ```qml
   property bool newSetting: false

   function loadSettings() {
       newSetting = PluginService.loadPluginData(pluginId, "newSetting", false)
   }
   ```

## Testing Guidelines

### Manual Testing Checklist

- [ ] Settings persist across restarts
- [ ] All providers work correctly
- [ ] Streaming responses display properly
- [ ] Error handling works (bad API key, network issues)
- [ ] Chat history saves and loads
- [ ] Markdown renders correctly:
  - [ ] Headers with proper spacing
  - [ ] Bold, italic, strikethrough formatting
  - [ ] Code blocks with language labels
  - [ ] Tables with borders and cell alignment
  - [ ] Task lists with checkboxes
  - [ ] Links, blockquotes, horizontal rules
- [ ] Keyboard shortcuts work
- [ ] UI responsive and smooth
- [ ] Settings sliders display correct values
- [ ] No errors in terminal output (when running with `QS_FORCE_STDERR_LOGGING=1`)

### Test Different Scenarios

1. **First-time setup**: Clean install experience
2. **Provider switching**: Change between providers
3. **API failures**: Invalid keys, network errors
4. **Long conversations**: Many messages, scrolling
5. **Settings changes**: Verify all settings save/load
6. **Restart behavior**: Settings and history persist

## Documentation

### Update Documentation When:

- Adding new features
- Changing behavior
- Adding settings
- Supporting new providers
- Fixing significant bugs

### Documentation Files:

- **README.md**: Feature overview, installation, and usage guide
- **CHANGELOG.md**: Version history
- **CONTRIBUTING.md**: This file (contributor guidelines)
- **CLAUDE.md**: Development guidance for Claude Code

## Pull Request Process

1. **Update version** in `plugin.json` if needed
2. **Update CHANGELOG.md** with changes
3. **Ensure all tests pass** (manual testing checklist)
4. **Update documentation** as needed
5. **Provide clear PR description**:
   - What changed
   - Why it changed
   - How to test
   - Screenshots if UI change

6. **Respond to review feedback**
7. **Squash commits** if requested
8. **Wait for maintainer approval**

## Code Review Criteria

Reviewers will check:

- Code quality and style
- Feature completeness
- No breaking changes (unless version bump)
- Documentation updated
- Manual testing performed
- Performance impact
- Security considerations (API keys, etc.)

## Questions?

- Open a discussion issue
- Tag maintainers for guidance
- Check existing issues and PRs for context

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
