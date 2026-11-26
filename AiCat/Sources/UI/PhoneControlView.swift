import SwiftUI

struct PhoneControlView: View {
    @State private var brightness = 50.0
    @State private var minutes = "5"
    @State private var query = ""
    @State private var shortcut = ""
    @State private var site = "https://"
    @State private var status = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Телефон") {
                    Button("Узнать заряд") { run("battery") }
                    Button("Узнать яркость") { run("brightness_read") }
                    Slider(value: $brightness, in: 0...100, step: 1)
                    Button("Яркость \(Int(brightness))%") { run("brightness", String(Int(brightness))) }
                    Button("Настройки AiCat") { run("settings") }
                }
                Section("Таймер") {
                    TextField("Минуты", text: $minutes).keyboardType(.decimalPad)
                    Button("Запустить") { run("timer_start", String((Double(minutes.replacingOccurrences(of: ",", with: ".")) ?? 0) * 60)) }
                    Button("Отменить") { run("timer_cancel") }
                }
                Section("Карты и браузер") {
                    TextField("Место или адрес", text: $query)
                    Button("Найти на карте") { run("maps", query) }
                    TextField("https://", text: $site).textInputAutocapitalization(.never).keyboardType(.URL)
                    Button("Открыть сайт") { run("open_url", site) }
                }
                Section("Команды iOS") {
                    TextField("Точное название установленной команды", text: $shortcut)
                    Button("Запустить команду") { run("run_shortcut", shortcut) }
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
    private func run(_ command: String, _ value: String = "") {
        Task { status = await PhoneControlTool.shared.execute(command: command, value: value) }
    }
}
