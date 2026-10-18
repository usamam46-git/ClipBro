import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.labelColor.setStroke()
            let board = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 1.5, width: 11, height: 14), xRadius: 2, yRadius: 2)
            board.lineWidth = 1.4; board.stroke()
            NSColor.labelColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: 6, y: 13.5, width: 6, height: 3.5), xRadius: 1.2, yRadius: 1.2).fill()
            NSBezierPath(ovalIn: NSRect(x: 6, y: 8, width: 1.5, height: 1.5)).fill()
            NSBezierPath(ovalIn: NSRect(x: 10.5, y: 8, width: 1.5, height: 1.5)).fill()
            let smile = NSBezierPath()
            smile.move(to: NSPoint(x: 6.5, y: 6))
            smile.curve(to: NSPoint(x: 11.5, y: 6), controlPoint1: NSPoint(x: 8, y: 4), controlPoint2: NSPoint(x: 10, y: 4))
            smile.lineWidth = 1; smile.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ClipBro"
        return image
    }
}
