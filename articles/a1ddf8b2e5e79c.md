---
title: "DAWとブラウザをWeb MIDI経由で連携して音楽と映像を同期させる"
emoji: "🎵"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["DAW", "VJ", "WebMIDI", "Hydra"]
published: true
publication_name: pepabo
---

本記事では、DAWで作成した音源とブラウザ上でのビジュアル生成・制御を同期することで、VJ的な表現を実現するための基礎について解説します。実例として、以下のようなシンプルな音楽と映像の同期を実現します。

https://youtu.be/rFgd0amLtdE

## 本記事のソフトウェア構成

- OS: macOS
- DAW: Ableton Live 12
- 映像: [Hydra](https://hydra.ojack.xyz/)（ビジュアルプログラミング環境）

本記事では上記の構成を用いていますが、他の構成でも同様のことができると思います。適宜読み替えてください。

## データの流れ

1. DAWで仮想MIDIバスへMIDI信号を送る
2. ブラウザから仮想MIDIデバイスの出力を受け取る
3. MIDI信号に基づいて映像を生成・制御する

DAWで任意のMIDI信号を仮想MIDIバスに送り、それをブラウザで受け取ってプログラム処理すればOKです。

## 仮想MIDIバスを設定する

Abletonのオンラインマニュアル「[仮想MIDIバスの設定する](https://help.ableton.com/hc/ja/articles/209774225-%E4%BB%AE%E6%83%B3MIDI%E3%83%90%E3%82%B9%E3%81%AE%E8%A8%AD%E5%AE%9A%E3%81%99%E3%82%8B)」にある通り設定してください。ハマりどころだけ以下に書いておきます。

以下のようにIAC Driverを用いて仮想MIDIバスを作成するのですが、Macを日本語環境で使っていると、装置名やポートが「IACドライバー」「バス 1」のように日本語で設定されます。上記のマニュアルや下図の通り英数字にしないと、LiveからMIDI信号が送られませんでした。気をつけてください。

![](https://storage.googleapis.com/zenn-user-upload/02050bef12ea-20250429.png)

## DAWの設定

ここではドラムトラックのリズムに映像を同期させるために、シンプルなトラックを用意しました。ひとつめのトラックがインストゥルメンとの割り当てられたドラムトラックです（上記の映像の音を鳴らしているトラック）。ふたつめが、そのトラックのキック、スネアのみをコピーしたMIDI信号を送るためのトラックです。「MIDI To」に上記で設定した「IAC Driver（Bus 1）」を設定しています。

![](https://storage.googleapis.com/zenn-user-upload/c567957af337-20250429.png)

## ブラウザでMIDI信号を受け取る

ここではHydraというビジュアルプログラミング環境を用いています。Web MIDI APIを直接使ってもいいのですが、[arnoson/hydra-midi](https://github.com/arnoson/hydra-midi)という便利なライブラリがあります。

Hydraの画面に表示されているコードを全部して以下のコードを貼り付けましょう。

```javascript
await loadScript('https://cdn.jsdelivr.net/npm/hydra-midi@latest/dist/index.js')
await midi.start({ channel: '*', input: '*' })
midi.show()
```

DAWからの信号をちゃんと受け取れていれば、以下のようにMIDI信号が表示されるようになるはずです。

![](https://storage.googleapis.com/zenn-user-upload/c49cd02219b7-20250429.png)

## MIDI信号に合わせて映像を制御する

本記事の環境では、上記で作成したMIDIバスが2つめのMIDIインプットとして取得できましたので、それを用います（環境によってどれが仮想MIDIバスなのか異なりますので、上記の`midi.show()`の結果を見て選択してください）。

さて、キックが`36`、スネアが`38`というノートとして送られてくるので、それぞれに合わせて映像を切り替えるようにしましょう。以下のように信号が届いた時に実行される関数を書いてハンドリングします。それぞれのノートに対応する映像を呼び出すようにしています。

```javascript
live = midi.input(1).channel('*')
live.onNote('*', ({ note, velocity, channel }) => {
  switch (note) {
    case 36: { scene1(note); break; }
    case 38: { scene2(note); break; }
  }
})
```

映像をどう生成するかについては本記事では扱いませんので、[Hydraのドキュメント](https://hydra.ojack.xyz/docs/)をご覧ください。[本記事で作成した例](https://hydra.ojack.xyz/?sketch_id=AKMXsWI4iN3vqhuV)もどうぞ。MIDI信号のハンドリングのしかたについてはhydra-midiのドキュメントをご覧ください。

## 応用例

上記のようにしてMIDI信号をDAWとブラウザとで同期しつつ映像を生成・制御しつつ、その他にMIDIキーボードのモジュレーションホイールも使ってみた例を以下に挙げておきます。映像内では、DAWによるトラックの他、Max for LiveによるMIDI信号の送信、自作のWeb楽器での自動演奏とHydraによる映像生成を組み合わせています。

https://youtu.be/tDB8ePVxXdg

[Hydraのソースコード](https://hydra.ojack.xyz/?sketch_id=Ll2tgCwn0hB0aOre)

## おわりに

本記事では、DAWからWeb MIDI API経由でブラウザにMIDI信号を送り、映像との同期を実現する方法を解説しました。仮想MIDIバスの設定から始まり、Ableton Liveでの送信設定、ブラウザでの受信と処理までの一連の流れを示しました。この手法により、音楽と映像を連動させたパフォーマンスが可能になります。今回はHydraを使いましたが、同様の原理で他の構成でも連携できるでしょう。
