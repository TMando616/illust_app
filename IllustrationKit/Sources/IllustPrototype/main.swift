import CoreImage
import CoreText
import Foundation
import ImageIO
import IllustrationKit
import UniformTypeIdentifiers

// ステップ1の試作。入力フォルダの写真を画風ごとに変換し、変換前後を並べた一覧画像を出力フォルダに書き出す。
// 使い方: swift run -c release IllustPrototype <入力フォルダ> <出力フォルダ> [--palette-from <お手本のフォルダ>]
//   --palette-from を付けると、お手本の絵から色を拾い、その色に寄せた画風も作る

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("使い方: swift run -c release IllustPrototype <入力フォルダ> <出力フォルダ> [--palette-from <お手本のフォルダ>]")
    exit(1)
}
let inputDir = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2])
let paletteDir = args.firstIndex(of: "--palette-from").map { URL(fileURLWithPath: args[$0 + 1]) }
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let context = CIContext(options: [.cacheIntermediates: false])
let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

func loadImages(in dir: URL) throws -> [(name: String, image: CIImage)] {
    try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .compactMap { url in
            // 写真の向きの情報（EXIF）を反映して読む
            CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
                .map { (url.deletingPathExtension().lastPathComponent, $0) }
        }
}

func writeJPEG(_ image: CGImage, to url: URL, quality: Double = 0.9) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

func hex(_ c: SIMD3<Float>) -> String {
    String(format: "#%02X%02X%02X", Int(c.x.rounded()), Int(c.y.rounded()), Int(c.z.rounded()))
}

// 画風の一覧
var styles: [IllustrationStyle] = [.wholeScene, .subjectOnly]
var palette: [SIMD3<Float>] = []
if let paletteDir {
    let samples = try loadImages(in: paletteDir).map { RGBAImage($0.image, context: context) }
    // 背景の白・透明な部分と、黒い線は除いて色を拾う
    palette = ColorQuantizer.centroids(of: samples, count: 8) { c, alpha in
        alpha > 200 && c.min() < 235 && (c * SIMD3(0.299, 0.587, 0.114)).sum() > 70
    }
    print("お手本から拾った色: \(palette.map(hex).joined(separator: " "))")
}

// 変換
let photos = try loadImages(in: inputDir)
let illustrator = Illustrator(context: context)
var rows: [[CGImage]] = []
for photo in photos {
    var row = [context.createCGImage(photo.image, from: photo.image.extent)!]
    for style in styles {
        let start = Date()
        let result = illustrator.render(photo.image, style: style)
        let cg = context.createCGImage(result, from: result.extent)!
        writeJPEG(cg, to: outputDir.appendingPathComponent("\(photo.name)_\(style.id).jpg"))
        row.append(cg)
        print(String(format: "%@ / %@: %.2f秒", photo.name, style.name, Date().timeIntervalSince(start)))
    }
    rows.append(row)
}

// 一覧画像：1行に「元の写真・画風1・画風2…」を並べる
let cellWidth = 600, gap = 12, header = 56
let columns = styles.count + 1
let rowHeights = rows.map { row in Int(Double(cellWidth) * Double(row[0].height) / Double(row[0].width)) }
let sheetWidth = columns * cellWidth + (columns + 1) * gap
let sheetHeight = header + rowHeights.reduce(0, +) + (rows.count + 1) * gap
let sheet = CGContext(data: nil, width: sheetWidth, height: sheetHeight, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))

func drawText(_ text: String, x: Int, y: Int, size: CGFloat = 26) {
    let font = CTFontCreateWithName("HiraginoSans-W6" as CFString, size, nil)
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.15, alpha: 1),
    ])
    sheet.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(CTLineCreateWithAttributedString(attributed), sheet)
}

// CGContext は左下が原点なので、上から順に並べるために y を下から計算する
for (c, title) in (["元の写真"] + styles.map(\.name)).enumerated() {
    drawText(title, x: gap + c * (cellWidth + gap) + 4, y: sheetHeight - header + 16)
}
var top = sheetHeight - header
for (r, row) in rows.enumerated() {
    top -= gap + rowHeights[r]
    for (c, image) in row.enumerated() {
        sheet.interpolationQuality = .high
        sheet.draw(image, in: CGRect(x: gap + c * (cellWidth + gap), y: top, width: cellWidth, height: rowHeights[r]))
    }
}
let sheetURL = outputDir.appendingPathComponent("_一覧.jpg")
writeJPEG(sheet.makeImage()!, to: sheetURL, quality: 0.85)
print("一覧画像: \(sheetURL.path)")
