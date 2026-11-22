import SwiftUI
import UniformTypeIdentifiers

public struct RAGManagerView: View {
    @ObservedObject var ragTool = RAGTool.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showDocumentPicker = false
    @State private var statusAlertMessage = ""
    @State private var showStatusAlert = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Шапка RAG
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ЛОКАЛЬНАЯ БАЗА ЗНАНИЙ (RAG BM25)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("Импортируй PDF-документы, инструкции, конспекты или заметки (.txt, .md). Кот будет мгновенно находить точные ответы со ссылкой на источник.")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Кнопка добавления документа
                    Button(action: { showDocumentPicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Импортировать документ (PDF, TXT, MD)")
                        }
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Список проиндексированных документов
                    List {
                        if ragTool.documentsMeta.isEmpty {
                            Text("Документов пока нет. Нажми кнопку выше, чтобы добавить первый файл.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(ragTool.documentsMeta) { doc in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(doc.name)
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(.white)
                                        Text("\(doc.chunkCount) чанков проиндексировано")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: {
                                        ragTool.removeDocument(name: doc.name)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.05))
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    
                    if !ragTool.documentsMeta.isEmpty {
                        Button("Очистить всю базу документов") {
                            ragTool.clearAll()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("База знаний (RAG)")
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.cyan))
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerRepresentable { url in
                    let result = ragTool.importDocument(url: url)
                    statusAlertMessage = result.message
                    showStatusAlert = true
                }
            }
            .alert(isPresented: $showStatusAlert) {
                Alert(title: Text("Импорт документа"), message: Text(statusAlertMessage), dismissButton: .default(Text("Отлично")))
            }
        }
    }
}

struct DocumentPickerRepresentable: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .plainText, .text]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
