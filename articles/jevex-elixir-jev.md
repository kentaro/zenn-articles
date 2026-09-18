---
title: "Jevの判断をElixirの式として書ける「Jevex」を作りました"
emoji: "🧪"
type: "tech"
topics: ["elixir", "ai", "jev", "lolipop"]
published: false
publication_name: pepabo
---

TypeSafeの推論モデルJevをElixirから使うためのライブラリ、Jevexを作りました。文章を分類したり、緊急度を評価したりする処理を、いつもの`Enum`やパイプラインの中に書けます。

ソースコードは[GitHub](https://github.com/kentaro/jevex)、パッケージは[Hex](https://hex.pm/packages/jevex)、APIドキュメントは[HexDocs](https://hexdocs.pm/jevex/0.1.0/)で公開しています。

たとえば、問い合わせのうち対応が必要なものを拾い、担当チームごとにまとめる処理はこうなります。

```elixir
defmodule Tickets do
  use Jevex

  def queues(tickets) do
    tickets
    |> Enum.filter(&(&1 ~> "対応が必要な問い合わせですか？"))
    |> Enum.group_by(
      &(&1 ~> {"どのチームが担当しますか？",
        billing: "請求・支払い・返金",
        support: "技術的な問題・障害"})
    )
  end
end
```

`~>`の左側に評価するデータ、右側に質問を書きます。この例では、最初の質問がbooleanを返し、次の質問が`:billing`か`:support`を返します。どちらも普通のElixirの値なので、そのまま`Enum.filter/2`や`Enum.group_by/2`に渡せます。

Jev専用の繰り返し構文や条件分岐は作っていません。Jevから値を受け取った後は、Elixirにもともとある道具を使う、という作りです。

## Jevが返す3種類の値

JevのAPIでは、評価対象の`state`と質問を送り、質問の種類に応じた回答を受け取ります。[公式のAPIリファレンス](https://docs.typesafe.ai/api)には、次の3種類が定義されています。

| 種類 | 回答 |
|---|---|
| Noul | 質問への答えがyesである確率 |
| Choice | 指定した選択肢からの選択と、その確率分布 |
| Score | 順序を持った評価基準に沿った数値 |

Jevexも、この3種類を扱います。ただし、Noulを常にbooleanにしてしまうと、せっかくの確率が失われます。そこで、条件式向けの書き方と、確率をそのまま受け取る書き方を分けました。

```elixir
defmodule Urgency do
  use Jevex

  def urgent?(ticket) do
    ticket ~> "緊急の対応が必要ですか？"
  end

  def probability(ticket) do
    ticket ~> {:noul, "緊急の対応が必要ですか？"}
  end
end
```

文字列だけを渡すと、yesの確率がしきい値以上かを判定してbooleanを返します。しきい値の初期値は0.5です。`{:noul, 質問}`なら、`0.92`のような確率をそのまま返します。数値として集計したいときや、アプリケーション側で段階的に扱いたいときはこちらを使います。

Choiceは質問と選択肢を組にします。先ほどの例ではatomをキーにしましたが、文字列をキーにしたmapなら、選択結果も文字列になります。

Scoreには、低いほうから順に評価基準を並べます。

```elixir
defmodule Severity do
  use Jevex

  def score(ticket) do
    ticket ~> {"利用者への影響はどの程度ですか？",
      ["軽微な不便", "一部の機能が使えない", "サービス全体が使えない"]}
  end
end
```

この場合の範囲は0から2で、1.6のような小数も返ります。常に0から1に収まる数値ではありません。Noulの確率とは値の範囲が異なります。

## まずは公式APIにつなぐ

JevexはElixir 1.17以降に対応しています。[GitHub Actions](https://github.com/kentaro/jevex/actions/runs/35348801602)では、Elixir 1.17／OTP 27とElixir 1.20／OTP 29でテスト、静的解析、ドキュメント生成、パッケージのビルドを確認しています。

`mix.exs`の依存関係にJevexを追加します。

```elixir
defp deps do
  [
    {:jevex, "~> 0.1.0"}
  ]
end
```

`mix deps.get`を実行したら、TypeSafeのAPIキーを環境変数`TYPESAFE_API_KEY`に設定します。接続先は`config/runtime.exs`に書きます。

```elixir
import Config

config :jevex, :client,
  backend: :typesafe,
  api_key: {:system, "TYPESAFE_API_KEY"}
```

これで、冒頭の`Tickets.queues/1`などを呼び出せます。入力は文字列のほか、mapやlistでも構いません。ただし、リクエストとして送れるJSON互換のデータである必要があります。

接続先やキーはマクロに埋め込まず、実行時に読み取ります。`use Jevex`を書いたり、モジュールをコンパイルしたりしただけでは通信しません。

## EnumやStreamと組み合わせる

Scoreを並び替えのキーに使うなら、`Enum.sort_by/3`に渡します。

```elixir
defmodule RankedTickets do
  use Jevex

  def ranked(tickets) do
    Enum.sort_by(
      tickets,
      &(&1 ~> {"影響はどの程度ですか？", ["小さい", "中程度", "大きい"]}),
      :desc
    )
  end

  def probabilities(tickets) do
    Enum.map(tickets, fn ticket ->
      {ticket, ticket ~> {:noul, "緊急の対応が必要ですか？"}}
    end)
  end
end
```

`sort_by`は各要素のキーを1回ずつ求めます。比較関数の中で推論すると、比較のたびにAPIを呼ぶことになるので避けています。画面にもスコアを表示するなら、`{ticket, score}`の組を先に作ってから並び替えれば、その値を再利用できます。

Noulも、確率のままなら`Enum.map/2`で取り出して集計できます。たとえば、レビュー対象の選別に使う確率の分布を眺めたり、人の判断と比較したりできます。

途中まででよければ、`Stream`も使えます。

```elixir
defmodule TicketStream do
  use Jevex

  def first_five(tickets) do
    tickets
    |> Stream.filter(&(&1 ~> "対応が必要な問い合わせですか？"))
    |> Enum.take(5)
  end
end
```

ストリームを組み立てただけでは通信せず、列挙するときに推論します。5件見つかったら、それより先の要素は調べません。ただし、5件の該当を見つけるために、何十件も評価することはあります。`take(5)`がAPI呼び出しを5回に制限するわけではありません。

同じストリームをもう一度列挙すれば、再び通信します。Jevexが暗黙にキャッシュしたり、複数の式をまとめて送ったりすることはありません。

## 関数節への振り分けも普通に書く

Choiceの結果を使った振り分けには、関数節を使えます。

```elixir
defmodule TicketRouting do
  use Jevex

  def route(ticket) do
    team = ticket ~> {"担当はどちらですか？",
      billing: "請求・支払い", support: "技術的な問題"}

    dispatch(team, ticket)
  end

  defp dispatch(:billing, ticket), do: {:billing_queue, ticket}
  defp dispatch(:support, ticket), do: {:support_queue, ticket}
end
```

`case`で分岐してもよいですし、booleanを返す式なら`if`でも使えます。数値を受け取って`cond`でしきい値ごとに分ける書き方もできます。

一方、推論そのものをガードやパターンの中で呼ぶことはできません。先に値を求め、その値を使ってマッチさせます。モジュール本体での呼び出しも禁止し、コンパイル時に推論が走らないようにしています。

マクロが行っているのは、式を実行時の関数呼び出しに展開することです。左右の式はそれぞれ1回だけ評価されます。周囲の`if`や`and`を置き換えてはいないので、到達しなかった分岐の質問は送られません。

## エラーはwithで扱う

`~>`は、評価に失敗すると`Jevex.Error`を送出します。失敗を戻り値として扱うために、`~>>`も用意しました。こちらは`{:ok, value}`か`{:error, error}`を返します。

```elixir
defmodule TicketAssessment do
  use Jevex

  def assess(ticket) do
    with {:ok, probability} <- ticket ~>> {:noul, "緊急の対応が必要ですか？"},
         {:ok, team} <- ticket ~>> {"担当はどちらですか？",
           billing: "請求・支払い", support: "技術的な問題"},
         {:ok, score} <- ticket ~>> {"影響はどの程度ですか？",
           ["小さい", "中程度", "大きい"]} do
      {:ok, %{urgency: probability, team: team, severity: score}}
    end
  end
end
```

成功すれば3回の評価です。途中でエラーになれば`with`を抜けるため、残りの質問は送りません。コレクションの処理も、`Enum.reduce_while/3`と組み合わせれば、最初の失敗で止められます。

通信失敗を`false`として扱ってしまうと、「緊急ではない」のか「緊急度が分からない」のかを区別できません。その区別は、構文を短くしても残すようにしました。

## AIゲートウェイ経由で使う

公式APIのほかに、[ロリポップ！AIゲートウェイ](https://lolipop.jp/ai/gateway/)にも対応しています。APIキーを`LOLIPOP_AI_GATEWAY_API_KEY`に設定して、接続先を切り替えます。

```elixir
config :jevex, :client,
  backend: :lolipop,
  api_key: {:system, "LOLIPOP_AI_GATEWAY_API_KEY"}
```

質問を書く側のコードはそのままです。公式APIとゲートウェイのどちらにつなぐかは、実行時の設定で選べます。

OpenRouter、Cloudflare Workers AI、Vercel AI Gateway向けのアダプターも用意しています。それぞれの評価APIに合わせてリクエストを組み立てるため、単にChat CompletionsのURLを差し替える実装ではありません。接続先ごとの設定や制約は、リポジトリのガイドにまとめています。

## 確信が足りないときの扱い

booleanにするしきい値と、回答を採用するための確信度は、別の設定にしています。

```elixir
config :jevex, :client,
  backend: :typesafe,
  api_key: {:system, "TYPESAFE_API_KEY"}

config :jevex, :syntax,
  truth_threshold: 0.5,
  min_noul_certainty: 0.9,
  min_confidence: 0.8,
  on_error: :lolipop,
  on_low_confidence: :lolipop
```

TypeSafeを通常の接続先にしておけば、この例ではエラーや確信度不足のときにゲートウェイを試します。バックアップ側のAPIキーも必要です。

`truth_threshold`はNoulをbooleanに変換する境目です。`min_noul_certainty`は`max(p, 1 - p)`を調べます。yesの確率が0.1なら、noだという確信は0.9なので、低確率であること自体を理由に不採用にはしません。このチェックは、生のNoul確率を返す構文にも適用されます。

ChoiceとScoreには`min_confidence`を使います。接続先によって確信度が省略される場合もありますが、明示した条件を欠損値が通過することはありません。

バックアップを試すのは1段だけで、その回答にも同じ条件を適用します。条件を満たさなければエラーを返します。また、`on_error`の対象は通信エラーや一時的なHTTPエラーです。認証エラーや入力の不備まで別の接続先で繰り返すことはありません。

## 構文の下には独立したリクエスト層がある

内部は、HTTP通信、接続先ごとの変換、回答の検証、構文の順に分けています。構文の層だけに、認証やリトライを持ち込まないようにしました。

返ってきたJSONは、そのままElixirの値にしているわけではありません。質問と回答の対応、回答の型、確率の範囲、選択肢と確率分布を検証します。Choiceのatomも、受信した文字列から新しく作らず、呼び出し側が指定したキーに対応づけます。

Elixirが静的型付き言語になるわけではないので、型仕様だけで安全性を保証するとは考えていません。型仕様で表せる部分は静的解析に渡し、外部から受け取る値は実行時に検証します。ただし、形式が正しいことと、モデルの判断が正しいことは別です。確率の値が実際の正答率と一致する保証もありません。

複数の質問を1回にまとめたい場合は、低レイヤーのAPIを使います。

```elixir
client = Jevex.Client.new!(backend: :typesafe)

questions = %{
  "urgent" => Jevex.Question.noul!("緊急の対応が必要ですか？"),
  "severity" => Jevex.Question.score!("影響はどの程度ですか？", ["小さい", "大きい"])
}

{:ok, response} = Jevex.evaluate(client, "決済ができません", questions)
```

この方法なら、確率分布や使用トークン数なども受け取れます。再利用する質問群を宣言する`Jevex.Schema`もありますが、通常の式を書くためには不要です。

短い式でも、その先には通信があります。冒頭の例で100件を調べ、20件が残れば、通常は合計120回の評価です。リトライやバックアップが入ると、通信回数はさらに増えます。並列化したければ`Task.async_stream/3`を使えますが、同時実行数を増やしても評価回数は減りません。このあたりは、普通の関数のように書けるからこそ意識したいところです。

## サンプルと検証

型や確率分布の検証、エラー処理などについて193件のテストを通しています。LolipopのAPIに実際に接続する4件のテストも確認しました。リポジトリの`examples/syntax.exs`には、APIキーなしで構文を試せる例を入れてあります。

問い合わせの振り分けに限らず、文章のフィルタリングやレビュー対象の選別など、手元の処理に合うところで試してみてください。
