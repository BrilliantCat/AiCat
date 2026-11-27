import Contacts
import MessageUI
import UIKit

@MainActor
final class PhoneCommunication: NSObject, MFMessageComposeViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    static let shared = PhoneCommunication()
    private var reply: CheckedContinuation<String, Never>?

    nonisolated static func phoneNumber(_ input: String) -> String? {
        let compact = input.filter { !" ()-\u{2011}\u{2013}\u{00a0}".contains($0) }
        let digits = compact.hasPrefix("+") ? String(compact.dropFirst()) : compact
        guard (2...15).contains(digits.count), digits.allSatisfy({ "0123456789".contains($0) }) else { return nil }
        return compact
    }

    private enum Recipient {
        case number(String)
        case unavailable(String)
    }

    private func resolve(_ input: String) async -> Recipient {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        guard !query.isEmpty else { return .unavailable("Укажи номер или имя из контактов.") }
        if let number = Self.phoneNumber(query) { return .number(number) }
        guard query.contains(where: { $0.isLetter }) else { return .unavailable("Проверь номер телефона.") }
        let store = CNContactStore()
        do {
            guard try await store.requestAccess(for: .contacts) else {
                return .unavailable("Для поиска по имени разреши AiCat доступ к контактам. Можно также указать номер.")
            }
            let matches = try await Task.detached(priority: .userInitiated) { () throws -> [String: String] in
                let keys: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]
                let names = [query] + (["маме":"мама", "папе":"папа"][query.lowercased()].map { [$0] } ?? [])
                for name in names {
                    let contacts = try store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: name), keysToFetch: keys)
                    var choices: [String: String] = [:]
                    for contact in contacts {
                        for entry in contact.phoneNumbers {
                            if let number = Self.phoneNumber(entry.value.stringValue) {
                                choices[number] = CNContactFormatter.string(from: contact, style: .fullName) ?? name
                            }
                        }
                    }
                    if !choices.isEmpty { return choices }
                }
                return [:]
            }.value
            if matches.count == 1, let number = matches.keys.first { return .number(number) }
            guard !matches.isEmpty else { return .unavailable("Не нашёл номер для «\(query)». Укажи имя как в Контактах или сам номер.") }
            let options = matches.keys.sorted().prefix(8).map { "\(matches[$0] ?? query) · \($0)" }
            return .unavailable("Нашёл несколько номеров. Укажи нужный номер в команде.\n" + options.joined(separator: "\n"))
        } catch { return .unavailable("Не удалось прочитать контакты. Можно указать номер напрямую.") }
    }

    static func emailDraft(to recipient: String, body: String) -> URL? {
        let address = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.range(of: #"^[\p{L}0-9._%+\-]+@[\p{L}0-9.\-]+\.[\p{L}]{2,}$"#, options: .regularExpression) != nil else { return nil }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = address
        if !body.isEmpty { parts.queryItems = [URLQueryItem(name: "body", value: body)] }
        return parts.url
    }

    func perform(_ command: String, recipient: String, text: String) async -> String {
        if command == "mail_draft" {
            guard let url = Self.emailDraft(to: recipient, body: text) else { return "Укажи почтовый адрес, например name@example.com." }
            let opened = await UIApplication.shared.open(url)
            return opened ? "Открыл черновик в почтовом приложении." : "Не удалось открыть почтовое приложение."
        }
        if command == "sms_draft" && !MFMessageComposeViewController.canSendText() { return "На этом устройстве недоступна отправка сообщений." }
        let number: String
        switch await resolve(recipient) {
        case .number(let value): number = value
        case .unavailable(let message): return message
        }
        if command == "sms_draft" { return await compose(to: number, body: text) }
        let scheme = command == "facetime" ? "facetime" : "tel"
        guard let url = URL(string: "\(scheme):\(number)") else { return "Проверь номер телефона." }
        let opened = await UIApplication.shared.open(url)
        return opened ? "Передал номер \(number) для звонка." : "iOS не смогла открыть звонок на \(number)."
    }

    private func compose(to number: String, body: String) async -> String {
        guard reply == nil else { return "Редактор сообщения уже открыт." }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard var presenter = scene?.keyWindow?.rootViewController else { return "Открой AiCat, чтобы подготовить сообщение." }
        while let next = presenter.presentedViewController { presenter = next }
        guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed else { return "Повтори после закрытия текущего окна." }
        let composer = MFMessageComposeViewController()
        composer.recipients = [number]
        composer.body = body
        composer.messageComposeDelegate = self
        return await withCheckedContinuation { continuation in
            reply = continuation
            presenter.present(composer, animated: true)
            composer.presentationController?.delegate = self
        }
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        let message: String
        switch result {
        case .sent: message = "Сообщение передано на отправку."
        case .cancelled: message = "Отправка отменена."
        default: message = "Не удалось отправить сообщение."
        }
        controller.dismiss(animated: true) { self.finish(message) }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish("Отправка отменена.")
    }

    private func finish(_ message: String) {
        let continuation = reply
        reply = nil
        continuation?.resume(returning: message)
    }
}
