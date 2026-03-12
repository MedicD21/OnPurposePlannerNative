import Foundation

struct PageAttachment: Identifiable, Codable {
    var id: UUID
    var pageId: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    enum Kind: Codable {
        case photo(Data)
        case file(Data, String)  // data + filename
    }

    var kind: Kind

    init(id: UUID = UUID(), pageId: String,
         x: CGFloat = 740, y: CGFloat = 540,
         width: CGFloat = 300, height: CGFloat = 300,
         kind: Kind) {
        self.id = id
        self.pageId = pageId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.kind = kind
    }
}
