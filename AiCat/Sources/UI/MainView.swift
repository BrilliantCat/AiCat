import SwiftUI

public struct MainView: View {
    @StateObject private var catHandler = CatActionHandler.shared
    @State private var inputText: String = ""
    @State private var voiceEnabled: Bool = true
    @State private var isListening: Bool = false
    @State private var showModelManager: Bool = false
    @State private var showWardrobe: Bool = false
    @State private var chatMessages: [ChatMessage] = [
        ChatMessage(sender: .cat, text: "Салют, кожаный! Я AiCat — твой локальный агент. Живу в A17 Pro, на серверы ничего не сливаю. Чем займемся?")
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Фон: глубокий темный киберпанк / Apple Dark
            Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header с тумблером озвучки и статусом Dynamic Island
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("AiCat")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            Text(catHandler.state.moodEmoji)
                                .font(.title3)
                        }
                        Text("Офлайн • iPhone 15 Pro (A17 Pro)")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                    
                    // Кнопка Гардероба
                    Button(action: { showWardrobe = true }) {
                        Image(systemName: "tshirt.fill")
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    
                    // Кнопка Управления Моделями
                    Button(action: { showModelManager = true }) {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    
                    // Ползунок озвучки голосом
                    HStack(spacing: 6) {
                        Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundColor(voiceEnabled ? .green : .gray)
                            .font(.footnote)
                        Toggle("", isOn: $voiceEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Интерактивная 3D-сцена с котиком (погладить, покрутить)
                ZStack(alignment: .bottom) {
                    Cat3DSceneView()
                        .frame(height: 250)
                    
                    // Бейдж статуса
                    Text(catHandler.state.statusText)
                        .font(.caption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.bottom, 8)
                }
                
                // Панель быстрых трюков для котика
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ActionChip(icon: "pawprint.fill", label: "Повисни") {
                            sendCatCommand("Повисни на лапках под Dynamic Island")
                        }
                        ActionChip(icon: "tshirt.fill", label: "Оденься") {
                            sendCatCommand("Оденься в стильный прикид")
                        }
                        ActionChip(icon: "figure.roll", label: "Кувырок") {
                            sendCatCommand("Сделай кувырок")
                        }
                        ActionChip(icon: "sparkles", label: "Помойся") {
                            sendCatCommand("Помойся лапкой")
                        }
                        ActionChip(icon: "gamecontroller.fill", label: "Поиграй") {
                            sendCatCommand("Поиграй с лазером")
                        }
                        ActionChip(icon: "calendar", label: "Планы на сегодня") {
                            sendUserQuery("Какие у меня планы и напоминания на сегодня?")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Лента сообщений
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatMessages) { msg in
                                MessageBubble(message: msg)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                
                // Поле ввода запроса и кнопка голосового вызова
                HStack(spacing: 10) {
                    TextField("Скажи или спроси что-нибудь...", text: $inputText)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    // Кнопка микрофона
                    Button(action: {
                        toggleVoiceRecording()
                    }) {
                        Image(systemName: isListening ? "waveform.circle.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(isListening ? .red : .cyan)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    // Кнопка отправки текста
                    if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: {
                            let text = inputText
                            inputText = ""
                            sendUserQuery(text)
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
        }
        .sheet(isPresented: $showModelManager) {
            ModelManagerView()
        }
        .sheet(isPresented: $showWardrobe) {
            WardrobeSheet()
        }
    }
    
    private func sendUserQuery(_ text: String) {
        chatMessages.append(ChatMessage(sender: .user, text: text))
        
        // Симулируем ответ локальной модели с юмором AiCat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let reply = "Принял задачу! Проверяю твои локальные данные в памяти A17 Pro. Все под контролем, кожаный."
            chatMessages.append(ChatMessage(sender: .cat, text: reply))
        }
    }
    
    private func sendCatCommand(_ command: String) {
        chatMessages.append(ChatMessage(sender: .user, text: command))
        
        let response = catHandler.execute(
            action: command.contains("Повисни") ? "hang_on_island" :
                    command.contains("Оденься") ? "dress_up" :
                    command.contains("Кувырок") ? "somersault" :
                    command.contains("Помойся") ? "wash" : "play"
        )
        
        chatMessages.append(ChatMessage(sender: .cat, text: response))
    }
    
    private func toggleVoiceRecording() {
        isListening.toggle()
        if isListening {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }
}

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public enum Sender { case user, cat }
    public let sender: Sender
    public let text: String
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user { Spacer() }
            
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    message.sender == .user ?
                    Color.cyan.opacity(0.3) :
                    Color.white.opacity(0.12)
                )
                .cornerRadius(16)
            
            if message.sender == .cat { Spacer() }
        }
    }
}

struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .bold()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.2))
            .foregroundColor(.cyan)
            .cornerRadius(16)
        }
    }
}
