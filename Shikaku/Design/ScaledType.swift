//
//  ScaledType.swift
//  Shikaku
//
//  Accessibility layout helpers (2026-10-03 audit, docs/ACCESSIBILITY.md):
//  number text that follows Dynamic Type, and card rows that stack once the
//  text is too big to sit beside a glyph.
//

import SwiftUI

/// Theme.numberFont at a size that scales with the reader's text size,
/// relative to `.body`, like every other text style in the app.
private struct ScaledNumberFont: ViewModifier {
    @ScaledMetric private var size: CGFloat

    init(size: CGFloat, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
    }

    func body(content: Content) -> some View {
        content.font(Theme.numberFont(size: size))
    }
}

extension View {
    /// Monospaced numbers that grow with Dynamic Type. Use instead of
    /// `.font(Theme.numberFont(size:))` wherever the text is not boxed into a
    /// fixed-size shape.
    func numberFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(ScaledNumberFont(size: size, relativeTo: style))
    }
}

/// A Home card's row: glyph, text and arrow side by side, stacked once the
/// reader's text size is an accessibility size (side by side, the text was
/// squeezed to a word per line at AX5).
struct CardRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Layout.s3))
            : AnyLayout(HStackLayout(spacing: Layout.s4))
        layout { content }
    }
}
