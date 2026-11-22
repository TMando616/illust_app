import CoreGraphics
import CoreImage

/// 1画素4バイト（R・G・B・A）の画像。平滑化や色の集計のように「画素を1つずつ見る」処理はここで行う
public struct RGBAImage: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// CIImage を画素の配列に書き出す
    public init(_ image: CIImage, context: CIContext) {
        let extent = image.extent.integral
        let moved = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        let w = Int(extent.width), h = Int(extent.height)
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        context.render(moved, toBitmap: &buffer, rowBytes: w * 4,
                       bounds: CGRect(x: 0, y: 0, width: w, height: h),
                       format: .RGBA8, colorSpace: Self.colorSpace)
        self.init(width: w, height: h, pixels: buffer)
    }

    public var cgImage: CGImage {
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: Self.colorSpace,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }

    public var ciImage: CIImage { CIImage(cgImage: cgImage) }

    @inline(__always) func rgb(at i: Int) -> SIMD3<Float> {
        SIMD3(Float(pixels[i * 4]), Float(pixels[i * 4 + 1]), Float(pixels[i * 4 + 2]))
    }
}
