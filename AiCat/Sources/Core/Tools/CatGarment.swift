import Foundation

enum CatGarment: String, CaseIterable, Identifiable {
    case cap = "Кожаная кепка"
    case beret = "Ягодный берет"
    case glasses = "Черные кибер-очки"
    case readers = "Янтарные очки"
    case pendant = "Золотой кулон-лапка"
    case bow = "Бархатная бабочка"
    case hoodie = "Неоновый худи"
    case vest = "Горчичная жилетка"

    case crown = "Звёздная корона"
    case pearl = "Жемчужное ожерелье"
    case trousers = "Джинсовые штаны"

    enum Slot: String, CaseIterable { case head = "На голову", eyes = "Очки", neck = "На шею", body = "Одежда", legs = "Штаны" }
    var id: Self { self }
    var slot: Slot {
        switch self {
        case .cap, .beret, .crown: return .head
        case .glasses, .readers: return .eyes
        case .pendant, .bow, .pearl: return .neck
        case .hoodie, .vest: return .body
        case .trousers: return .legs
        }
    }

    // Saved builds and chat tools both use Russian display names, including mixed outfits.
    static func matching(_ description: String?) -> [Self] {
        let words = (description ?? "").lowercased().replacingOccurrences(of: "ё", with: "е")
        let hasGlasses = words.split(whereSeparator: { !$0.isLetter }).contains { $0.hasPrefix("очк") }
        return allCases.filter { item in
            switch item {
            case .crown: return words.contains("корон")
            case .pearl: return words.contains("жемчуж") || words.contains("ожерел")
            case .cap: return words.contains("кепк")
            case .beret: return words.contains("берет")
            case .glasses: return hasGlasses && !words.contains("янтар")
            case .readers: return hasGlasses && words.contains("янтар")
            case .pendant: return words.contains("кулон")
            case .bow: return words.contains("бабочк")
            case .hoodie: return words.contains("худи")
            case .vest: return words.contains("жилет")
            case .trousers: return words.contains("штан") || words.contains("джинс")
            }
        }
    }

    static func equipping(_ items: [Self], over worn: [Self]) -> [Self] {
        Slot.allCases.compactMap { slot in
            items.last(where: { $0.slot == slot }) ?? worn.first(where: { $0.slot == slot })
        }
    }
}
