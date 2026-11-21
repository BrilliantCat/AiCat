import SwiftUI

public struct MainView: View {
    @StateObject private var catHandler = CatActionHandler.shared
    @StateObject private var tamagotchi = TamagotchiManager.shared
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var certificateWatchdog = CertificateWatchdog.shared
    @StateObject private var fitnessCoach = CatFitnessCoach.shared
    
    @State private var inputText: String = ""
    @State private var voiceEnabled: Bool = true
    @State private var isListening: Bool = false
    @State private var showCertificateInfo: Bool = false
    @State private var showModelManager: Bool = false
    @State private var showWardrobe: Bool = false
    
    @FocusState private var isInputFocused: Bool
    
    @State private var chatMessages: [ChatMessage] = []
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Фон: глубокий темный Apple Dark
            Color(red: 0.07, green: 0.08, blue: 0.11).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Верхняя панель управления
                headerView
                
                // 2. Сертификатный баннер (если осталось мало дней)
                if certificateWatchdog.needsRenewal {
                    certificateBanner
                }
                
                // 3. Фитнес-панель (появляется только во время тренировки)
                if fitnessCoach.isWorkoutActive {
                    workoutLiveBanner
                }
                
                // 4. Интерактивная 3D-сцена с котиком (плавно сворачивается в компактный аватар при наборе текста)
                if !isInputFocused {
                    ZStack(alignment: .bottom) {
                        Cat3DSceneView()
                            .frame(height: 220)
                            .transition(.opacity.combined(with: .scale))
                        
                        statusBadges
                    }
                }
                
                // 5. Панель быстрых трюков
                actionChipsBar
                
                // 6. Лента сообщений чата (занимает весь свободный экран)
                messagesScrollView
                
