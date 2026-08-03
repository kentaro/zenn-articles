// ノード復帰時のキャッチアップを示すシーケンス図
// 生成: typst compile engawa-catchup.typ engawa-catchup.png --ppi 200
#import "@preview/cetz:0.4.2"

#set page(width: auto, height: auto, margin: 14pt, fill: white)
#set text(font: "Hiragino Kaku Gothic ProN", size: 9pt, fill: rgb("#1f2328"))

#let ink = rgb("#1f2328")
#let muted = rgb("#7a828e")
#let accent = rgb("#0f7b6c")
#let accent-soft = rgb("#e3efec")
#let line-col = rgb("#d5d9e0")

#let head-box(label) = box(
  inset: (x: 9pt, y: 6pt), radius: 4pt,
  fill: white, stroke: 0.9pt + ink,
  text(size: 9.5pt, weight: "bold")[#label],
)

#let tag(label, size: 8.5pt, fill-col: ink, weight: "regular") = box(
  inset: (x: 4pt), fill: white,
  text(size: size, fill: fill-col, weight: weight)[#label],
)

#cetz.canvas({
  import cetz.draw: *

  let brw = 1.4
  let na = 6.0
  let nb = 10.6
  let head-y = 9.4
  let foot-y = 0.9

  for x in (brw, na, nb) {
    line((x, head-y - 0.42), (x, foot-y),
         stroke: (paint: line-col, thickness: 0.7pt, dash: (2pt, 3pt)))
  }

  // ノードBの停止期間
  rect((nb - 0.35, 5.55), (nb + 0.35, 8.75), fill: rgb("#f0f1f4"), stroke: 0.7pt + muted)
  content((nb, 8.45), tag([停止中], size: 7.5pt, fill-col: muted))

  content((brw, head-y), head-box[ブラウザ])
  content((na, head-y), head-box[ノードA])
  content((nb, head-y), head-box[ノードB])

  let num(x, y, n) = {
    circle((x, y), radius: 0.16, fill: accent, stroke: none)
    content((x, y), text(size: 6.5pt, fill: white, weight: "bold")[#n])
  }

  let msg(y, x1, x2, n, label, note: none, reply: false) = {
    let dir = if x2 > x1 { 1 } else { -1 }
    let s = if reply {
      (paint: accent, thickness: 0.9pt, dash: (2.5pt, 2.5pt))
    } else {
      (paint: accent, thickness: 1.1pt)
    }
    line((x1 + 0.28 * dir, y), (x2 - 0.12 * dir, y),
         mark: (end: ">", fill: accent, scale: 0.6), stroke: s)
    num(x1 + 0.08 * dir, y, n)
    content(((x1 + x2) / 2 + 0.1 * dir, y + 0.28), tag(label))
    if note != none {
      content(((x1 + x2) / 2 + 0.1 * dir, y - 0.26),
              tag(note, size: 7.5pt, fill-col: muted))
    }
  }

  // Bが落ちている間の投稿
  msg(7.95, brw, na, 1, [投稿（EVENT）], note: [署名を検証して保存])
  content((brw + 0.25, 7.10), anchor: "west",
          tag([ノードBが落ちていても、投稿はノードAに積まれていく], size: 7.5pt, fill-col: muted))

  // Bの復帰
  content((nb, 5.25), tag([再起動・クラスタ再参加], size: 7.5pt, fill-col: ink))

  msg(4.45, nb, na, 2, [ノードAのカーソル以降を要求],
      note: [ピアごとに続きの位置を覚えている])
  msg(3.35, na, nb, 3, [未反映のイベントをまとめて送る], reply: true)
  msg(2.45, brw, nb, 4, [ノードBを開いてもタイムラインは同じ])

  content(((na + nb) / 2, 1.45), tag(
    [追いついたあとは、新しい投稿がリアルタイムに流れる],
    size: 8.5pt, fill-col: accent, weight: "bold",
  ))
})
