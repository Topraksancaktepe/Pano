import CoreGraphics

public enum ImageGeometry {
    public static func fit(image: CGSize, in bounds: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / image.width, bounds.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    public static func imagePoint(_ point: CGPoint, in frame: CGRect, image: CGSize) -> CGPoint? {
        guard frame.width > 0, frame.height > 0, frame.contains(point) else { return nil }
        return CGPoint(x: (point.x - frame.minX) / frame.width * image.width,
                       y: (point.y - frame.minY) / frame.height * image.height)
    }

    public static func previewFrame(size: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, max(1, visibleFrame.width - 44))
        let height = min(size.height, max(1, visibleFrame.height - 44))
        return CGRect(x: visibleFrame.maxX - width - 22, y: visibleFrame.minY + 22,
                      width: width, height: height)
    }
}
