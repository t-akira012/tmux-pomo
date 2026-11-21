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
| `prefix + o` | cloud 版はサーバーから同期、local 版は表示を更新 |

cloud 版のタイマー時間は次のコマンドで**分**を指定する。指定可能な範囲は 1～1440 分。

```sh
./scripts/cloud/change_duration.sh 25
```

cloud 版は `SYNC_INTERVAL` 秒ごとにサーバー状態を取得し、取得した時刻から毎秒の表示値を端末側で計算する。残り時間が 0 を過ぎると `+` を付けて完了後の時間を表示し、停止後はその値を保持する。状態のキャッシュは Git 管理外の `.pomo-state.json` に保存する。

local 版のスクリプトは変更しない。固定 25 分の計測と `$HOME/.tmux-pomo.db` の SQLite を使う。
