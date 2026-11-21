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
                            Text("АКТИВНЫЙ МОЗГ (A17 PRO):")
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
                                    Text("Версия GGUF: v\(meta.version)")
                                    Text("Тензоров: \(meta.tensorCount)")
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
                                .padding(.horizontal, 12)
                                .background(Color.cyan.opacity(0.15))
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Каталог офлайн-нейросетей для iPhone 15 Pro
                        Text("Нейросети для iPhone 15 Pro (Офлайн)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(modelManager.catalog) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(.white)
                                        Text("\(item.typeText) • \(item.sizeText)")
                                            .font(.caption2)
                                            .foregroundColor(.cyan)
                                    }
                                    Spacer()
                                    
                                    let isLoaded = (item.id == "llm_qwen3b" && modelManager.isModelLoaded) ||
                                                   (item.id == "diffusion_sd15" && modelManager.isDiffusionLoaded)
                                    
                                    if isLoaded {
                                        Label("Активна", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(12)
                                    } else {
                                        Link(destination: URL(string: item.downloadURLString)!) {
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
                                
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text("Путь для файла: \(item.destinationFolder)")
                                    .font(.caption2)
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Нейросети AiCat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}
