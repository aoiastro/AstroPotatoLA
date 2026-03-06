import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }

            if viewModel.isDownloading {
                VStack {
                    ProgressView(value: viewModel.downloadProgress)
                    Text("Downloading Model: \(Int(viewModel.downloadProgress * 100))%")
                        .font(.caption)
                }
                .padding()
            }

            if !viewModel.isModelReady && !viewModel.isDownloading {
                Button("Download Model") {
                    Task {
                        await viewModel.downloadModel()
                    }
                }
                .padding()
            }

            HStack {
                TextField("Enter message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.isGenerating || !viewModel.isModelReady)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(inputText.isEmpty || viewModel.isGenerating || !viewModel.isModelReady ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || viewModel.isGenerating || !viewModel.isModelReady)
            }
            .padding()
        }
        .navigationTitle("AstroPotatoLA")
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.text)
                .padding(10)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(10)
            
            if !message.isUser { Spacer() }
        }
    }
}
