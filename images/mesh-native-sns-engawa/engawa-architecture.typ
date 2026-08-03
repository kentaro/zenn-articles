// Engawaのノード構成と同期を示す図
// 生成: typst compile engawa-architecture.typ engawa-architecture.png --ppi 200
#import "@preview/cetz:0.4.2"

#set page(width: auto, height: auto, margin: 16pt, fill: white)
#set text(font: "Hiragino Kaku Gothic ProN", size: 9pt, fill: rgb("#1f2328"))

#let ink = rgb("#1f2328")
#let muted = rgb("#7a828e")
#let accent = rgb("#0f7b6c")
#let line-col = rgb("#d5d9e0")

#let node(title, sub, items) = box(
  inset: (x: 14pt, y: 10pt), radius: 5pt,
  fill: white, stroke: 0.9pt + ink,
  align(center)[
    #text(size: 10pt, weight: "bold")[#title] \
    #v(1pt)
    #text(size: 7.5pt, fill: muted)[#sub]
    #v(5pt)
    #line(length: 100%, stroke: 0.5pt + line-col)
    #v(5pt)
    #text(size: 8.5pt)[#items.join([ \ ])]
  ],
)

#let browser = box(
  inset: (x: 14pt, y: 8pt), radius: 5pt,
  fill: rgb("#e3efec"), stroke: 0.9pt + accent,
  align(center)[
    #text(size: 10pt, weight: "bold")[ブラウザ] \
    #text(size: 7.5pt, fill: muted)[メッシュ内のどのマシンからでも]
  ],
)

#cetz.canvas(length: 1cm, {
  import cetz.draw: *

  let xa = 2.3
  let xb = 6.9
  let xc = 11.5
  let node-y = 1.6
  let browser-y = 5.4

  // ブラウザからどのノードへも届く
  for x in (xa, xb, xc) {
    line((xb, browser-y - 0.75), (x, node-y + 1.55),
         mark: (end: ">", fill: accent, scale: 0.7),
         stroke: (paint: accent, thickness: 1.0pt))
  }
  content((xb, browser-y - 1.05),
          box(inset: (x: 6pt, y: 3pt), fill: white,
              text(size: 8pt, fill: accent)[どのノードを開いても同じSNS]))

  // ノード間の同期
  let sync(x1, x2) = line((x1 + 1.75, node-y), (x2 - 1.75, node-y),
       mark: (start: ">", end: ">", fill: ink, scale: 0.7),
       stroke: (paint: ink, thickness: 1.0pt, dash: (3pt, 2.5pt)))
  sync(xa, xb)
  sync(xb, xc)
  content(((xa + xb) / 2, node-y + 0.35),
          box(inset: (x: 3pt), fill: white, text(size: 7.5pt, fill: muted)[同期]))
  content(((xb + xc) / 2, node-y + 0.35),
          box(inset: (x: 3pt), fill: white, text(size: 7.5pt, fill: muted)[同期]))

  content((xb, browser-y), browser)
  content((xa, node-y), node([ノードA], [Mac], ([Nostrリレー], [Webクライアント], [SQLite])))
  content((xb, node-y), node([ノードB], [VPS], ([Nostrリレー], [Webクライアント], [SQLite])))
  content((xc, node-y), node([ノードC], [ラズベリーパイ], ([Nostrリレー], [Webクライアント], [SQLite])))

  content((xb, -0.95), text(size: 8pt, fill: muted)[
    全ノードが全投稿を保持する。どれか落ちても、残りのノードで読み書きが続く
  ])
})
