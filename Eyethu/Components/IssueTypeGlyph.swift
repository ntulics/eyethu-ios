import SwiftUI

struct IssueTypeGlyph: View {
    let type: IssueType
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    init(type: IssueType, size: CGFloat, weight: Font.Weight = .medium, color: Color) {
        self.type = type
        self.size = size
        self.weight = weight
        self.color = color
    }

    var body: some View {
        if let emoji = type.emojiIcon {
            Text(emoji)
                .font(.system(size: size))
        } else {
            Image(systemName: type.symbolIcon)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(color)
        }
    }
}

