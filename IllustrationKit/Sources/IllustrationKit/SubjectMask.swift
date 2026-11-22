import CoreImage
import CoreVideo
import Vision

/// 被写体の切り抜き。iOS 17 / macOS 14 の「被写体を持ち上げる」機能と同じ仕組み（Vision）で、
/// 人・動物・物の形をマスクとして取る。端末内で処理され、サーバーには送らない
enum SubjectMask {
    /// 各画素の「被写体らしさ」（0〜1）。被写体が見つからなければ nil
    static func make(for image: RGBAImage) -> [Float]? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image.cgImage)
        do { try handler.perform([request]) } catch { return nil }
        guard let observation = request.results?.first, !observation.allInstances.isEmpty,
              let buffer = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        else { return nil }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bw = CVPixelBufferGetWidth(buffer), bh = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        // マスクは元の画像と同じ大きさで返るが、念のため大きさが違っても読めるようにしておく
        var mask = [Float](repeating: 0, count: image.width * image.height)
        for y in 0..<image.height {
            let row = base.advanced(by: min(bh - 1, y * bh / image.height) * rowBytes).assumingMemoryBound(to: Float32.self)
            for x in 0..<image.width { mask[y * image.width + x] = row[min(bw - 1, x * bw / image.width)] }
        }
        return mask
    }
}
