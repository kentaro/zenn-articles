// 実際のネットワーク構成（ZTLメッシュ上のEngawaクラスタ）
// 生成: typst compile engawa-network.typ engawa-network.png --ppi 200
#set page(width: auto, height: auto, margin: 16pt, fill: white)
#set text(font: "Hiragino Kaku Gothic ProN", size: 9pt, fill: rgb("#1f2328"))

#let ink = rgb("#1f2328")
#let muted = rgb("#7a828e")
#let accent = rgb("#0f7b6c")
#let line-col = rgb("#d5d9e0")

#let machine(title, addr, items) = box(
  inset: (x: 14pt, y: 10pt), radius: 5pt,
  fill: white, stroke: 0.9pt + ink,
  align(center)[
    #text(size: 10pt, weight: "bold")[#title] \
    #v(1pt)
    #text(size: 7.5pt, fill: muted, font: "Menlo")[#addr]
    #v(5pt)
    #line(length: 100%, stroke: 0.5pt + line-col)
    #v(5pt)
    #text(size: 8.5pt)[#items.join([ \ ])]
  ],
)

#let viewer(title, sub) = box(
  inset: (x: 12pt, y: 8pt), radius: 5pt,
  fill: rgb("#e3efec"), stroke: 0.9pt + accent,
  align(center)[
    #text(size: 9.5pt, weight: "bold")[#title] \
    #text(size: 7.5pt, fill: muted)[#sub]
  ],
)

#align(center)[
  #box(
    inset: (x: 20pt, top: 14pt, bottom: 16pt), radius: 8pt,
    fill: rgb("#f7faf9"), stroke: (paint: accent, thickness: 1.1pt),
    [
      #align(left)[
        #text(size: 9pt, weight: "bold", fill: accent)[ZTLのメッシュ]
        #h(6pt)
        #text(size: 7.5pt, fill: muted)[参加した機器だけのアドレス空間]
      ]
      #v(10pt)
      #grid(
        columns: 3, column-gutter: 14pt, align: horizon,
        machine([自宅のMac], [100.64.0.7], ([engawa（単一バイナリ）],)),
        machine([VPS], [100.64.0.9], ([engawa（単一バイナリ）],)),
        machine([ラズベリーパイ], [100.64.0.5], ([engawa（単一バイナリ）],)),
      )
      #v(12pt)
      #align(center, viewer([ノートPCやスマホ], [メッシュに参加して、ブラウザで閲覧・投稿]))
    ],
  )

  #v(8pt)
  #text(size: 8pt, fill: muted)[
    メッシュの外（インターネット）からは、どのノードにも到達できない。ポートはどこにも公開しない
  ]
]
