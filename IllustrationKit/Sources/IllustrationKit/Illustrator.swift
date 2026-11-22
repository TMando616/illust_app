import CoreImage
import CoreImage.CIFilterBuiltins

/// 写真をイラスト風に変換する。入出力は CIImage に統一する（無音カメラの撮影フレームをそのまま渡せるように）。
/// 流れ：縮小 → 被写体を切り抜く → 平らな色の面にする（被写体は細かく、背景は大胆に）→ パステル調
///       → 被写体の中に線（明るさの変化から）と、被写体の輪郭線を重ねる
public struct Illustrator: @unchecked Sendable {
    private let context: CIContext

    public init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    /// - Parameters:
    ///   - maxLongSide: 処理する長辺の画素数
    ///   - lineWidth: 線の太さ（長辺1024pxのときの画素数）。0なら線を引かない
    ///   - strength: 元の写真との混ぜ具合（1 = イラストだけ）
    public func render(_ image: CIImage, style: IllustrationStyle, maxLongSide: CGFloat = 1024,
                       lineWidth: Double? = nil, strength: Double? = nil) -> CIImage {
        let scaled = downscale(image, maxLongSide: maxLongSide)
        let source = RGBAImage(scaled, context: context)
        let w = source.width, h = source.height, n = w * h
        // 長さの値は長辺1024pxを基準に決めてあるので、解像度に合わせて伸び縮みさせる
        let unit = Double(max(w, h)) / 1024

        // 被写体のマスク。見つからなければ全体を被写体として扱う
        let mask = SubjectMask.make(for: source) ?? [Float](repeating: 1, count: n)

        // 平らな色の面：被写体用（細かめ）と背景用（大胆）を作り、マスクで使い分ける
        let subject = flatten(source, longSide: style.subjectDetail, style: style, unit: unit)
        let background: Flat? = if case .illustrated = style.background {
            flatten(source, longSide: style.backgroundDetail, style: style, unit: unit)
        } else { nil }

        // 線：被写体の中は明るさの変化から拾い、被写体の外形には輪郭線を引く
        let width = (lineWidth ?? style.defaultLineWidth) * unit
        var lineAlpha = [Float](repeating: 0, count: n)
        if width > 0 {
            let smooth = smoothed(source, radius: max(1, Int((3 * unit).rounded())), passes: 3)
            let inner = LineArt.xdog(smooth, sigma: style.lineSigma * Float(unit),
                                     threshold: style.lineThreshold, softness: style.lineSoftness, mask: mask)
            let inside = mask.map { $0 > 0.5 ? Int32(1) : Int32(0) }
            let outline = LineArt.soften(
                LineArt.edges(regions: inside, colors: [.zero, SIMD3(repeating: 255)], width: w, height: h,
                              threshold: 0, thickness: width * style.outlineScale),
                width: w, height: h)
            for i in 0..<n { lineAlpha[i] = max(inner[i] * mask[i], outline[i]) }
        }

        let mix = Float(strength ?? style.defaultStrength)
        var out = source.pixels
        for i in 0..<n {
            let fill: SIMD3<Float>
            switch style.background {
            case .illustrated:
                fill = mask[i] > 0.5 ? subject.color(at: i) : background!.color(at: i)
            case .plain(let color):
                // 被写体のふちはマスクの値でなめらかに背景色へつなぐ
                fill = color + (subject.color(at: i) - color) * mask[i]
            }
            let flat = fill + (style.lineColor - fill) * lineAlpha[i]
            let c = source.rgb(at: i) + (flat - source.rgb(at: i)) * mix
            out[i * 4] = UInt8(min(255, max(0, c.x.rounded())))
            out[i * 4 + 1] = UInt8(min(255, max(0, c.y.rounded())))
            out[i * 4 + 2] = UInt8(min(255, max(0, c.z.rounded())))
            out[i * 4 + 3] = 255
        }
        return RGBAImage(width: w, height: h, pixels: out).ciImage
    }

    /// 平らな色の面（各画素がどの面か＋面ごとの色）
    struct Flat {
        let ids: [Int32]
        let colors: [SIMD3<Float>]
        func color(at i: Int) -> SIMD3<Float> { colors[Int(ids[i])] }
    }

    /// 写真を平らな色の面にする。面の分け方は長辺 `longSide` に縮めた画像で決め（小さいほど面が大きくまとまる）、
    /// 元の大きさに戻してから境目を丸める。塗る色は面ごとの平均色（代表色で塗ると肌などの色がずれるため）
    func flatten(_ source: RGBAImage, longSide: Int, style: IllustrationStyle, unit: Double) -> Flat {
        let w = source.width, h = source.height
        let seg = RGBAImage(downscale(source.ciImage, maxLongSide: CGFloat(longSide)), context: context)
        let sw = seg.width, sh = seg.height
        let smooth = smoothed(seg, radius: style.smoothingRadius, passes: style.smoothingPasses)

        let centers = ColorQuantizer.centroids(of: [smooth], count: style.colorCount)
        var small = ColorQuantizer.labels(of: smooth, centers: centers)
        small = ColorQuantizer.modeFilter(small, width: sw, height: sh, colors: centers.count, radius: 1)
        // 小さくても周りと色の差がはっきりした面（目・サングラスなど）は残す
        small = Regions.mergeSmall(labels: small, width: sw, height: sh,
                                   minArea: max(4, Int(Double(sw * sh) * style.minRegionFraction)),
                                   image: smooth, keepContrast: style.keepContrast)

        var labels = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            let sy = min(sh - 1, y * sh / h)
            for x in 0..<w { labels[y * w + x] = small[sy * sw + min(sw - 1, x * sw / w)] }
        }
        let roundRadius = max(1, Int((Double(style.shapeRounding) * unit).rounded()))
        for _ in 0..<2 {
            labels = ColorQuantizer.modeFilter(labels, width: w, height: h, colors: centers.count, radius: roundRadius)
        }
        let regions = Regions(labels: labels, width: w, height: h)

        var colors = regions.meanColors(of: source)
        if !style.palette.isEmpty, style.paletteBlend > 0 {
            colors = colors.map { c in
                let p = style.palette[ColorQuantizer.nearestIndex(c, style.palette)]
                return c + (p - c) * style.paletteBlend
            }
        }
        if style.pastel > 0 { colors = colors.map { Pastel.apply($0, amount: style.pastel) } }
        return Flat(ids: regions.ids, colors: colors)
    }

    func smoothed(_ image: RGBAImage, radius: Int, passes: Int) -> RGBAImage {
        var result = image
        for _ in 0..<passes { result = Kuwahara.apply(result, radius: radius) }
        return result
    }

    func downscale(_ image: CIImage, maxLongSide: CGFloat) -> CIImage {
        let longSide = max(image.extent.width, image.extent.height)
        guard longSide > maxLongSide else { return image }
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(maxLongSide / longSide)
        filter.aspectRatio = 1
        return filter.outputImage!
    }
}
