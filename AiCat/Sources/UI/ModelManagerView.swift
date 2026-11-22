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
                        // Карточка текущего состояния мозга
                        VStack(alignment: .leading, spacing: 10) {
                            Text("АКТИВНЫЙ МОЗГ (APPLE A17 PRO):")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "cpu.fill")
                                    .font(.title2)
                                    .foregroundColor(modelManager.isModelLoaded ? .green : .cyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(modelManager.activeModelName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(modelManager.modelPathInfo)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            if let meta = modelManager.ggufMetadata {
                                HStack(spacing: 12) {
                                    Text("Формат: GGUF v\(meta.version)")
                                    Text("Тензоры: \(meta.tensorCount)")
                                    Text("Квантование: \(meta.quantization)")
                                }
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                modelManager.findAndLoadModel()
                                modelManager.findAndLoadDiffusionModel()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Пересканировать папки Models")
                                }
                                .font(.caption)
                                .bold()
                                .foregroundColor(.cyan)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // БЕНЧМАРК И ЗАМЕР СКОРОСТИ
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ДИАГНОСТИКА И СКОРОСТЬ:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            if let b = modelManager.lastBenchmark {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading) {
                                        Text("TTFT (1-й токен):")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text("\(String(format: "%.1f", b.timeToFirstTokenMs)) мс")
                                            .font(.headline)
                                            .foregroundColor(.cyan)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("Скорость генерации:")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text("\(String(format: "%.1f", b.tokensPerSecond)) ток/с")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("Память Metal:")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text("\(String(format: "%.0f", b.memoryUsageMB)) МБ")
                                            .font(.headline)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                modelManager.runBenchmark { _ in }
                            }) {
                                HStack {
                                    if modelManager.isBenchmarking {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    } else {
                                        Image(systemName: "speedometer")
                                    }
                                    Text(modelManager.isBenchmarking ? "Тестирую чип A17 Pro..." : "Запустить тест скорости (Бенчмарк)")
                                }
                                .font(.subheadline)
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cyan)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .disabled(modelManager.isBenchmarking)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Инструкция по установке файлов
                        VStack(alignment: .leading, spacing: 12) {
                            Text("КАК ДОБАВИТЬ НЕЙРОСЕТИ БЕЗ ПК:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                InstructionStep(number: "1", text: "Открой стандартное приложение «Файлы» на iPhone.")
                                InstructionStep(number: "2", text: "Перейди в «На моем iPhone» -> «AiCat» -> папка «Models».")
                                InstructionStep(number: "3", text: "Положи туда файл qwen2.5-3b-instruct-q4_k_m.gguf и папку coreml-stable-diffusion.")
                                InstructionStep(number: "4", text: "Вернись сюда и нажми 'Пересканировать папки Models'.")
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding()
                }
            }
            .navigationTitle("Процессор & Модели")
            .navigationBarItems(trailing: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.cyan))
        }
    }
}

struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption2)
                .bold()
                .frame(width: 20, height: 20)
                .background(Color.cyan.opacity(0.2))
                .foregroundColor(.cyan)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}
