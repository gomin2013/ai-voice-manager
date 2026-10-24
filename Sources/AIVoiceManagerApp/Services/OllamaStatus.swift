import Foundation
import Observation

/// Is Ollama running and which models it has — for AI Providers. The chosen model is the AI Agent's
/// (`AgentSettings`, still stored as `ollama.model`), so there is one writer.
@MainActor
@Observable
final class OllamaStatus {
    private(set) var models: [String] = []
    private(set) var isRunning = false

    /// On launch and "Check again".
    func probe() async {
        models = (try? await AIService.listModels(.ollama, apiKey: "")) ?? []
        isRunning = !models.isEmpty
    }
}
