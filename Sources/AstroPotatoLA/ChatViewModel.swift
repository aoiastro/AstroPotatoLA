import Foundation
import MLX
import MLXLLM
import MLXLMCommon

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var isModelReady = false
    @Published var isGenerating = false

    var session: ChatSession?
    
    // Using a light-weight MLX model
    private let modelConfiguration = ModelConfiguration(
        id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
    )

    func downloadModel() async {
        guard !isModelReady else { return }
        isDownloading = true
        
        do {
            let container = try await Task.detached(priority: .userInitiated) {
                try await LLMModelFactory.shared.loadContainer(
                    configuration: await self.modelConfiguration
                ) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress.fractionCompleted
                    }
                }
            }.value
            
            self.session = ChatSession(
                container,
                instructions: "You are a helpful AI assistant.",
                generateParameters: GenerateParameters(temperature: 0.7)
            )
            
            isModelReady = true
        } catch {
            print("Failed to start MLX model: \(error)")
            messages.append(ChatMessage(text: "Error loading model: \(error.localizedDescription)", isUser: false))
        }
        isDownloading = false
    }

    func sendMessage(_ text: String) async {
        guard let session = session, isModelReady else { return }
        
        // MLX requires prompts properly formatted, but ChatSession wraps generation logic.
        messages.append(ChatMessage(text: text, isUser: true))
        let responseIndex = messages.count
        messages.append(ChatMessage(text: "", isUser: false))
        isGenerating = true

        do {
            let response = try await session.respond(to: text)
            messages[responseIndex] = ChatMessage(text: response, isUser: false)
        } catch {
            print("Generation error: \(error)")
            messages[responseIndex] = ChatMessage(text: "Error generating response: \(error.localizedDescription)", isUser: false)
        }
        
        isGenerating = false
    }
}
