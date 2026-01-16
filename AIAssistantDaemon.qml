import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import "."

Item {
    id: root

    // Injected by PluginService
    property var pluginService: null
    property string pluginId: "aiAssistant"

    function toggle() {
        // Toggle the instance on the first screen for now
        // In a future update, we can detect the focused screen.
        if (variants.instances.length > 0) {
            variants.instances[0].toggle();
        }
    }

            // Logic Component (Global for all variants)
            AIAssistantService {
                id: aiLogic
                pluginId: root.pluginId
                Component.onCompleted: console.log("DEBUG: AIAssistantService initialized")
            }
        Component.onCompleted: console.log("DEBUG: Daemon initialized, aiService:", aiLogic)

        Variants {
            id: variants
            model: Quickshell.screens

            delegate: DankSlideout {
                id: slideout
                required property var modelData
                title: "AI Assistant"
                slideoutWidth: 480
                expandable: true
                expandedWidthValue: 960

                content: AIAssistant {
                    aiService: aiLogic
                    onHideRequested: slideout.hide()
                }
            }
        }}
