# illust_app

アルバムの写真を、端末内でシンプルなイラスト風に変換するiOSアプリ。Swift / SwiftUI。アプリ名は未決（「イラスト変換」は仮称）。

仕様・決定事項・実装ステップは **docs/spec.md** にまとめてある。作業を始める前に必ず読むこと。進み具合と次のタスクは **docs/handoff.md** に書く。

仕様書は確定版ではなく、作りながら変えていく前提のたたき台。実装してみて仕様と合わない・もっと良い形があると分かったら、本人と相談して決め、決まった内容を docs/spec.md に反映する（変えた日付と理由も一言残す）。

## よく使うコマンド

```bash
xcodegen generate   # project.yml から .xcodeproj を作り直す（ファイルを足したら毎回）
xcodebuild -project IllustApp.xcodeproj -scheme IllustApp -destination 'id=E429B161-CAA4-424E-9197-0732F1CE1036' -derivedDataPath build build
cd IllustrationKit && swift test                                   # 変換処理のテスト（Mac 上で動く）
cd IllustrationKit && swift run IllustPrototype <入力フォルダ> <出力フォルダ>   # ステップ1の試作
```

## 構成

- `IllustApp/`：アプリ本体（画面だけ）
- `IllustrationKit/`：変換処理だけをまとめた Swift Package。iOS と macOS の両方でビルドできるので、試作もテストも Mac 上で回せる。将来は無音カメラ（`../silent_camera`）からも読み込む
- `.xcodeproj` は XcodeGen で `project.yml` から生成する。git には `project.yml` だけを入れる
- バンドルID は `com.tmando616.illust`（全アプリ共通の頭は `com.tmando616`。公開後は変えられない）

## 守ること

- 変換処理の入出力は `CIImage` に統一する。画風は `IllustrationStyle`（データ）として持ち、コードを変えずに足せるようにする
- 最初にステップ1の試作で「イラストに見えるか」を確かめ、本人が見た目に納得してからアプリに組み込む
- 写真を公開モデル（AnimeGAN など）で変換しない（商用利用できないライセンスが多い）。ネット上のイラストをお手本にして公開版に入れない
- 写真は PhotosPicker で選ぶ（読み取りの許可が要らない）。サーバーには送らない
- 広告は最後のステップで入れる。開発中は必ずテスト用の広告IDを使う
- 未決事項（docs/spec.md の「未決事項」）は勝手に決めず、本人に確認する
- 修正のたびに `swift test` とアプリのビルドを通してからコミットする
- 説明は簡潔に、「なぜそうするか」をセットで。Laravelにたとえると伝わりやすい
