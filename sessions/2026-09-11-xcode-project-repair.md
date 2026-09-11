# Xcode project repair

- `project.pbxproj` の全履歴とSwift Package関連参照を調査した。
- `e0788c5` で追加された `ExternalBrain.swift` の `PBXBuildFile` IDが、既存Firebase `XCRemoteSwiftPackageReference` IDと重複していたことを特定した。
- Firebase Package Referenceを維持し、ExternalBrainのBuild File IDだけを未使用IDへ変更した。
- `Package.resolved` はXcodeのPackage解決で追跡済みのFirebase 12.18.0ロック内容へ復元された。
- Mac検証で見つかった `ExternalBrain.swift` のSQLite module importとoptional usage context testを最小修正した。
- iOS 17.4でaccessibility element typeに依存していた検索UIテストをidentifierベースへ修正した。
- 検索結果の入れ子画面から型付きdestinationを解決できない遷移を明示destinationへ修正した。
- `plutil`と`xcodebuild -list`に成功し、Firebase 12.18.0と3 Target／2 Schemeを確認した。
- `swift test`は110件すべて成功した。
- iOS Simulator Debug buildに成功し、iPhone SE (3rd generation, iOS 17.4)のUIテスト14件すべて成功した。
