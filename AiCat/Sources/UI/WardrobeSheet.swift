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
    
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Cat3DSceneView(motion: .idle)
                    .frame(maxWidth: .infinity).frame(height: 235)
                    .accessibilityLabel("Котёнок в выбранных вещах")
                List {
                    ForEach(CatGarment.Slot.allCases, id: \.self) { slot in
                        Section(slot.rawValue) {
                            ForEach(CatGarment.allCases.filter { $0.slot == slot }) { garment in
                                let equipped = catHandler.wornGarments.contains(garment)
                                Button {
                                    _ = catHandler.execute(action: equipped ? "take_off" : "dress_up", item: garment.rawValue)
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    HStack {
                                        Text(garment.rawValue)
                                        Spacer()
                                        Image(systemName: equipped ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(equipped ? Color.mint : Color.secondary)
                                    }
                                }
                                .foregroundStyle(.primary)
                                .accessibilityValue(equipped ? "Надето" : "Можно надеть")
                            }
                        }
                    }
                    Button("Снять всё") { _ = catHandler.execute(action: "take_off") }
                        .disabled(catHandler.wornGarments.isEmpty)
                }
            }
            .navigationTitle("Гардероб").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
