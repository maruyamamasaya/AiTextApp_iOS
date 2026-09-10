# Vespera実機デプロイ

## 対象

- Vespera
- iPhone 17e
- iOS 26.6.1

## 結果

- 現在の作業ツリーをDebug構成で実機向けに署名・ビルドした。
- `com.example.AiTextApp`をVesperaへ上書きインストールした。
- インストール後にVespera上でアプリを起動した。

## 検証

- Vespera向け実機build: 成功。
- `devicectl`によるinstall: 成功。
- `devicectl`によるlaunch: 成功。
