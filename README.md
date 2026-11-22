# tmux-pomo

tmux のステータス行にタイマーの時間・名前・色を表示するプラグイン。

## 設定

リポジトリのルートで `.env.example` を `.env` にコピーし、`TIMER_ACCESS_INPUT` にネイティブタイマーのバックエンドと同じ PW を設定する。`.env` は Git 管理外。`TIMER_FQDN` は `https://` を付けずに指定する。

```sh
cp .env.example .env
chmod 600 .env
```

`USE_LOCAL=false` は Cloudflare Workers・D1 のタイマーに接続し、`USE_LOCAL=true` は既存のローカル SQLite 版を使う。切り替えたら `pomo.tmux` を読み直す。cloud 版では、プラグイン読み込み時に PW からアクセス用パスを一度計算して `.env` に追記し、以後は保存したパスを使う。PW を変更した場合は `.env` の `TIMER_ACCESS_PATH` 行を削除してから読み直す。`SYNC_INTERVAL` はサーバーとの同期間隔（秒）で、従来の設定値は 30 秒。

## tmux での操作

`pomo.tmux` を tmux 設定から読み込む。ステータス行には `#{pomo_status}`（時間）、`#{pomo_name}`（名前）、`#{pomo_color}`（色）を置ける。

| キー | 操作 |
| --- | --- |
| `prefix + p` | セッション名を入力して開始 |
| `prefix + P` | 確認して停止 |
| `prefix + O` | 実行中のセッション名を変更 |
| `prefix + M` | cloud 版の共有メモをR2から取得し、popupのnvimで編集 |
| `prefix + o` | cloud 版はサーバーから同期、local 版は表示を更新 |

cloud 版のタイマー時間は次のコマンドで**分**を指定する。指定可能な範囲は 1～1440 分。

```sh
./scripts/cloud/change_duration.sh 25
```

cloud 版は `SYNC_INTERVAL` 秒ごとにサーバー状態の取得を試みる。取得に失敗しても次の試行まで同じ間隔を空け、複数の表示から同時に呼ばれても取得は一度にまとめる。取得した時刻から毎秒の表示値を端末側で計算する。名前と色は状態取得時に tmux の設定値へ反映する。計時中は残り時間を赤で表示し、停止または期限到達で終了時刻を緑で固定表示する。開始ごとにサーバーが計時記録のIDを採番する。状態のキャッシュは Git 管理外の `.pomo-state.json` に保存する。

local 版のスクリプトは変更しない。固定 25 分の計測と `$HOME/.tmux-pomo.db` の SQLite を使う。

## 操作の検証

`python3 tests/cloud_contract.py` で10件の契約テストを実行する。
キー p・P・O・o、開始の名前入力、停止確認、名前変更、状態の時間・名前・色、時間設定の1〜1440分、同期・失敗時の再試行、local切替を確認する。
キー割当・プロンプト・コマンド名・引数を維持する。
計時記録は開始ごとに採番し、完了時刻を固定する。

## 共有メモ

cloud版は `scripts/cloud/memo.sh` で共有メモを編集する。`prefix + M` で既存のAPI経由でR2から取得し、画面の90%のtmux popupでnvimを開く。接続先はGit管理外の `.env` の `TIMER_FQDN` を使う。

`mktemp -d` で専用ディレクトリを作り、取得した本文を `memo.md` に保存する。nvimを終了した時、取得時から保存内容が変わっていればR2へ上書きPUTする。保存せず終了した場合と内容が同じ場合はPUTしない。保存後に追加編集して `:q!` で終了した場合は、最後に保存した内容をPUTする。末尾の改行も本文の一部として保持する。

PUT成功または変更なしで一時ディレクトリを削除する。取得失敗時はpopupを開かず一時ファイルを削除する。エディターやPUTの失敗時は編集ファイルを残し、tmuxのメッセージに場所を表示する。R2はアプリと同じ単一メモを使い、最後のPUTの内容で上書きする。local版のキー割り当ては既存のままとする。

`python3 tests/memo_contract.py` で取得失敗、保存と破棄、末尾改行、空の本文、PUT失敗時のファイル保持を確認する。
