import Foundation

struct MailFolder: Identifiable, Equatable {
    let id: UUID
    let accountID: UUID
    var name: String
    var fullPath: String
    var parentID: UUID?
    var uidValidity: Int?
    var uidNext: Int?

    init(id: UUID = UUID(),
         accountID: UUID,
         name: String,
         fullPath: String,
         parentID: UUID?,
         uidValidity: Int?,
         uidNext: Int?) {
        self.id = id
        self.accountID = accountID
        self.name = name
        self.fullPath = fullPath
        self.parentID = parentID
        self.uidValidity = uidValidity
        self.uidNext = uidNext
    }
}
