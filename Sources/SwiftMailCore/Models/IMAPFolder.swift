import Foundation

public struct IMAPFolder: Identifiable, Hashable, Sendable {
    public let id: String
    public var accountID: String
    public var name: String
    public var fullPath: String
    public var parentID: String?
    public var uidValidity: Int?
    public var uidNext: Int?

    public init(
        id: String = UUID().uuidString,
        accountID: String,
        name: String,
        fullPath: String,
        parentID: String? = nil,
        uidValidity: Int? = nil,
        uidNext: Int? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.name = name
        self.fullPath = fullPath
        self.parentID = parentID
        self.uidValidity = uidValidity
        self.uidNext = uidNext
    }
}
