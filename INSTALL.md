# Installation Guide

## Quick Install

```bash
# Clone to DMS plugins directory
mkdir -p ~/.config/DankMaterialShell/plugins
cd ~/.config/DankMaterialShell/plugins
git clone https://github.com/yourusername/dms-ai-assistant.git AIAssistant

# Restart DMS
dms restart
```

Then enable the plugin in Settings → Plugins.

## Requirements Check

Before installing, ensure you have:

1. **DankMaterialShell** with plugin toggle support
   - Check DMS version: `dms version`
   - Required: Version with [PR #XXX](link) merged

2. **System Dependencies**:
   ```bash
   # Check curl
   which curl

   # Check wl-copy
   which wl-copy
   ```

## Step-by-Step Installation

### 1. Install to Plugins Directory

```bash
# Create plugins directory if it doesn't exist
mkdir -p ~/.config/DankMaterialShell/plugins

# Navigate to plugins directory
cd ~/.config/DankMaterialShell/plugins

# Clone the repository
git clone https://github.com/yourusername/dms-ai-assistant.git AIAssistant
```

### 2. Verify Installation

```bash
# Check files are present
ls -la ~/.config/DankMaterialShell/plugins/AIAssistant/

# Should show:
# - plugin.json
# - *.qml files
# - *.js files
```

### 3. Restart DankMaterialShell

```bash
# Restart DMS to detect the new plugin
dms restart

# Or if using systemd
systemctl --user restart dms
```

### 4. Enable the Plugin

1. Open DMS Settings (Mod+Comma or Settings app)
2. Navigate to **Plugins** tab
3. Click **Scan for Plugins** if needed
4. Find **AI Assistant** in the list
5. Toggle it to **Enabled**

### 5. Configure the Plugin

1. Click the **Settings** button next to AI Assistant
2. Or toggle the assistant (Mod+A or via DankBar)
3. Click the **Settings** icon in the assistant window
4. Configure your AI provider:
   - Select provider (OpenAI, Anthropic, Gemini, or Custom)
   - Enter Base URL (usually auto-filled)
   - Enter your model name
   - Set API key or environment variable
   - Adjust temperature and max tokens if desired

## First Run Configuration

### Option A: Using API Key Directly

1. Select your provider
2. Enter your API key in the "API Key" field
3. Toggle "Remember API Key" ON to save it
4. Click outside the settings to save

### Option B: Using Environment Variable (Recommended)

1. Add API key to your shell profile:
   ```bash
   # For bash: ~/.bashrc
   # For zsh: ~/.zshrc
   # For fish: ~/.config/fish/config.fish
   export OPENAI_API_KEY="sk-your-key-here"
   ```

2. Restart your session or source the file:
   ```bash
   source ~/.bashrc  # or ~/.zshrc, etc.
   ```

3. In plugin settings:
   - Set "API Key Env Var" to `OPENAI_API_KEY`
   - Leave "Remember API Key" OFF
   - API key will be read from environment

## Verification

### Test the Plugin

1. Toggle the assistant:
   ```bash
   dms plugin toggle aiAssistant
   ```

2. You should see the chat interface

3. Try sending a message:
   - Type: "Hello, are you working?"
   - Press Ctrl+Enter or click Send
   - You should see a streaming response

### Check Logs

If something goes wrong:

```bash
# Watch DMS logs
journalctl --user -u dms -f

# Or if running manually
# Check terminal output for plugin-related messages
```

## Updating

To update to the latest version:

```bash
cd ~/.config/DankMaterialShell/plugins/AIAssistant
git pull
dms restart
```

## Uninstallation

To remove the plugin:

```bash
# Remove plugin directory
rm -rf ~/.config/DankMaterialShell/plugins/AIAssistant

# Restart DMS
dms restart
```

Your settings and chat history will remain in:
- Settings: `~/.config/DankMaterialShell/plugin_settings.json`
- History: `~/.local/state/DankMaterialShell/plugins/aiAssistant/session.json`

Delete these manually if desired.

## Troubleshooting

### Plugin Not Showing in Settings

1. Check plugin.json exists and is valid:
   ```bash
   cat ~/.config/DankMaterialShell/plugins/AIAssistant/plugin.json
   ```

2. Click "Scan for Plugins" in Settings → Plugins

3. Check DMS logs for errors:
   ```bash
   journalctl --user -u dms | grep -i "plugin\|assistant"
   ```

### Settings Not Persisting

1. Check plugin_settings.json is writable:
   ```bash
   ls -la ~/.config/DankMaterialShell/plugin_settings.json
   ```

2. Check for JSON syntax errors:
   ```bash
   cat ~/.config/DankMaterialShell/plugin_settings.json | jq .
   ```

### API Requests Failing

1. Test API connection manually:
   ```bash
   # OpenAI example
   curl -H "Authorization: Bearer $OPENAI_API_KEY" \
        https://api.openai.com/v1/models
   ```

2. Check firewall/network:
   ```bash
   ping api.openai.com
   ```

3. Verify API key is correct:
   - Check no extra spaces
   - Check not expired
   - Check sufficient credits/quota

### No Streaming Responses

Some providers or local setups may not support streaming. The plugin will fall back to non-streaming mode automatically.

## Getting Help

- GitHub Issues: Report bugs or request features
- DMS Community: Join discussions about plugins
- Documentation: Check README.md for detailed usage info
