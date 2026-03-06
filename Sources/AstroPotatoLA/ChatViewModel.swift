import Foundation
import LocalLLMClient
import LocalLLMClientMLX

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

    private var session: LLMSession?
    
    // Using a small quantized model for mobile tests
    private let modelConfig = LLMSession.DownloadModel.mlx(
        id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        parameter: .init(
            temperature: 0.7,
            topP: 0.9
        )
    )

    func downloadModel() async {
        isDownloading = true
        do {
            try await modelConfig.downloadModel { progress in
                Task { @MainActor in
                    self.downloadProgress = progress
                }
            }
            session = LLMSession(model: modelConfig)
            // session?.messages = [.system("You are a helpful AI assistant.")]
            isModelReady = true
        } catch {
            print("Failed to download model: \(error)")
            messages.append(ChatMessage(text: "Error loading model: \(error.localizedDescription)", isUser: false))
        }
        isDownloading = false
    }

    func sendMessage(_ text: String) async {
        guard let session = session, isModelReady else { return }
        
        messages.append(ChatMessage(text: text, isUser: true))
        let responseIndex = messages.count
        messages.append(ChatMessage(text: "", isUser: false))
        isGenerating = true

        do {
            var currentResponse = ""
            for try await chunk in session.streamResponse(to: text) {
                currentResponse += chunk
                messages[responseIndex] = ChatMessage(text: currentResponse, isUser: false)
            }
        } catch {
            print("Generation error: \(error)")
            messages[responseIndex] = ChatMessage(text: "Error generating response: \(error.localizedDescription)", isUser: false)
        }
        
        isGenerating = false
    }
}
