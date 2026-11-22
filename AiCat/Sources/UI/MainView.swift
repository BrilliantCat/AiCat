import SwiftUI

public struct MainView: View {
    @StateObject private var catHandler = CatActionHandler.shared
    @StateObject private var tamagotchi = TamagotchiManager.shared
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var certificateWatchdog = CertificateWatchdog.shared
    @StateObject private var fitnessCoach = CatFitnessCoach.shared
    @StateObject private var yogaCoach = YogaCoachTool.shared
    @StateObject private var speechRecognizer = OfflineSpeechRecognizer.shared
    @ObservedObject private var speechSynthesizer = CatSpeechSynthesizer.shared
    
    @State private var inputText: String = ""
    @State private var showCertificateInfo: Bool = false
    @State private var showModelManager: Bool = false
    @State private var showWardrobe: Bool = false
    @State private var showRAGManager: Bool = false
    
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
                
                // 2. Сертификатный баннер
                if certificateWatchdog.needsRenewal {
                    certificateBanner
                }
                
                // 3. Фитнес-панель (Отжимания / Приседания)
                if fitnessCoach.isWorkoutActive {
                    workoutLiveBanner
                }
                
                // 4. Панель йоги (при активной сессии)
                if yogaCoach.isSessionActive {
                    yogaLiveBanner
                }
                
                // 5. Предупреждение о микрофоне/речи при наличии ошибки
                if let err = speechRecognizer.errorMessage {
                    speechErrorBanner(err)
                }
                
                // 6. Интерактивная 3D-сцена с котиком (скрывается при вводе текста, освобождая весь экран под чат)
                if !isInputFocused {
                    ZStack(alignment: .bottom) {
                        Cat3DSceneView()
                            .frame(height: 220)
                            .transition(.opacity.combined(with: .scale))
                        
                        statusBadges
                    }
                    
                    // 7. Панель быстрых трюков (скрывается при клавиатуре)
                    actionChipsBar
                }
                
                // 8. Лента сообщений чата (занимает всё доступное пространство)
                messagesScrollView
                
