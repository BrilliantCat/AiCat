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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("АКТИВНЫЙ МОЗГ:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "cpu.fill")
                                    .font(.title2)
                                    .foregroundColor(modelManager.isModelLoaded ? .green : .cyan)
                                VStack(alignment: .leading) {
                                    Text(modelManager.activeModelName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(modelManager.modelPathInfo)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
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
                                    
                                    if item.id == "llm_qwen3b" && modelManager.isModelLoaded {
                                        Label("Активна", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(12)
                                    } else {
                                        Link(destination: URL(string: item.downloadURLString)!) {
                                            Label("Ссылка", systemImage: "arrow.down.circle.fill")
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
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.cyan))
        }
    }
}
