# 0007: 個人所有端末限定のOpenAI直接接続

- Status: Accepted（暫定）
- Date: 2026-09-12

## Context

AiTextAppでGeminiとOpenAIを選択可能にする。Firebase Callable FunctionsとSecret Managerを使う案はAPI keyを端末から分離できるが、Firebase projectをBlaze planへ変更する必要がある。現時点の利用者は開発者本人だけで、Xcodeから本人所有iPhoneへ導入し、TestFlight／App Store／第三者配布は行わない。利用者はクライアント側API keyの抽出リスクを理解し、Blazeや別のホスティングサービスを暫定導入しない方針を選択した。

OpenAIの公式API認証ガイドは、API keyをブラウザやアプリなどのclient-side codeへ公開せず、server側の環境変数またはkey management serviceから読むことを求めている。このDecisionは公式推奨を置き換える一般方針ではなく、適用範囲を限定した暫定的な例外である。

## Decision

- OpenAI API keyはSettingsの`SecureField`から入力し、`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`のKeychain itemへ保存する。
- Keyはソース、plist、UserDefaults、SQLite、Export、backup、analytics、ログ、Screenshotへ含めない。
- OpenAI選択時はiOS appからResponses APIへHTTPSで直接通信し、`store: false`を指定する。
- GeminiはFirebase AI LogicとApp Checkを継続する。OpenAI直接接続にFirebase Functions、Secret Manager、Blaze planは使わない。
- Keyの削除UIと、未設定・認証失敗・rate limit・network・API errorの境界を提供する。

## Required Migration Trigger

次のいずれかに該当する前に、このDecisionをSupersededにしてOpenAI直接接続を廃止する。

- TestFlightまたはApp Storeへ配布する。
- 第三者へapp binaryまたは利用権限を渡す。
- 複数利用者または管理外端末へ展開する。
- 個人実験から継続運用・公開サービスへ移行する。

移行後はAPI keyをバックエンドのSecret管理へ置き、利用者認証、端末／アプリ検証、rate limit、model allowlist、入力上限、監視、key rotation、緊急停止を実装する。

## Consequences

Blazeや別ホスティングを追加せず、自分のiPhoneからOpenAIを利用できる。一方、Keychainはserver側Secretと同等の防御境界ではなく、端末またはapp runtimeが侵害されればkeyを抽出される可能性が残る。端末紛失・譲渡・侵害の疑いがある場合は、端末内Keychain itemの削除だけでなくOpenAI側でkeyを失効・再発行する。
