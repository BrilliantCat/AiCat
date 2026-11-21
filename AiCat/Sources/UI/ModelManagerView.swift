import SwiftUI

public struct ModelManagerView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Карточка текущего состояния
                        VStack(alignment: .leading, spacing: 8) {
                            Text("АКТИВНЫЙ МОЗГ:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "cpu.fill")
                                    .font(.title2)
                                    .foregroundColor(.cyan)
                                VStack(alignment: .leading) {
                                    Text(modelManager.activeModelName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Работает на Metal A17 Pro (8 GB RAM)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Загрузка моделей
                        Text("Доступные офлайн-модели")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(modelManager.availableModels) { model in
                            let isInstalled = modelManager.installedModels.contains(model.fileName)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.name)
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(.white)
                                        Text("Размер: \(model.sizeText)")
                                            .font(.caption2)
                                            .foregroundColor(.cyan)
                                    }
                                    Spacer()
                                    
                                    if isInstalled {
                                        Label("Готова", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(12)
                                    } else {
                                        Button(action: {
                                            modelManager.downloadModel(model)
                                        }) {
                                            Label("Скачать", systemImage: "arrow.down.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.cyan)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.cyan.opacity(0.2))
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                                
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Подсказка про iTunes / Files
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.orange)
                                Text("Свои модели (.gguf)")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                            Text("Ты также можешь скинуть любые свои GGUF-модели напрямую через приложение «Файлы» на iPhone или через кабель с компьютера в папку AiCat/Models.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Модели ИИ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.cyan))
        }
    }
}
