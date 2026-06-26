import AppKit

/// A small monochrome "notch with a waveform" glyph for the menu bar, drawn as a
/// template image so macOS tints it correctly in light and dark menu bars.
/// Echoes the app mark (a rounded notch pill + a voice waveform).
public enum JarvisMenuBarIcon {
    public static let image: NSImage = {
        let size = NSSize(width: 20, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let ink = NSColor.black

            // Rounded "notch" pill outline.
            let pill = NSRect(x: 1.5, y: 3.5, width: rect.width - 3, height: rect.height - 7)
            let outline = NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2)
            outline.lineWidth = 1.4
            ink.setStroke()
            outline.stroke()

            // Central voice waveform: five bars of varying height.
            let heights: [CGFloat] = [3, 5.5, 7.5, 5.5, 3]
            let barWidth: CGFloat = 1.5
            let gap: CGFloat = 1.7
            let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
            var x = rect.midX - totalWidth / 2
            ink.setFill()
            for height in heights {
                let bar = NSRect(x: x, y: rect.midY - height / 2, width: barWidth, height: height)
                NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
                x += barWidth + gap
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
