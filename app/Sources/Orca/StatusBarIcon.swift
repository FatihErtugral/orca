import AppKit

/// Renders the menu bar label as a single template image: a simple leaping
/// dolphin followed by a rounded "running/open" badge (e.g. "2/4"). Drawing it
/// ourselves — instead of relying on MenuBarExtra's label — is the only reliable
/// way to frame the numbers and keep them from looking detached.
enum StatusBarIcon {
    static func make(running: Int, open: Int, attention: Bool) -> NSImage {
        let text = "\(running)/\(open)" as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textSize = text.size(withAttributes: textAttrs)

        let iconW: CGFloat = 18
        let iconH: CGFloat = 16

        let gap: CGFloat = 3
        let framePadX: CGFloat = 5
        let framePadY: CGFloat = 2
        let frameW = ceil(textSize.width) + framePadX * 2
        let frameH = ceil(textSize.height) + framePadY * 2
        let height = max(iconH, frameH)
        let width = iconW + gap + frameW

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            NSColor.black.set()

            drawDolphin(in: NSRect(x: 0, y: (height - iconH) / 2, width: iconW, height: iconH))

            let frameRect = NSRect(
                x: iconW + gap + 0.75,
                y: (height - frameH) / 2 + 0.75,
                width: frameW - 1.5,
                height: frameH - 1.5
            )
            let frame = NSBezierPath(roundedRect: frameRect, xRadius: 4, yRadius: 4)
            frame.lineWidth = 1.3
            frame.stroke()

            let tx = frameRect.minX + (frameRect.width - textSize.width) / 2
            let ty = frameRect.minY + (frameRect.height - textSize.height) / 2
            text.draw(at: NSPoint(x: tx, y: ty), withAttributes: textAttrs)

            return true
        }
        image.isTemplate = true
        return image
    }

    /// Draws the embedded dolphin artwork, fitted (aspect-preserved) into `rect`.
    private static func drawDolphin(in rect: NSRect) {
        let side = min(rect.width, rect.height)
        let fitted = NSRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        DolphinAsset.image.draw(in: fitted, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
}
