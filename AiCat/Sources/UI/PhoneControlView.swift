import SwiftUI
import MediaPlayer

struct PhoneControlView: View {
    @State private var brightness = 50.0
    @State private var minutes = "5"
    @State private var query = ""
    @State private var shortcut = ""
    @State private var site = "https://"
    @State private var status = ""
    @State private var recipient = ""
    @State private var bodyText = ""
    @State private var phrase = ""
    @State private var aliases = PhoneCommand.savedShortcuts
    @State private var busy = false
    @AppStorage("aicat.phone.voiceRun") private var voiceRun = true
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Телефон") {
                    Button("Состояние iPhone") { run("device_status") }
                    Toggle("Выполнять распознанные голосовые команды", isOn: $voiceRun)
                    HStack {
                        Text("Фонарик")
                        Spacer()
                        Button("Вкл.") { run("flashlight_on") }
                        Button("Выкл.") { run("flashlight_off") }
                    }.buttonStyle(.borderless)
                    Button("Узнать заряд") { run("battery") }
                    Button("Узнать яркость") { run("brightness_read") }
                    Slider(value: $brightness, in: 0...100, step: 1)
                    Button("Яркость \(Int(brightness))%") { run("brightness", String(Int(brightness))) }
                    Button("Настройки AiCat") { run("settings") }
                }
                Section("Связь") {
                    TextField("Контакт, номер или email", text: $recipient)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Текст сообщения", text: $bodyText, axis: .vertical)
                    Menu("Связаться") {
                        Button("Позвонить") { run("call", recipient) }
                        Button("Видеозвонок FaceTime") { run("facetime", recipient) }
                        Button("Подготовить SMS") { run("sms_draft", recipient, bodyText) }
                        Button("Подготовить письмо") { run("mail_draft", recipient, bodyText) }
                    }.disabled(recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Звук и музыка") {
                    SystemVolumeControl().frame(height: 34).accessibilityLabel("Громкость")
                    Menu("Управлять приложением «Музыка»") {
                        Button("Что играет") { run("music_now") }
                        Button("Продолжить") { run("music_resume") }
                        Button("Пауза") { run("music_pause") }
                        Button("Следующий трек") { run("music_next") }
                        Button("Предыдущий трек") { run("music_previous") }
                    }
                }
                Section("Расписание") {
                    Menu("Календарь") {
                        Button("Сегодня") { run("agenda_today") }
                        Button("Завтра") { run("agenda_tomorrow") }
                    }
                    Menu("Напоминания") {
                        Button("Сегодня") { run("reminders_today") }
                        Button("Завтра") { run("reminders_tomorrow") }
                    }
                }
                Section("Таймер") {
                    TextField("Минуты", text: $minutes).keyboardType(.decimalPad)
                    Button("Запустить") { run("timer_start", String((Double(minutes.replacingOccurrences(of: ",", with: ".")) ?? 0) * 60)) }
                    Button("Сколько осталось") { run("timer_status") }
                    Button("Отменить") { run("timer_cancel") }
                }
                Section("Карты и браузер") {
                    TextField("Место или адрес", text: $query)
                    Button("Найти на карте") { run("maps", query) }
                    Menu("Проложить маршрут") {
                        Button("Пешком") { run("route_walk", query) }
                        Button("На машине") { run("route_drive", query) }
                        Button("На транспорте") { run("route_transit", query) }
                    }.disabled(query.isEmpty)
                    Button("Найти в интернете") { run("web_search", query) }.disabled(query.isEmpty)
                    TextField("https://", text: $site).textInputAutocapitalization(.never).keyboardType(.URL)
                    Button("Открыть сайт") { run("open_url", site) }
                }
                Section("Команды iOS") {
                    TextField("Точное название установленной команды", text: $shortcut)
                    Button("Запустить команду") { run("run_shortcut", shortcut) }
                    Button("Открыть «Команды»") { run("shortcuts_app") }
                    TextField("Фраза, например «Включи Wi-Fi»", text: $phrase)
                    Button("Связать фразу с командой") {
                        let key = PhoneCommand.phraseKey(phrase)
                        aliases[key] = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserDefaults.standard.set(aliases, forKey: PhoneCommand.shortcutsKey)
                        status = "Теперь можно сказать «\(phrase)»."
                        phrase = ""
                    }
                    .disabled(PhoneCommand.phraseKey(phrase).isEmpty || shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    ForEach(aliases.keys.sorted(), id: \.self) { key in
                        HStack {
                            Button { phrase = key; shortcut = aliases[key] ?? "" } label: {
                                VStack(alignment: .leading) { Text(key); Text(aliases[key] ?? "").font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                aliases.removeValue(forKey: key)
                                UserDefaults.standard.set(aliases, forKey: PhoneCommand.shortcutsKey)
                            } label: { Image(systemName: "minus.circle") }
                            .accessibilityLabel("Отвязать фразу " + key)
                        }.buttonStyle(.borderless)
                    }
                    Text("Создай команду в приложении «Команды» и укажи её имя. Так можно запускать свои сценарии Wi-Fi, Bluetooth, фокусирования и других доступных действий.").font(.caption)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !status.isEmpty {
                    Text(status).frame(maxWidth: .infinity, alignment: .leading)
                        .padding().background(.regularMaterial)
                }
            }
            .onAppear { brightness = Double(UIScreen.main.brightness) * 100 }
            .navigationTitle("Телефон")
            .toolbar { Button("Готово") { dismiss() } }
        }
    }
    private func run(_ command: String, _ value: String = "", _ detail: String = "") {
        guard !busy else { return }
        busy = true
        status = "Выполняю…"
        Task {
            status = await PhoneControlTool.shared.execute(command: command, value: value, detail: detail)
            busy = false
        }
    }
}

private struct SystemVolumeControl: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView { MPVolumeView(frame: .zero) }
    func updateUIView(_ view: MPVolumeView, context: Context) {}
}
