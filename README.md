# Countory

商品・数量・メモ・カテゴリを端末内で管理するiPhone / iPadアプリです。

## iPhone間のデータ移行

両方のiPhoneで、データ移行機能に対応したバージョンのCountoryを使用してください。

1. 旧iPhoneで画面上部の「データ移行」を開き、「バックアップを書き出す」を選びます。
2. JSONファイルをiCloud Driveへ保存します。AirDropを使う場合は、保存したファイルを「ファイル」アプリから共有し、新iPhoneの「ファイル」に保存します。
3. 新iPhoneで「データ移行」→「バックアップを選ぶ」を開き、保存したファイルを選びます。
4. 書き出し日時と追加件数を確認し、「この内容を取り込む」を押します。

「最近使った項目」にファイルがない場合は、「ブラウズ」からiCloud Driveや「このiPhone内」の保存先を開いてください。

商品ID・商品名・数量・メモ・登録日時・カテゴリを保存します。未使用のカテゴリも含み、検索や絞り込みに関係なく全件を書き出します。
同じ商品IDは取り込み先の内容を維持してスキップし、同名のカテゴリは再利用します。同名でもIDが異なる商品は別の商品として追加します。
取り込み先にあるデータの削除や上書きは行いません。ファイル形式はバージョン付きJSON、サイズ上限は20 MBです。

バックアップには商品名やメモがそのまま含まれます。新iPhoneで復元内容を確認してから、旧iPhoneのデータを消去してください。

## 開発・テスト

`Countory.xcodeproj`をXcodeで開き、`Countory`スキームを実行します。アプリはiOS 26.0以降、テストはiOS 26.2以降が対象です。

```sh
xcodebuild -scheme Countory -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
xcodebuild -scheme Countory -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' test
```

単体テストは復元・永続化・重複回避・不正ファイルの拒否を確認します。
UIテストでは、標準のファイル画面での書き出しから、削除したテスト商品の復元・再起動後の表示まで確認します。
商品編集中の数量・メモ・カテゴリ変更と検索、再起動後の保持も確認します。

## 新しいiOSへの対応確認

最低対応OSの`iOS 26.0`は、iOS 27でも動作させるために引き上げる必要はありません。
使用するSDKはXcodeが決め、実際に動作確認するOSは実行先のシミュレータまたは実機で決まります。
ビルド成功だけで判断せず、対象OS上でテストしてください。

2026年9月19日にXcode 27.0（27A266a）で、以下のシミュレータ検証を実施しました。

| 実行環境 | 結果 |
| --- | --- |
| iPhone 17 / iOS 27.0（24A434） | 単体10件・UI4件すべて成功 |
| iPhone 17 Pro / iOS 26.2（23C54） | 単体10件・UI4件すべて成功 |

検証で見つかった、カテゴリ追加時に編集中の内容がリセットされる問題と、自動保存前の終了でデータが失われる問題を修正しています。
編集画面に固定の商品IDを使い、商品・カテゴリの保存と商品の削除時に明示的に保存します。保存失敗時はエラーを表示します。

Xcode 27とiOS 27のシミュレータをインストールし、次のコマンドで確認できます。
シミュレータの名前は`xcrun simctl list devices available`で確認してください。

```sh
xcodebuild test -scheme Countory \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

公開前にはiOS 27の実機でも、旧版からデータを保持したまま更新し、商品編集・カテゴリ・検索・バックアップの書き出しと取り込みを確認してください。
AirDropとiCloud Driveを使った端末間の転送は実機で確認します。TestFlightで配布予定のビルドを検証できます。

参考: [Appleの実機・シミュレータでの動作確認](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)、[iOS 27リリースノート](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
