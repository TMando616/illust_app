import Foundation
import IllustrationKit

// 使い方: swift run IllustPrototype <入力フォルダ> <出力フォルダ>
// ステップ1で、入力フォルダの写真を変換して出力フォルダに書き出す処理を組む
let args = CommandLine.arguments
guard args.count == 3 else {
    print("使い方: swift run IllustPrototype <入力フォルダ> <出力フォルダ>")
    exit(1)
}
print("入力: \(args[1]) / 出力: \(args[2])（変換処理はステップ1で実装）")
