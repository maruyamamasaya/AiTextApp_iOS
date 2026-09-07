# External disaster recovery backup

- Files／iCloud Drive folder pickerとsecurity-scoped bookmarkによる保存先再利用を追加。
- SQLite Online Backup APIで外部snapshotを作り、manifest検証後に`latest`／`previous`を安全にrotation。
- RestoreをApplication Supportへstageし、次回起動のRepository生成前に現DB・WAL・SHMをrollback可能な形で置換。
- 不正manifest、破損DB、サイズ／SHA-256、path／symlink、integrity、schemaを検証。
- Core testを31件まで拡張し全件成功。iOS Simulator Debug build成功。
- Files providerおよびiCloud Drive実機操作は未確認。
