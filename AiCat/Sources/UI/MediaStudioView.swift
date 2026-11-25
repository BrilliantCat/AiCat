import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Vision
import AVFoundation

struct MediaStudioView: View {
    @StateObject private var audio = AudioFileTool()
    @ObservedObject private var music = MusicTool.shared
    @State private var photoItem: PhotosPickerItem?
    @State private var picture: UIImage?
    @State private var camera = false
    @State private var importer = false
    @State private var audioInput: URL?
    @State private var output: URL?
    @State private var text = ""
    @State private var start = "0"
    @State private var end = "10"
    @State private var status = ""
    @State private var busy = false
    @State private var scanning = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Фото и камера") {
                    PhotosPicker("Выбрать фото", selection: $photoItem, matching: .images)
                    Button("Посмотреть через камеру") {
                        Task {
                            let allowed = await AVCaptureDevice.requestAccess(for: .video)
                            if allowed && UIImagePickerController.isSourceTypeAvailable(.camera) {
                                camera = true
                            } else { status = "Камера недоступна. Проверь разрешение в настройках AiCat." }
                        }
                    }
                    if let picture {
                        Image(uiImage: picture).resizable().scaledToFit().frame(maxHeight: 260)
                        Button("Что на фото?") { run(scanning: true) { await describe(picture) } }
                        Button("Прочитать текст") {
                            run(scanning: true) { status = await PhotoTool.shared.recognizeTextAsync(from: picture) }
                        }
                        Button("Улучшить") {
                            run { self.picture = await Task.detached { PhotoTool.shared.autoEnhance(image: picture) }.value }
                        }
                        Button("Убрать фон") {
                            run { self.picture = await Task.detached { PhotoTool.shared.removeBackground(from: picture) }.value }
                        }
                        Button("Изменить по описанию") {
                            run {
                                guard !text.isEmpty, let url = ModelManager.shared.diffusionURL,
                                      let source = PhotoTool.shared.normalized(picture, size: CGSize(width: 512, height: 512)).cgImage else {
                                    status = "Введи описание и установи Stable Diffusion с VAEEncoder.mlmodelc."
                                    return
                                }
                                do { self.picture = try await LocalInference.shared.image(url: url, prompt: text, startingImage: source,
                                                                                        textModel: ModelManager.shared.activeModelURL) }
                                catch { status = error.localizedDescription }
                            }
                        }
                        Button("Подготовить PNG") {
                            do {
                                let url = FileManager.default.temporaryDirectory.appendingPathComponent("AiCat-\(UUID()).png")
                                guard let data = picture.pngData() else { return }
                                try data.write(to: url)
                                output = url
                            } catch { status = error.localizedDescription }
                        }
                    }
                }
                Section("Создание") {
                    TextEditor(text: $text).frame(minHeight: 90)
                    Button("Нарисовать по описанию") {
                        run {
                            let result = await ImageGenerationTool.shared.generateImageAsync(prompt: text)
                            if let image = result.image { picture = image }
                            status = result.status
                        }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Сохранить озвучку текста") {
                        run {
                            do { output = try await audio.exportSpeech(text) }
                            catch { status = error.localizedDescription }
                        }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Создать и включить Lo-Fi бит") {
                        run {
                            status = await music.generateBeat(style: "lo-fi")
                            output = music.lastExportURL
                        }
                    }
                    if let output, output == music.lastExportURL {
                        Button(music.isPlaying ? "Остановить бит" : "Послушать ещё раз") {
                            if music.isPlaying { music.stopPlayback() }
                            else {
                                do { try music.replay() } catch { status = error.localizedDescription }
                            }
                        }
                    }
                }
                Section("Обрезка аудио") {
                    Button(audioInput?.lastPathComponent ?? "Выбрать аудиофайл") { importer = true }
                    TextField("Начало, секунды", text: $start).keyboardType(.decimalPad)
                    TextField("Конец, секунды", text: $end).keyboardType(.decimalPad)
                    Button("Сохранить фрагмент") {
                        run {
                            guard let audioInput,
                                  let from = Double(start.replacingOccurrences(of: ",", with: ".")),
                                  let to = Double(end.replacingOccurrences(of: ",", with: ".")) else {
                                status = "Выбери аудиофайл и введи время в секундах."
                                return
                            }
                            do { output = try await audio.trim(url: audioInput, start: from, end: to) }
                            catch { status = error.localizedDescription }
                        }
                    }
                }
                if scanning { Cat3DSceneView(motion: .scan).frame(height: 190).accessibilityLabel("AiCat сканирует изображение") }
                if busy { ProgressView("Кот работает…") }
                if !status.isEmpty { Text(status).textSelection(.enabled) }
                if let output { ShareLink("Сохранить или отправить файл", item: output) }
            }
            .disabled(busy)
            .navigationTitle("Мастерская кота")
            .toolbar { Button("Готово") { dismiss() }.disabled(busy) }
            .interactiveDismissDisabled(busy)
            .sheet(isPresented: $camera) { CameraCapture(picture: $picture) }
            .onChange(of: photoItem) { _, item in
                run {
                    do {
                        if let data = try await item?.loadTransferable(type: Data.self) { picture = UIImage(data: data) }
                    } catch { status = error.localizedDescription }
                }
            }
            .fileImporter(isPresented: $importer, allowedContentTypes: [.audio]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID())-\(url.lastPathComponent)")
                    try FileManager.default.copyItem(at: url, to: copy)
                    audioInput = copy
                } catch { status = error.localizedDescription }
            }
        }
    }

    private func run(scanning: Bool = false, _ operation: @escaping @MainActor () async -> Void) {
        guard !busy else { return }
        busy = true
        self.scanning = scanning
        status = ""
        output = nil
        Task {
            defer {
                busy = false
                self.scanning = false
            }
            await operation()
        }
    }

    private func describe(_ image: UIImage) async {
        let labels = await Task.detached {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return "" }
            let request = VNClassifyImageRequest()
            do {
                try VNImageRequestHandler(data: data).perform([request])
                return request.results?.prefix(5).map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }.joined(separator: ", ") ?? ""
            } catch { return "" }
        }.value
        guard !labels.isEmpty else { status = "Не удалось распознать содержимое кадра."; return }
        guard ModelManager.shared.activeModelURL != nil else {
            status = "Категории изображения: " + labels
            return
        }
        status = await ModelManager.shared.infer(prompt: labels,
            system: "Ты AiCat. По-русски объясни категории классификатора изображения. Укажи неопределённость. Не придумывай объекты, действия или детали, которых нет в списке. Обращайся к хозяину: кожаный.")
        CatSpeechSynthesizer.shared.speak(text: status)
    }
}

private struct CameraCapture: UIViewControllerRepresentable {
    @Binding var picture: UIImage?
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.picture = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
