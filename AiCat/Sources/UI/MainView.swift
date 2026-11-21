import SwiftUI

public struct MainView: View {
    @StateObject private var catHandler = CatActionHandler.shared
    @StateObject private var tamagotchi = TamagotchiManager.shared
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var certificateWatchdog = CertificateWatchdog.shared
    
    @State private var inputText: String = ""
    @State private var voiceEnabled: Bool = true
    @State private var isListening: Bool = false
    @State private var showCertificateInfo: Bool = false
    @State private var showModelManager: Bool = false
    @State private var showWardrobe: Bool = false
    @State private var islandCatWalkOffset: CGFloat = -40
    @State private var islandCatDirection: CGFloat = 1
    
    @FocusState private var isInputFocused: Bool
    
    @State private var chatMessages: [ChatMessage] = [
        ChatMessage(sender: .cat, text: "Салют, кожаный! Я AiCat — твой 3D-агент в черных очках. Моделирую мысли в чипе A17 Pro. Погладь меня по голове, нажми трюки или спроси что угодно!")
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Фон: темный Apple Dark
            Color(red: 0.07, green: 0.08, blue: 0.11).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Dynamic Island Интерактивный кошачий островок
                dynamicIslandHabitat
                
                // 2. Шапка с тумблером голоса и кнопками
                headerView
                
                // 3. Сертификатный баннер (при необходимости)
                if certificateWatchdog.needsRenewal {
                    certificateBanner
                }
                
                // 4. Интерактивная 3D-сцена с котиком (адаптивная высота при открытии клавиатуры)
                ZStack(alignment: .bottom) {
                    Cat3DSceneView()
                        .frame(height: isInputFocused ? 115 : 220)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isInputFocused)
                    
                    statusBadges
                }
                
                // 5. Панель быстрых трюков
                actionChipsBar
                
                // 6. Лента сообщений чата
                messagesScrollView
                
                // 7. Поле ввода и микрофон
                inputBar
            }
        }
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
            startIslandCatPatrol()
        }
    }
    
    // MARK: - Dynamic Island Habitat
    
    private var dynamicIslandHabitat: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                // Бегающий мини-котик по островку
                HStack(spacing: 4) {
                    Text("🐾")
                        .font(.caption2)
                        .opacity(0.8)
                    Text("🐱🕶️")
                        .font(.subheadline)
                        .offset(x: islandCatWalkOffset)
                        .scaleEffect(x: islandCatDirection, y: 1.0)
                }
                .onTapGesture {
                    let reply = catHandler.execute(action: "somersault")
                    addCatResponse(reply)
                }
                
                Text("AiCat Island")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                
                Button(action: {
                    let reply = catHandler.execute(action: "hang_on_island")
                    addCatResponse(reply)
                }) {
                    Text("Повисни")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.25))
                        .foregroundColor(.cyan)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.85))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
            )
            Spacer()
        }
        .padding(.top, 4)
    }
    
    private func startIslandCatPatrol() {
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                if islandCatWalkOffset > 25 {
                    islandCatWalkOffset = -35
                    islandCatDirection = -1
                } else {
                    islandCatWalkOffset = 30
                    islandCatDirection = 1
                }
            }
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
        .padding(.top, 4)
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
                    sendUserQuery("Нарисуй кибер-кота в черных очках в стиле неонового киберпанка")
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
        chatMessages.append(ChatMessage(sender: .user, text: text))
        
        Task {
            let (reply, image) = await LLMEngine.shared.generate(prompt: text)
            await MainActor.run {
                self.addCatResponse(reply, image: image)
            }
        }
    }
    
    private func addCatResponse(_ text: String, image: UIImage? = nil) {
        chatMessages.append(ChatMessage(sender: .cat, text: text, image: image))
        
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

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public enum Sender { case user, cat }
    public let sender: Sender
    public let text: String
    public var image: UIImage? = nil
    
    public init(sender: Sender, text: String, image: UIImage? = nil) {
        self.sender = sender
        self.text = text
        self.image = image
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
