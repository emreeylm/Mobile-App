import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

struct DecisionBadge: View {
    let text: String
    let opacity: Double

    var body: some View {
        Text(text)
            .font(.headline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(opacity)
    }
}

struct FlowChips: View {
    let items: [String]

    var body: some View {
        if items.isEmpty { EmptyView() }
        else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let text: String
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer() }
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isMine ? AnyShapeStyle(.tint) : AnyShapeStyle(.thinMaterial))
                .foregroundStyle(isMine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)
            if !isMine { Spacer() }
        }
    }
}

// ✅ Profile tekrar mevcut olduğu için bunu da sorunsuz bırakıyoruz
struct MatchToast: View {
    let profile: Profile
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Eşleşme!")
                    .font(.headline.bold())
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Image(systemName: profile.avatarSymbol)
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).font(.headline)
                    Text("Mesajlar'a gidip sohbet edebilirsin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(14)
        .frame(maxWidth: 560)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - FlowLayout Component
struct FlowLayout: View {
    let items: [String]
    let viewForItem: (String) -> AnyView
    @State private var totalHeight = CGFloat.zero

    init<V: View>(items: [String], @ViewBuilder viewForItem: @escaping (String) -> V) {
        self.items = items
        self.viewForItem = { AnyView(viewForItem($0)) }
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(self.items, id: \.self) { item in
                self.viewForItem(item)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == self.items.last {
                            width = 0 
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if item == self.items.last {
                            height = 0 
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}
