import QtQuick
import QtQuick.Controls
import QtTest
import qs.Services

TestCase {
    id: testCase
    name: "CredentialsAndHistory"
    when: windowShown
    visible: true
    width: 600
    height: 200
    property var service
    property var settings
    property var field

    Component { id: serviceComponent; ServiceController {} }
    Component { id: settingsComponent; SettingsController { width: 500; height: 100 } }
    Component { id: chatComponent; ChatController {} }

    function init() {
        PluginService.reset();
        service = createTemporaryObject(serviceComponent, testCase);
        verify(service !== null);
        service.sessionLoaded = true;
        service.loadSettings();
        settings = createTemporaryObject(settingsComponent, testCase, {aiService: service});
        verify(settings !== null);
        settings.load();
        field = findChild(settings, "apiKeyField");
        verify(field !== null);
    }

    function test_saved_key_replaces_stale_session_override() {
        service.setSessionApiKey("stale-session-fixture");
        compare(service.resolveApiKey(), "old-gemini-fixture");
        settings.editApiKey("new-gemini-fixture");
        settings.commitApiKey();
        compare(service.resolveApiKey(), "new-gemini-fixture");
        compare(service.sessionApiKey, "");
        compare(PluginService.loadPluginData("aiAssistant", "providers", {}).gemini.apiKey, "new-gemini-fixture");
        settings.load();
        compare(field.text, "new-gemini-fixture");
    }

    function test_typing_survives_settings_reload_and_commits_on_enter() {
        field.forceActiveFocus();
        field.selectAll();
        // Real TextInput events exercise the production field binding/handlers.
        keyClick(Qt.Key_N);
        keyClick(Qt.Key_E);
        keyClick(Qt.Key_W);
        compare(field.text, "new");
        verify(settings.apiKeyDirty);
        PluginService.savePluginData("aiAssistant", "useMonospace", true);
        compare(field.text, "new");
        verify(settings.apiKeyDirty);
        keyClick(Qt.Key_Return);
        compare(service.resolveApiKey(), "new");
        compare(settings.apiKeyDirty, false);
        settings.load();
        compare(field.text, "new");
    }

    function test_remember_toggle_uses_draft_and_removes_saved_copy() {
        settings.editApiKey("fresh-draft-fixture");
        settings.setRememberApiKey(false);
        compare(service.resolveApiKey(), "fresh-draft-fixture");
        compare(service.sessionApiKey, "fresh-draft-fixture");
        compare(PluginService.loadPluginData("aiAssistant", "apiKey", "missing"), "");
        compare(PluginService.loadPluginData("aiAssistant", "providers", {}).gemini.apiKey, "");
        settings.editApiKey("remember-this-fixture");
        settings.setRememberApiKey(true);
        compare(service.resolveApiKey(), "remember-this-fixture");
        compare(service.sessionApiKey, "");
        compare(PluginService.loadPluginData("aiAssistant", "providers", {}).gemini.apiKey, "remember-this-fixture");
    }

    function test_session_keys_are_provider_scoped_and_survive_switches() {
        settings.setRememberApiKey(false);
        settings.editApiKey("gemini-session-fixture");
        settings.commitApiKey();
        settings.setProvider("anthropic");
        compare(service.sessionApiKey, "");
        compare(service.resolveApiKey(), "anthropic-fixture");
        settings.setProvider("gemini");
        compare(service.resolveApiKey(), "gemini-session-fixture");
        compare(field.text, "gemini-session-fixture");
    }

    function test_switching_provider_commits_draft_to_original_provider() {
        settings.setRememberApiKey(false);
        settings.editApiKey("pending-gemini-fixture");
        settings.setProvider("anthropic");
        compare(service.resolveApiKey(), "anthropic-fixture");
        compare(field.text, "anthropic-fixture");
        settings.setProvider("gemini");
        compare(service.resolveApiKey(), "pending-gemini-fixture");
        compare(field.text, "pending-gemini-fixture");
    }

    function test_empty_key_stays_empty_after_reload() {
        settings.editApiKey("");
        settings.commitApiKey();
        settings.load();
        compare(field.text, "");
        compare(service.resolveApiKey(), "");
        compare(PluginService.loadPluginData("aiAssistant", "providers", {}).gemini.apiKey, "");
    }

    function test_clearing_history_preserves_other_provider_and_saved_key() {
        const activeHash = service.computeConfigHash();
        const otherHash = "anthropic|https://api.anthropic.com";
        const otherChat = [{role: "user", content: "keep this chat", timestamp: 1, id: "other", status: "ok"}];
        const sessions = {};
        sessions[otherHash] = otherChat;
        service.restoreConversations({version: 3, sessions: sessions});
        service.providerConfigHash = activeHash;
        service.messagesModel.append({role: "user", content: "clear this", timestamp: 2, id: "active", status: "ok"});
        service.clearHistory(true);
        compare(service.messageCount, 0);
        compare(service.lastUserText, "");
        compare(service.conversationGroups[activeHash].tabs[0].messages.length, 0);
        compare(service.conversationGroups[otherHash].tabs[0].messages[0].content, "keep this chat");
        const persisted = JSON.parse(service.persistedSession);
        compare(persisted.conversationGroups[activeHash].tabs[0].messages.length, 0);
        compare(persisted.conversationGroups[otherHash].tabs[0].messages[0].content, "keep this chat");
        service.switchConfigHistory(otherHash);
        compare(service.messageCount, 1);
        service.switchConfigHistory(activeHash);
        compare(service.messageCount, 0);
        compare(service.resolveApiKey(), "old-gemini-fixture");
    }

    function test_clear_history_requires_confirmation_and_stopped_response() {
        const chat = createTemporaryObject(chatComponent, testCase, {aiService: service});
        verify(chat !== null);
        service.messagesModel.append({role: "user", content: "keep until confirmed", timestamp: 2, id: "active", status: "ok"});
        chat.requestClearHistory();
        verify(chat.showNewChatConfirm);
        compare(service.messageCount, 1);
        chat.showNewChatConfirm = false; // cancel
        compare(service.messageCount, 1);
        service.isStreaming = true;
        chat.requestClearHistory();
        verify(!chat.showNewChatConfirm);
        chat.confirmClearHistory();
        compare(service.messageCount, 1);
        service.isStreaming = false;
        chat.requestClearHistory();
        chat.confirmClearHistory();
        compare(service.messageCount, 0);
        verify(!chat.showNewChatConfirm);
    }

    function appendUser(text) {
        service.messagesModel.append({role: "user", content: text, timestamp: 2, id: text, status: "ok"});
    }

    function test_tabs_preserve_messages_drafts_and_selected_tab_on_restore() {
        const first = service.activeConversationId;
        appendUser("First conversation");
        service.conversationDraft = "unfinished first prompt";
        verify(service.createConversation());
        const second = service.activeConversationId;
        verify(second !== first);
        compare(service.messageCount, 0);
        compare(service.conversationDraft, "");
        appendUser("Second conversation");
        service.conversationDraft = "second draft";
        verify(service.selectConversation(first));
        compare(service.messagesModel.get(0).content, "First conversation");
        compare(service.lastUserText, "First conversation");
        compare(service.conversationDraft, "unfinished first prompt");
        service.saveSession();
        const saved = JSON.parse(service.persistedSession);
        compare(saved.version, 4);
        service.restoreConversations(saved);
        compare(service.activeConversationId, first);
        compare(service.conversationDraft, "unfinished first prompt");
        verify(service.selectConversation(second));
        compare(service.messagesModel.get(0).content, "Second conversation");
        compare(service.conversationDraft, "second draft");
    }

    function test_rename_close_and_clear_only_affect_target_tab() {
        const first = service.activeConversationId;
        appendUser("First");
        service.saveSession();
        verify(service.renameConversation(first, "My research"));
        verify(service.createConversation());
        const second = service.activeConversationId;
        appendUser("Second");
        service.clearHistory(true);
        verify(service.selectConversation(first));
        compare(service.conversations[0].title, "My research");
        compare(service.messageCount, 1);
        verify(service.closeConversation(second));
        compare(service.activeConversationId, first);
        compare(service.messageCount, 1);
        verify(!service.closeConversation(first));
        compare(service.conversations.length, 1);
        verify(!service.renameConversation(first, "  "));
    }

    function test_close_active_tab_selects_neighbor_and_does_not_resurrect_on_restore() {
        const first = service.activeConversationId;
        appendUser("Keep me");
        verify(service.createConversation());
        const removed = service.activeConversationId;
        appendUser("Remove me");
        verify(service.closeConversation(removed));
        compare(service.activeConversationId, first);
        compare(service.messagesModel.get(0).content, "Keep me");
        service.restoreConversations(JSON.parse(service.persistedSession));
        compare(service.conversations.length, 1);
        verify(!service.conversations.some(tab => tab.id === removed));
    }

    function test_tab_actions_are_blocked_while_streaming() {
        const first = service.activeConversationId;
        verify(service.createConversation());
        const second = service.activeConversationId;
        appendUser("Keep streaming chat");
        service.isStreaming = true;
        verify(!service.createConversation());
        verify(!service.selectConversation(first));
        verify(!service.renameConversation(second, "Wrong"));
        verify(!service.closeConversation(second));
        verify(!service.clearHistory(true));
        compare(service.activeConversationId, second);
        compare(service.messageCount, 1);
        service.isStreaming = false;
    }

    function test_new_chat_creates_tab_and_close_requires_confirmation() {
        const chat = createTemporaryObject(chatComponent, testCase, {aiService: service});
        const first = service.activeConversationId;
        appendUser("Keep original chat");
        chat.startNewChat();
        const second = service.activeConversationId;
        verify(second !== first);
        verify(!chat.showNewChatConfirm);
        compare(service.conversations.length, 2);
        chat.requestCloseConversation(first);
        verify(chat.showNewChatConfirm);
        compare(service.conversations.length, 2);
        chat.confirmClearHistory();
        compare(service.conversations.length, 1);
        compare(service.activeConversationId, second);
    }

    function test_provider_and_model_changes_preserve_tab_groups() {
        const first = service.activeConversationId;
        appendUser("Gemini first");
        verify(service.createConversation());
        const second = service.activeConversationId;
        appendUser("Gemini second");
        settings.saveActiveField("model", "different-model-fixture");
        compare(service.activeConversationId, second);
        compare(service.messageCount, 1);
        settings.setProvider("anthropic");
        compare(service.conversations.length, 1);
        compare(service.messageCount, 0);
        appendUser("Anthropic chat");
        settings.setProvider("gemini");
        compare(service.conversations.length, 2);
        compare(service.activeConversationId, second);
        compare(service.messagesModel.get(0).content, "Gemini second");
        verify(service.selectConversation(first));
        compare(service.messagesModel.get(0).content, "Gemini first");
    }
}
