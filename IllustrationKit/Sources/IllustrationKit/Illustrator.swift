import CoreImage
import CoreImage.CIFilterBuiltins

/// 写真をイラスト風に変換する。入出力は CIImage に統一する（無音カメラの撮影フレームをそのまま渡せるように）。
/// 流れ：縮小 → 平滑化（桑原フィルター）→ 色数を減らす → 線画を重ねる
public struct Illustrator: @unchecked Sendable {
    private let context: CIContext

    public init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    /// - Parameters:
    ///   - maxLongSide: 処理する長辺の画素数。小さいほど細部が消えてイラストらしくなり、速い
    ///   - lineWidth: 線の太さ（長辺1024pxのときの画素数）。0なら線を引かない
    ///   - strength: 元の写真との混ぜ具合（1 = イラストだけ）
    public func render(_ image: CIImage, style: IllustrationStyle, maxLongSide: CGFloat = 1024,
                       lineWidth: Double? = nil, strength: Double? = nil) -> CIImage {
        let scaled = downscale(image, maxLongSide: maxLongSide)
        let source = RGBAImage(scaled, context: context)
        let w = source.width, h = source.height
        // 半径や線の太さは長辺1024pxを基準に決めてあるので、解像度に合わせて伸び縮みさせる
        let unit = Double(max(w, h)) / 1024

        // 面に分ける（デフォルメ）。面の分け方は小さく縮めた画像で決める。
        // 縮めると細部が消えて面が大きくまとまり、拡大して戻したときに形も単純になる
        let segSource = RGBAImage(downscale(scaled, maxLongSide: CGFloat(style.segmentationLongSide)), context: context)
        let sw = segSource.width, sh = segSource.height
        var smooth = segSource
        for _ in 0..<style.smoothingPasses { smooth = Kuwahara.apply(smooth, radius: style.smoothingRadius) }

        // 色数を減らして色の番号を振り、小さな粒と小さな面を隣にまとめる。
        // 色数を減らすのは「面の分け方」を決めるためで、塗る色は面ごとの平均色にする
        // （代表色で塗ると、背景の大きな面に色を取られて肌や髪の色がずれるため）
        let centers = ColorQuantizer.centroids(of: [smooth], count: style.colorCount)
        var small = ColorQuantizer.labels(of: smooth, centers: centers)
        small = ColorQuantizer.modeFilter(small, width: sw, height: sh, colors: centers.count, radius: 1)
        // 小さくても周りと色の差がはっきりした面（目・サングラスなど）は特徴として残す
        small = Regions.mergeSmall(labels: small, width: sw, height: sh,
                                   minArea: max(4, Int(Double(sw * sh) * style.minRegionFraction)),
                                   image: smooth, keepContrast: style.keepContrast)

        // 元の大きさに戻し、境目をならして丸みのある形にする
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

        // 面ごとの色（＋パレットへ寄せる・パステル調にする）
        var colors = regions.meanColors(of: source)
        if !style.palette.isEmpty, style.paletteBlend > 0 {
            colors = colors.map { c in
                let p = style.palette[ColorQuantizer.nearestIndex(c, style.palette)]
                return c + (p - c) * style.paletteBlend
            }
        }
        if style.pastel > 0 { colors = colors.map { Pastel.apply($0, amount: style.pastel) } }

        // 線画：面の境目のうち、色の差がはっきりしているところだけに線を引く
        let width = (lineWidth ?? style.defaultLineWidth) * unit
        let lines = width > 0
            ? LineArt.edges(regions: regions.ids, colors: colors, width: w, height: h,
                            threshold: style.edgeThreshold, thickness: width)
            : [Bool](repeating: false, count: w * h)
        // 線のふちを1画素ぶんぼかして、ギザギザを目立たなくする（線の濃さ 0〜1）
        let lineAlpha = LineArt.soften(lines, width: w, height: h)

        let mix = Float(strength ?? style.defaultStrength)
        var out = source.pixels
        for i in 0..<(w * h) {
            let fill = colors[Int(regions.ids[i])]
            let flat = fill + (style.lineColor - fill) * lineAlpha[i]
            let c = source.rgb(at: i) + (flat - source.rgb(at: i)) * mix
            out[i * 4] = UInt8(min(255, max(0, c.x.rounded())))
            out[i * 4 + 1] = UInt8(min(255, max(0, c.y.rounded())))
            out[i * 4 + 2] = UInt8(min(255, max(0, c.z.rounded())))
            out[i * 4 + 3] = 255
        }
        return RGBAImage(width: w, height: h, pixels: out).ciImage
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
