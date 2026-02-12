import SwiftUI

struct AvatarCircle: View {
    let url: URL?
    let fallbackText: String

    var body: some View {
        ZStack {
            Circle().fill(Color.primary.opacity(0.06))
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Text(fallbackText)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.55))
                    }
                }
            } else {
                Text(fallbackText)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.55))
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
    }
}
