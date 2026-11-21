import SwiftUI

public struct WardrobeItem: Identifiable {
    public let id = UUID()
    public let name: String
    public let icon: String
    public let description: String
    public let isEquipped: Bool
}

public struct WardrobeSheet: View {
    @ObservedObject var catHandler = CatActionHandler.shared
    @Environment(\.presentationMode) var presentationMode
    
    let items = [
        ("🕶️", "Черные кибер-очки", "Фирменный стиль AiCat. Защита от ярких экранов."),
        ("🧥", "Неоновый худи", "Теплый киберпанк худи для ночных хакатонов."),
        ("🧢", "Кожаная кепка", "Дерзкий уличный стиль."),
        ("🥇", "Золотой кулон-лапка", "Украшение для солидного кота."),
        ("🐈", "Естественная шубка", "Классический пушистый британский стиль.")
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.11, blue: 0.14).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Гардероб AiCat")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.top)
                        
                        Text("Выбери прикид для своего кота. Он мгновенно примерит его в 3D и на Dynamic Island!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        ForEach(items, id: \.1) { emoji, title, desc in
                            HStack(spacing: 14) {
                                Text(emoji)
                                    .font(.system(size: 36))
                                    .frame(width: 50, height: 50)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if title == "Естественная шубка" {
                                        _ = catHandler.execute(action: "take_off")
                                    } else {
                                        _ = catHandler.execute(action: "dress_up", item: title)
                                    }
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }) {
                                    Text(catHandler.state.currentOutfit == title ? "Надет" : "Надеть")
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(catHandler.state.currentOutfit == title ? Color.green.opacity(0.3) : Color.cyan.opacity(0.2))
                                        .foregroundColor(catHandler.state.currentOutfit == title ? .green : .cyan)
                                        .cornerRadius(12)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.cyan))
        }
    }
}
