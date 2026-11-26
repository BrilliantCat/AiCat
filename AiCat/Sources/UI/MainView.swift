import SwiftUI

public struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var catHandler = CatActionHandler.shared
    @StateObject private var tamagotchi = TamagotchiManager.shared
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
    @State private var showDebugLog: Bool = false
    @State private var showMediaStudio = false
    @State private var showPhoneControl = false
    @State private var waitingForReply = false
    @StateObject private var liveActivity = LiveActivityManager.shared
    @State private var showClearChat = false
    @State private var lastPet = Date.distantPast
    @AppStorage("aicat.autoChat") private var automaticChat = false
    @AppStorage("aicat.hordeConsent") private var hordeConsent = false
    @State private var askForOnline = false
    @State private var hideRequest = 0
    @State private var inRoom = true
    
    @FocusState private var isInputFocused: Bool
    
    @State private var chatMessages: [ChatMessage] = []
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Фон: глубокий темный Apple Dark
            LinearGradient(colors: [Color(red: 0.06, green: 0.10, blue: 0.16),
                                    Color(red: 0.13, green: 0.10, blue: 0.20),
                                    Color(red: 0.04, green: 0.07, blue: 0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

            
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
                
                if inRoom {
                    Group {
                        if (fitnessCoach.isWorkoutActive || yogaCoach.isSessionActive), let pose = catMotion {
                            LessonDemonstration(motion: pose, paused: yogaCoach.isPaused || fitnessCoach.isPaused,
                                                breath: yogaCoach.breathStep)
                        } else {
                            Cat3DSceneView(motion: catMotion, inRoom: true, isRoaming: tamagotchi.isRoaming,
                                           hideRequest: hideRequest,
                                           isVisible: !showWardrobe && !showMediaStudio && !showModelManager &&
                                       !showDebugLog && !showRAGManager && !showPhoneControl)
                        }
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 8)
                        .accessibilityLabel("Комната кота")
                        .accessibilityAction(named: "Погладить") { petCompanion() }
                    statusBadges.padding(.top, 8)
                    actionChipsBar
                } else {
                    messagesScrollView
                    if speechRecognizer.isTranscribing { ProgressView("Распознаю речь…") }
                    else if speechRecognizer.isRecording { Text("Слушаю. Нажми микрофон, чтобы закончить.").font(.caption) }
                    if waitingForReply { ProgressView("Кот думает…").tint(.cyan) }
                    inputBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in if phase != .active { CatPurrFeedback.shared.stop() } }
        .onChange(of: speechSynthesizer.isVoiceEnabled) { _, enabled in if !enabled { CatPurrFeedback.shared.stop() } }
        .onChange(of: speechSynthesizer.preferredVoiceID) { _, _ in previewVoice() }
        .onChange(of: speechSynthesizer.tone) { _, _ in previewVoice() }
        .onChange(of: speechSynthesizer.isSpeaking) { _, speaking in if speaking { CatPurrFeedback.shared.stop() } }
        .onChange(of: fitnessCoach.isWorkoutActive) { _, active in if active { inRoom = true } }
        .onChange(of: yogaCoach.isSessionActive) { _, active in if active { inRoom = true } }
        .onOpenURL { url in
            guard url.scheme == "aicat", let host = url.host, ["chat", "room"].contains(host) else { return }
            isInputFocused = false
            showWardrobe = false
            showModelManager = false
            showRAGManager = false
            showDebugLog = false
            showMediaStudio = false
            showPhoneControl = false
            inRoom = host == "room"
            if inRoom, let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "care" })?.value, let care = CatCare(rawValue: value) {
                _ = tamagotchi.care(care)
            }
        }
        .tint(.mint)
        .confirmationDialog("Очистить переписку?", isPresented: $showClearChat, titleVisibility: .visible) {
            Button("Очистить", role: .destructive) {
                ChatStorage.shared.clear()
                chatMessages = ChatStorage.shared.loadMessages()
            }
        }

        .sheet(isPresented: $showWardrobe) {
            WardrobeSheet()
        }
        .sheet(isPresented: $showModelManager) {
            ModelManagerView()
        }
        .sheet(isPresented: $showRAGManager) {
            RAGManagerView()
        }
        .sheet(isPresented: $showPhoneControl) { PhoneControlView() }
        .sheet(isPresented: $showMediaStudio) { MediaStudioView() }
        .sheet(isPresented: $showDebugLog) {
            DebugLogView()
        }
        .alert("Включить онлайн-ответы?", isPresented: $askForOnline) {
            Button("Включить") { hordeConsent = true; automaticChat = true }
            Button("Оставить офлайн", role: .cancel) {}
        } message: {
            Text("AI Horde обрабатывает запросы на компьютерах добровольцев. Туда отправится текст вопроса и до четырёх последних текстовых реплик онлайн-чата. При недоступности сервиса ответит AiCat на телефоне.")
        }
        .alert(isPresented: $showCertificateInfo) {
            Alert(
                title: Text("Обновление сертификата (7 дней)"),
                message: Text(certificateWatchdog.instructionsText),
                dismissButton: .default(Text("Понятно, сделаю!"))
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMediaStudio"))) { _ in showMediaStudio = true }
        .onAppear {
            self.chatMessages = ChatStorage.shared.loadMessages()
        }
        .onChange(of: speechRecognizer.transcribedText) { _, newText in
            if !newText.isEmpty {
                self.inputText = newText
            }
        }
        .onChange(of: speechRecognizer.isRecording) { _, recording in if recording { inRoom = false } }
    }

    private var catMotion: CatMotion? {
        if fitnessCoach.isWorkoutActive {
            return fitnessCoach.currentExerciseName.localizedCaseInsensitiveContains("присед") ? .squat : .pushUp
        }
        if yogaCoach.isSessionActive {
            return yogaCoach.currentExercise.motion
        }
        if waitingForReply { return .think }
        if speechSynthesizer.isSpeaking { return .talk }
        return nil
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AiCat").font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                Text(waitingForReply ? "Слушаю и думаю…" : catHandler.state.statusText)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.layoutPriority(1)
            Spacer(minLength: 4)
            Button {
                isInputFocused = false
                inRoom.toggle()
            } label: {
                Image(systemName: inRoom ? "bubble.left.and.bubble.right" : "pawprint.fill")
                    .frame(width: 44, height: 44)
            }.accessibilityLabel(inRoom ? "Открыть чат" : "Открыть комнату")
            Button { speechSynthesizer.isVoiceEnabled.toggle() } label: {
                Image(systemName: speechSynthesizer.isVoiceEnabled ? "speaker.wave.2" : "speaker.slash")
                    .frame(width: 44, height: 44)
            }.accessibilityLabel("Озвучка ответов")
            Menu {
                Button("Гардероб", systemImage: "tshirt") { showWardrobe = true }
                Menu("Голос кота", systemImage: "speaker.wave.2") {
                    Picker("Голос", selection: $speechSynthesizer.preferredVoiceID) {
                        Text("Автоматически").tag("")
                        ForEach(speechSynthesizer.russianVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    if speechSynthesizer.russianVoices.count == 1 { Text("На iPhone установлен один русский голос") }
                    Picker("Тембр", selection: $speechSynthesizer.tone) {
                        Text("Мягкий").tag("soft")
                        Text("Бархатный").tag("deep")
                        Text("Игривый").tag("bright")
                    }
                    Button("Послушать голос") {
                        speechSynthesizer.isVoiceEnabled = true
                        speechSynthesizer.speak(text: "Я здесь, кожаный. Рассказывай, как прошёл твой день?")
                    }
                }
                Button("Фото и аудио", systemImage: "camera") { showMediaStudio = true }
                Button("Телефон", systemImage: "iphone") { showPhoneControl = true }
                Button("Документы", systemImage: "doc.text") { showRAGManager = true }
                Button(automaticChat ? "Ответы: авто · перейти в офлайн" : "Ответы: офлайн · включить авто") {
                    if automaticChat { automaticChat = false }
                    else if hordeConsent { automaticChat = true }
                    else { askForOnline = true }
                }
                .disabled(waitingForReply)
                Button("Модели", systemImage: "cpu") { showModelManager = true }
                Button("Диагностика", systemImage: "waveform.path.ecg") { showDebugLog = true }
                Text(liveActivity.islandStatus)
                Button("Показать кота в острове", systemImage: "pawprint") {
                    tamagotchi.refreshAutonomousLife()
                }
                Divider()
                Button("Очистить чат", systemImage: "trash", role: .destructive) { showClearChat = true }
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
            }.accessibilityLabel("Меню AiCat")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // MARK: - Workout Live HUD
    
    private var workoutLiveBanner: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(fitnessCoach.currentExerciseName).fontWeight(.semibold)
                Spacer()
                Text("\(fitnessCoach.currentRepsCount) / \(fitnessCoach.targetReps)").monospacedDigit()
            }
            Text(fitnessCoach.catCheerMessage).font(.caption).foregroundStyle(.secondary)
            HStack {
                if fitnessCoach.isPushupWorkout {
                    Button(fitnessCoach.usingCamera ? "Датчик" : "Камера") { fitnessCoach.toggleCamera() }
                        .disabled(fitnessCoach.isPaused)
                        .accessibilityHint("Переключить источник автоматического счёта")
                }
                Button("+1") { fitnessCoach.manualRecordRep() }.disabled(fitnessCoach.isPaused)
                Spacer()
                Button(fitnessCoach.isPaused ? "Продолжить" : "Пауза") {
                    if fitnessCoach.isPaused { fitnessCoach.resume() } else { fitnessCoach.pause() }
                }
                Button("Стоп", role: .destructive) { fitnessCoach.stopWorkout() }
            }
            .buttonStyle(.bordered).controlSize(.small).font(.caption)
        }
        .font(.subheadline).padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal).padding(.vertical, 4)
    }

    private var yogaLiveBanner: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(yogaCoach.currentExercise.name).fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(yogaCoach.remainingSeconds) с").monospacedDigit().foregroundStyle(.mint)
            }
            Text(yogaCoach.currentExercise.catComment).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("\(yogaCoach.currentExerciseIndex + 1) из \(yogaCoach.routine.count)").foregroundStyle(.secondary)
                Spacer()
                Button(yogaCoach.isPaused ? "Продолжить" : "Пауза") {
                    if yogaCoach.isPaused { yogaCoach.resume() } else { yogaCoach.pause() }
                }
                Button("Далее") { yogaCoach.nextPose() }
                Button("Стоп", role: .destructive) { _ = yogaCoach.stopWorkout() }
            }
            .buttonStyle(.bordered).controlSize(.small).font(.caption)
        }
        .font(.subheadline).padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal).padding(.vertical, 4)
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
        HStack(spacing: 12) {
            Label("\(tamagotchi.satiety)%", systemImage: "fish.fill").foregroundStyle(.mint)
            Label("\(tamagotchi.happiness)%", systemImage: "heart.fill").foregroundStyle(.pink)
            Label("\(tamagotchi.energy)%", systemImage: "bolt.fill").foregroundStyle(.yellow)
            Spacer(minLength: 0)
            Image(systemName: liveActivity.islandStatus == "Кот в острове" ? "checkmark.circle" : "info.circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel(liveActivity.islandStatus)
        }
        .font(.caption2).padding(.horizontal, 16)
    }

    private var actionChipsBar: some View {
        HStack(spacing: 10) {
            Button { _ = tamagotchi.feedFish() } label: { Label("Кормить", systemImage: "fish") }
            Menu {
                Button("Мячик") { _ = tamagotchi.play() }
                Button("Прятки") { hideRequest += 1 }
                    .disabled(catMotion != nil || tamagotchi.isSleeping)
            } label: { Label("Играть", systemImage: "gamecontroller") }
            Menu {
                Button("Погладить", systemImage: "hand.draw") { petCompanion() }
                Button("Умыться") { _ = catHandler.execute(action: "wash") }.disabled(tamagotchi.isSleeping)
                if tamagotchi.isSleeping {
                    Button("Проснуться") { _ = tamagotchi.wake() }
                } else {
                    Button("Спать") { _ = tamagotchi.sleep() }
                }
                Divider()
                Button("Йога") { addCatResponse(yogaCoach.startWorkout()) }
                Button("Дыхание") { addCatResponse(yogaCoach.startWorkout(type: "breathing")) }
                Button("Разминка") { addCatResponse(yogaCoach.startWorkout(type: "mobility")) }
                Button("Планка") { addCatResponse(yogaCoach.startWorkout(type: "plank")) }
                Button("Отжимания") { addCatResponse(fitnessCoach.startPushups()) }
                Button("Приседания") { addCatResponse(fitnessCoach.startSquats()) }
            } label: { Label("Заняться", systemImage: "sparkles") }
        }
        .font(.system(.caption, design: .rounded, weight: .medium))
        .buttonStyle(.bordered).tint(.mint)
        .frame(maxWidth: .infinity).padding(.vertical, 6)
    }

    private func previewVoice() {
        speechSynthesizer.isVoiceEnabled = true
        speechSynthesizer.speak(text: "Я здесь, кожаный. Рассказывай, как прошёл твой день?")
    }

    private func petCompanion() {
        guard Date().timeIntervalSince(lastPet) > 2 else { return }
        lastPet = Date()
        _ = tamagotchi.petCat()
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
            .defaultScrollAnchor(.bottom)
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: chatMessages.count) { _, _ in
                if let last = chatMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 10) {
            HStack {
                TextField("Как прошёл твой день?", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit { submitInput() }
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
            
            Button(action: { toggleVoiceRecording() }) {
                Image(systemName: speechRecognizer.isRecording ? "waveform.circle.fill" : "mic.fill")
                    .font(.title3)
                    .foregroundColor(speechRecognizer.isRecording ? .red : .cyan)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(waitingForReply || speechRecognizer.isTranscribing)
            
            if !inputText.isEmpty {
                Button(action: {
                    submitInput()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                }.disabled(waitingForReply || speechRecognizer.isRecording || speechRecognizer.isTranscribing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    // MARK: - Logic & AI Chat
    
    private func submitInput() {
        guard !waitingForReply, !speechRecognizer.isRecording, !speechRecognizer.isTranscribing else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendUserQuery(text)
    }

    private func sendUserQuery(_ text: String) {
        guard !waitingForReply else { return }
        waitingForReply = true
        LiveActivityManager.shared.startOrUpdateActivity(status: "Думает над ответом", mood: "🤔", action: "Думает", recordAction: false)
        let history = Array(chatMessages.suffix(4))
        let useNetwork = automaticChat && hordeConsent
        let userMsg = ChatMessage(sender: .user, text: text)
        chatMessages.append(userMsg)
        ChatStorage.shared.saveMessages(chatMessages)
        
        Task {
            let (reply, image, source) = await LLMEngine.shared.conversation(text, history: history, automatic: useNetwork)
            await MainActor.run {
                self.waitingForReply = false
                if !yogaCoach.isSessionActive && !fitnessCoach.isWorkoutActive {
                    tamagotchi.refreshAutonomousLife()
                }
                self.addCatResponse(reply, image: image, source: source)
            }
        }
    }
    
    private func addCatResponse(_ text: String, image: UIImage? = nil, source: String? = nil) {
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
        
        var catMsg = ChatMessage(
            sender: .cat,
            text: text,
            imageFileName: savedName
        )
        catMsg.source = source
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
            Task { _ = await speechRecognizer.finishListening() }
        } else {
            speechRecognizer.requestPermissions { granted in
                if granted {
                    do {
                        try self.speechRecognizer.startListening()
                    } catch {
                        speechRecognizer.errorMessage = error.localizedDescription
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
    var source: String?
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
                if let source = message.source { Text(source).font(.caption2).foregroundStyle(.secondary) }
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