                // 7. Поле ввода и микрофон
                inputBar
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isInputFocused)
        .sheet(isPresented: $showWardrobe) {
            WardrobeSheet()
        }
        .sheet(isPresented: $showModelManager) {
            ModelManagerView()
        }
        .alert(isPresented: $showCertificateInfo) {
            Alert(
                title: Text("Обновление сертификата (7 дней)"),
                message: Text(certificateWatchdog.instructionsText),
                dismissButton: .default(Text("Понятно, сделаю!"))
            )
        }
        .onAppear {
            // Загружаем сохраненную историю диалога
            self.chatMessages = ChatStorage.shared.loadMessages()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("AiCat")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                    Text(catHandler.state.moodEmoji)
                        .font(.headline)
                }
                Text(modelManager.isModelLoaded ? "● Qwen 2.5 3B (GGUF Активна)" : "Офлайн A17 Pro (Поиск GGUF)")
                    .font(.caption2)
                    .foregroundColor(modelManager.isModelLoaded ? .green : .cyan)
            }
            
            Spacer()
            
            // Очистка чата
            Button(action: {
                ChatStorage.shared.clear()
                chatMessages = ChatStorage.shared.loadMessages()
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.gray)
                    .font(.caption)
                    .padding(7)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            
            // Гардероб
            Button(action: { showWardrobe = true }) {
                Image(systemName: "tshirt.fill")
                    .foregroundColor(.cyan)
                    .padding(7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            
            // Меню моделей
            Button(action: { showModelManager = true }) {
                Image(systemName: "cpu.fill")
                    .foregroundColor(modelManager.isModelLoaded ? .green : .cyan)
                    .padding(7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            
            // Тумблер озвучки голосом
            HStack(spacing: 6) {
                Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundColor(voiceEnabled ? .green : .gray)
                    .font(.caption)
                Toggle("", isOn: $voiceEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }
    
    // MARK: - Workout Live HUD
    
    private var workoutLiveBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(fitnessCoach.currentExerciseName): \(fitnessCoach.currentRepsCount) из \(fitnessCoach.targetReps)")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                Text(fitnessCoach.catCheerMessage)
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
            
            Spacer()
            
            Button("Стоп") {
                fitnessCoach.stopWorkout()
            }
            .font(.caption)
            .bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.25))
            .foregroundColor(.red)
            .cornerRadius(10)
        }
        .padding(10)
        .background(Color.cyan.opacity(0.12))
        .cornerRadius(14)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var certificateBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Сертификат: \(certificateWatchdog.daysRemaining) дн. Нажми для инфо!")
                .font(.caption2)
                .foregroundColor(.white)
            Spacer()
            Button("Инфо") { showCertificateInfo = true }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.3))
                .cornerRadius(8)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var statusBadges: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Text("🐟 \(tamagotchi.satiety)%")
                    .font(.caption2)
                    .foregroundColor(.cyan)
                Text("❤️ \(tamagotchi.happiness)%")
                    .font(.caption2)
                    .foregroundColor(.pink)
                Text("⚡ \(tamagotchi.energy)%")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            
            Text(catHandler.state.statusText)
                .font(.caption2)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                )
        }
        .padding(.bottom, 4)
    }
    
    private var actionChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ActionChip(icon: "fish.fill", label: "Покормить") {
                    let reply = tamagotchi.feedFish()
                    addCatResponse(reply)
                }
                ActionChip(icon: "figure.roll", label: "Кувырок") {
                    let reply = catHandler.execute(action: "somersault")
                    addCatResponse(reply)
                }
                ActionChip(icon: "sparkles", label: "Помойся") {
                    let reply = catHandler.execute(action: "wash")
                    addCatResponse(reply)
                }
                ActionChip(icon: "pawprint.fill", label: "Повисни") {
                    let reply = catHandler.execute(action: "hang_on_island")
                    addCatResponse(reply)
                }
                ActionChip(icon: "paintpalette.fill", label: "Нарисуй арт") {
                    sendUserQuery("Нарисуй неоновый киберпанк город с летающими машинами")
                }
                ActionChip(icon: "figure.strengthtraining.traditional", label: "Отжимания") {
                    let reply = CatFitnessCoach.shared.startPushups()
                    addCatResponse(reply)
                }
                ActionChip(icon: "music.note", label: "Музыка") {
                    let reply = MusicTool.shared.generateBeat(style: "lo-fi")
                    addCatResponse(reply)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(chatMessages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)
            }
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: chatMessages.count) { _ in
                if let last = chatMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: isInputFocused) { focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if let last = chatMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Скажи или спроси что-нибудь...", text: $inputText)
                .focused($isInputFocused)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(18)
                .foregroundColor(.white)
            
            if isInputFocused {
                Button(action: { isInputFocused = false }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.gray)
                }
            }
            
            Button(action: { toggleVoiceRecording() }) {
                Image(systemName: isListening ? "waveform.circle.fill" : "mic.fill")
                    .font(.title3)
                    .foregroundColor(isListening ? .red : .cyan)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: {
                    let text = inputText
                    inputText = ""
                    sendUserQuery(text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Logic & AI Chat
    
    private func sendUserQuery(_ text: String) {
        let userMsg = ChatMessage(sender: .user, text: text)
        chatMessages.append(userMsg)
        ChatStorage.shared.saveMessages(chatMessages)
        
        Task {
            let (reply, image) = await LLMEngine.shared.generate(prompt: text)
            await MainActor.run {
                self.addCatResponse(reply, image: image)
            }
        }
    }
    
    private func addCatResponse(_ text: String, image: UIImage? = nil) {
        let catMsg = ChatMessage(
            sender: .cat,
            text: text,
            imageData: image?.jpegData(compressionQuality: 0.85)
        )
        chatMessages.append(catMsg)
        ChatStorage.shared.saveMessages(chatMessages)
        
        if voiceEnabled {
            CatSpeechSynthesizer.shared.speak(text: text)
        }
    }
    
    private func toggleVoiceRecording() {
        isListening.toggle()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if isListening {
            try? OfflineSpeechRecognizer.shared.startListening()
        } else {
            OfflineSpeechRecognizer.shared.stopListening()
            let recognized = OfflineSpeechRecognizer.shared.transcribedText
            if !recognized.isEmpty {
                sendUserQuery(recognized)
            }
        }
    }
}

public struct ChatMessage: Identifiable, Codable {
    public var id: UUID
    public enum Sender: String, Codable { case user, cat }
    public var sender: Sender
    public var text: String
    public var imageData: Data?
    
    public init(id: UUID = UUID(), sender: Sender, text: String, imageData: Data? = nil) {
        self.id = id
        self.sender = sender
        self.text = text
        self.imageData = imageData
    }
    
    public var image: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user { Spacer() }
            
            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.white)
                
                if let img = message.image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 240, maxHeight: 240)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                        )
                    
                    Button(action: {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    }) {
                        Label("Сохранить в Фото", systemImage: "square.and.arrow.down")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                message.sender == .user ?
                Color.cyan.opacity(0.28) :
                Color.white.opacity(0.11)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.cyan.opacity(0.18))
            .foregroundColor(.cyan)
            .cornerRadius(14)
        }
    }
}
