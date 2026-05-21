import Foundation

actor InstallIDStore {
    private let item = KeychainStore.Item(service: "pulse", account: "install_id")
    private var cached: UUID?

    func installID() -> UUID {
        if let cached { return cached }
        if let data = KeychainStore.read(item),
           let string = String(data: data, encoding: .utf8),
           let uuid = UUID(uuidString: string) {
            cached = uuid
            return uuid
        }
        let new = UUID()
        cached = new
        let data = new.uuidString.data(using: .utf8) ?? Data()
        try? KeychainStore.write(item, data: data)
        return new
    }
}
