//! クリップボード読み取りモジュール。
//! `arboard` を使って OS のクリップボードからテキストを取得する。

use anyhow::{Context, Result};
use arboard::Clipboard;

/// クリップボードのテキストを取得する。
///
/// テキストが無い場合（空、または画像などの非テキスト）は異常ではなく
/// 空文字列を返し、メッセージ表示は呼び出し側に任せる。
pub fn read_text() -> Result<String> {
    let mut clipboard = Clipboard::new().context("failed to access the system clipboard")?;
    match clipboard.get_text() {
        Ok(text) => Ok(text),
        Err(arboard::Error::ContentNotAvailable) => Ok(String::new()),
        Err(e) => Err(e).context("failed to read text from the clipboard"),
    }
}

/// クリップボードへ平文テキストを書き込む。
///
/// `set_text` はクリップボード全体を「テキスト 1 種類」で置き換えるため、
/// RTF / HTML などの書式付きデータは取り除かれる（＝「テキストのみ貼り付け」）。
pub fn set_text(text: &str) -> Result<()> {
    let mut clipboard = Clipboard::new().context("failed to access the system clipboard")?;
    clipboard
        .set_text(text.to_owned())
        .context("failed to write text to the clipboard")
}
