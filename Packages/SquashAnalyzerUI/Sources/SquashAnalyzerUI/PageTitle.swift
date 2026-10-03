import SwiftUI

/// Page titles are 20 pt semibold in normal case on every screen
/// (docs/style/README.md). On iOS the inline navigation title is replaced by
/// one at that size; on Android MainActivity sets the same size for every top
/// bar, and the title sits inline next to the back arrow on both.
public enum PageTitleStyle {
    public static let size: CGFloat = 20.0

    public static var font: Font { .system(size: size, weight: .semibold) }
}

extension View {
    public func pageTitle(_ title: String) -> some View {
        #if os(iOS) && !SKIP
        return self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(PageTitleStyle.font)
                        .foregroundColor(SharedColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        #elseif SKIP
        // Compact bar next to the back arrow, as on iOS (no large title)
        return self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        #else
        return self.navigationTitle(title)
        #endif
    }
}