                // 9. Поле ввода и микрофон
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
        .sheet(isPresented: $showRAGManager) {
            RAGManagerView()
        }
        .alert(isPresented: $showCertificateInfo) {
            Alert(
                title: Text("Обновление сертификата (7 дней)"),
                message: Text(certificateWatchdog.instructionsText),
                dismissButton: .default(Text("Понятно, сделаю!"))
            )
        }
        .onAppear {
            self.chatMessages = ChatStorage.shared.loadMessages()
        }
        .onChange(of: speechRecognizer.transcribedText) { newText in
            if speechRecognizer.isRecording && !newText.isEmpty {
                self.inputText = newText
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
                Text(modelManager.isModelLoaded ? "● Qwen 2.5 3B (GGUF Активна)" : "AiCat Офлайн ядро")
                    .font(.caption2)
                    .foregroundColor(modelManager.isModelLoaded ? .green : .cyan)
            }
            
            Spacer()
            
            // Очистка истории переписки
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
            
            // Документы и база знаний RAG
            Button(action: { showRAGManager = true }) {
                Image(systemName: "doc.text.magnifyingglass")
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
                Image(systemName: speechSynthesizer.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundColor(speechSynthesizer.isVoiceEnabled ? .green : .gray)
                    .font(.caption)
                Toggle("", isOn: $speechSynthesizer.isVoiceEnabled)
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
            
            Button("+1") {
                fitnessCoach.manualRecordRep()
            }
            .font(.caption)
            .bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.cyan.opacity(0.25))
            .foregroundColor(.cyan)
            .cornerRadius(10)
            
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
    
    // MARK: - Yoga Live HUD
    
    private var yogaLiveBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.mind.and.body")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(yogaCoach.currentExercise.name)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                    Text("⏱️ \(yogaCoach.remainingSeconds)с")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                }
                Text(yogaCoach.currentExercise.catComment)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Далее") {
                yogaCoach.nextPose()
            }
            .font(.caption)
            .bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.25))
            .foregroundColor(.green)
            .cornerRadius(10)
            
            Button("Стоп") {
                _ = yogaCoach.stopWorkout()
            }
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .cornerRadius(10)
        }
        .padding(10)
        .background(Color.green.opacity(0.12))
        .cornerRadius(14)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private func speechErrorBanner(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(msg)
                .font(.caption2)
                .foregroundColor(.yellow)
            Spacer()
            Button(action: { speechRecognizer.errorMessage = nil }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Certificate Banner
    
    private var certificateBanner: some View {
        Button(action: { showCertificateInfo = true }) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.yellow)
                Text("Сертификат истекает через \(certificateWatchdog.daysRemaining) дн. (Нажми для инструкции)")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.18))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Badges
    
    private var statusBadges: some View {
        HStack(spacing: 8) {
            BadgeView(icon: "fish.fill", text: "\(tamagotchi.satiety)%", color: .cyan)
            BadgeView(icon: "heart.fill", text: "\(tamagotchi.happiness)%", color: .pink)
            BadgeView(icon: "bolt.fill", text: "\(tamagotchi.energy)%", color: .yellow)
            
            Text(catHandler.state.statusText)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                )
        }
        .padding(.bottom, 4)
    }
    
    private var actionChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ActionChip(icon: "figure.mind.and.body", label: "Йога") {
                    let reply = yogaCoach.startWorkout()
                    addCatResponse(reply)
                }
                ActionChip(icon: "figure.strengthtraining.traditional", label: "Отжимания") {
                    let reply = CatFitnessCoach.shared.startPushups()
                    addCatResponse(reply)
                }
                ActionChip(icon: "figure.run", label: "Приседания") {
                    let reply = CatFitnessCoach.shared.startSquats()
                    addCatResponse(reply)
                }
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
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: chatMessages.count) { _ in
                if let last = chatMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            HStack {
                TextField("Скажи или спроси что-нибудь...", text: $inputText)
                    .focused($isInputFocused)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                
                if !inputText.isEmpty {
                    Button(action: { inputText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
            }
            .background(Color.white.opacity(0.08))
            .cornerRadius(20)
            
            Button(action: { toggleVoiceRecording() }) {
                Image(systemName: speechRecognizer.isRecording ? "waveform.circle.fill" : "mic.fill")
                    .font(.title3)
                    .foregroundColor(speechRecognizer.isRecording ? .red : .cyan)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            if !inputText.isEmpty {
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
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
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
        var savedName: String? = nil
        if let img = image {
            let name = "\(UUID().uuidString).jpg"
            savedName = name
            DispatchQueue.global(qos: .background).async {
                if let data = img.jpegData(compressionQuality: 0.85) {
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let target = docs.appendingPathComponent("Images").appendingPathComponent(name)
                    try? data.write(to: target, options: .atomic)
                }
            }
        }
        
        let catMsg = ChatMessage(
            sender: .cat,
            text: text,
            imageFileName: savedName
        )
        chatMessages.append(catMsg)
        ChatStorage.shared.saveMessages(chatMessages)
        
        if CatSpeechSynthesizer.shared.isVoiceEnabled {
            CatSpeechSynthesizer.shared.speak(text: text)
        }
    }
    
    private func toggleVoiceRecording() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if speechRecognizer.isRecording {
            speechRecognizer.stopListening()
            let recognized = speechRecognizer.transcribedText
            inputText = ""
            if !recognized.isEmpty {
                sendUserQuery(recognized)
            }
        } else {
            speechRecognizer.requestPermissions { granted in
                if granted {
                    do {
                        try self.speechRecognizer.startListening()
                    } catch {
                        print("Error starting recording: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct BadgeView: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }
}

public struct ChatMessage: Identifiable, Codable {
    public var id: UUID
    public enum Sender: String, Codable { case user, cat }
    public var sender: Sender
    public var text: String
    public var imageFileName: String?
    public var imageData: Data?
    
    public init(id: UUID = UUID(), sender: Sender, text: String, imageFileName: String? = nil, imageData: Data? = nil) {
        self.id = id
        self.sender = sender
        self.text = text
        self.imageFileName = imageFileName
        self.imageData = imageData
    }
    
    public var image: UIImage? {
        if let name = imageFileName {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docs.appendingPathComponent("Images").appendingPathComponent(name)
            if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
                return img
            }
        }
        if let data = imageData {
            return UIImage(data: data)
        }
        return nil
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
