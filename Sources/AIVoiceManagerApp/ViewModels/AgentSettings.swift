import Foundation
import Observation

/// The AI Agent's provider and model (Hosts Manager's five), shared by AI Providers › AI Agent, the AI Agent panel
/// and the scene's Polish / Add pauses. The Keychain is read here — at launch and on a change — never in `body`.
@MainActor
@Observable
final class AgentSettings {
    private(set) var settings = AISettings.load()
    /// The provider's models for the menus; empty until listed (or when the provider has no model list).
    private(set) var models: [String] = []

    var isConfigured: Bool { settings.isConfigured }

    /// What the AI Agent header and the scene's ✦ show: the model, or the provider when it has no model.
    var label: String {
        guard settings.isConfigured else { return localized("ai.notConfigured") }
        return settings.provider.needsModel ? settings.model : settings.provider.displayName
    }

    /// Switching provider loads that provider's saved model and key instead of carrying the old ones over.
    func select(_ provider: AIProvider) {
        settings = AISettings.load(provider: provider)
        settings.save()
        models = []
    }

    func setModel(_ model: String) {
        settings.model = model.trimmingCharacters(in: .whitespaces)
        settings.save()
    }

    /// OpenAI / Claude key (Gemini's is the Voices key, saved there).
    func setKey(_ key: String) {
        settings.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.save()
        models = []
    }

    /// After the Voices tab saved or removed the Gemini key.
    func reload() { settings = AISettings.load(provider: settings.provider) }

    func loadModels() async {
        let current = settings
        guard current.provider.needsModel, !current.provider.needsAPIKey || !current.apiKey.isEmpty else {
            models = []
            return
        }
        let listed = (try? await AIService.listModels(current.provider, apiKey: current.apiKey)) ?? []
        guard current.provider == settings.provider else { return }   // switched while listing
        models = listed
        if settings.model.isEmpty, let first = listed.first { setModel(first) }
    }
}
