---
title: "ElixirとNostrで、インターネットから見えない分散SNS「Engawa」を作りました"
emoji: "🏡"
type: "tech"
topics: ["elixir", "nostr", "wireguard", "ゼロトラスト", "lolipop"]
published: true
publication_name: pepabo
---

GMOペパボの「[ロリポップ！ゼロトラストリンク](https://ztna.lolipop.jp/)」（以下、ZTL）のLinux版クライアントが公開されました。ZTLは、離れた場所にある機器同士を、ポートを公開することなく直接つなぐことができるサービスです。参加した機器にはネットワーク内だけで通用するIPアドレスが振られ、そのアドレスで互いに通信できます。これまでは、macOS、Windows、iOS、Androidと、人が手で触る端末向けのクライアントを提供してきましたが、今回のLinux版によって、サーバやコンテナもメッシュに参加できるようになりました。同時に公開されたESP32版と合わせたリリースの経緯については、[テックブログの記事](https://tech.pepabo.com/2026/08/03/stackchan-zero-trust-link/)に書いています。

本記事では、このLinux版を土台にして作った2つのOSSを紹介します。ひとつは、ZTLをはじめとするメッシュVPNの上でErlangクラスタを自動形成するライブラリ、libcluster_meshです。

https://github.com/kentaro/libcluster_mesh

もうひとつは、そのユースケースとして、クラスタの上に[Nostr](https://github.com/nostr-protocol/nostr)プロトコルで実装したSNS、Engawa（縁側）です。

https://github.com/kentaro/engawa

Engawaはメッシュの中からだけアクセスできるSNSで、すべてのノードが全投稿を保持しているため、どのノードが落ちても、残りのノードをブラウザで開けばそのまま使い続けられます。全体としては、以下のような3層の構成になっています。

| 層 | 役割 |
|---|---|
| Engawa | メッシュ内だけのSNS（Nostrリレー + Webクライアント + SQLite） |
| libcluster_mesh | メッシュ上でのノード発見とErlangクラスタ形成 |
| ZTLなどのメッシュVPN | 暗号化されたフラットなプライベートネットワーク |

## 博論でやりたかったことの続き

博士論文「[IoTシステム開発の複雑さを低減するための統合的アーキテクチャ](https://speakerdeck.com/kentaro/dynamic-isomorphic-iot-system-architecture)」では、異種混合が当然とされてきたIoTシステムを、Elixirという単一言語とErlangの分散ネットワークによって統合的に開発する手法を研究していました。デバイスにもエッジにもクラウドにも同じ言語、同じ分散機構が載るという等質性（isomorphism）を目指したものです。もっとも、当時のシステム構成は、デバイス層がエッジ層に、エッジ層がクラウド層に接続するという階層構造を前提としていました。

![博士論文で扱った、階層構成のIoTシステム](/images/mesh-native-sns-engawa/phd-layered.jpg)
*博論の頃の構成。デバイス層、エッジ層、クラウド層の階層（発表スライドより）*

ゼロトラストメッシュの上では、こうした階層を組む必要がそもそもありません。NAT越えや暗号化、相手への到達性はメッシュVPNが引き受けてくれるので、接続の都合で「下の層から上の層へつなぎに行く」構成にしなくても、クラウドのサーバも、工場やスマートホームのエッジも、[Nerves](https://nerves-project.org/)を載せたデバイスも、同じアドレス空間に対等に並びます。そこにlibcluster_meshを組み合わせると、あちこちで動いているElixirノードが互いを自動で発見して、ひとつのErlangクラスタになります。博論の頃に階層として組んでいた構成を、フラットに置き直せるようになりました。

![ゼロトラストメッシュで、すべてのノードが対等につながる](/images/mesh-native-sns-engawa/zerotrust-mesh.jpg)
*ゼロトラストメッシュでは、すべてのノードが直接つながる*

フラットに全部つながって大丈夫なのか、という点は、ZTLのアクセスルールでコントロールします。誰から誰への通信を、どのポート・プロトコル（`443/tcp`のような形式）で許可するかを、ユーザー単位でダッシュボードから設定できます。Erlangクラスタの分散ポートやEngawaのポートを誰に開けるかも、これで絞れます。

## ZTLのLinux版

Linux版は、systemdで常駐させて使うサーバ向けのクライアントです。root権限もカーネルのTUNデバイスも使わないモード（root不要モード）が用意されており、権限を絞ったコンテナの中でも動かせます。

ただし、Erlangクラスタを組む場合はTUNモードを使います。root不要モードにはOSから見えるネットワークインターフェースがなく、BEAMが分散プロトコルのリスナーをメッシュアドレスにバインドできないためです。

## libcluster_meshの概要

Elixirでノード同士をつなぐ際の定番は[libcluster](https://github.com/bitwalker/libcluster)です。メンバーを固定してよいのであれば、メッシュの上でも、既存のEpmd戦略にノード名を列挙するだけでクラスタを組めます。ただしこの場合、ノードを1台追加するたびに全ノードの設定を書き換えることになります。

動的にノードを発見しようとすると、今度は組み込みのストラテジーが使えません。GossipはUDPのマルチキャスト（設定によってはブロードキャスト）で互いを見つける方式で、ピアごとの1対1トンネルの集まりであるWireGuard系のメッシュには、そうしたパケットの届く範囲がありません。DNSPollも、1つの名前から複数ノードのアドレスが引けることを前提にしているので、1ホスト1名前のMagicDNSのようなメッシュのDNSとは噛み合いません。TailscaleにはクラウドAPIからデバイス一覧を取る[libcluster_tailscale](https://github.com/moomerman/libcluster_tailscale)というストラテジーもあって、これは動きます。ただAPIキーの発行と管理が必要ですし、接続先が`api.tailscale.com`に固定されているのでHeadscaleのようなセルフホストのコントロールサーバでは使えず、当然ながらTailscale以外のメッシュにも使えません。

一方で、メッシュの各ノードで動いているデーモンは、ピア全員のメッシュIP、ホスト名、オンライン状態の一覧をもともと持っています。libcluster_meshはこれを使います。ローカルのデーモンを数秒おきにポーリングしてピア一覧を読み取り、ホスト名のプレフィックスでクラスタメンバーを選別し（ホスト名のない素のWireGuardでは、IPアドレスのCIDRで選びます）、`basename@メッシュIP`形式のノード名に変換して、libclusterに接続を任せます。クラウドAPIもAPIキーも静的なホストリストも必要なく、ノード発見のトラフィックがホストの外に出ることもありません。

対応しているメッシュは、以下の4つです。

| ストラテジー | メッシュ | ピアの情報源 |
|---|---|---|
| `Cluster.Strategy.TailscaleLocal` | Tailscale（Headscale網を含む） | `tailscale status --json` |
| `Cluster.Strategy.Netbird` | NetBird | `netbird status --json` |
| `Cluster.Strategy.LolipopZTL` | ロリポップ！ゼロトラストリンク | `ztlctl status` |
| `Cluster.Strategy.WireGuard` | 素のWireGuard（手組みのメッシュ） | `wg show <if> dump` |

libcluster_meshは[hex.pm](https://hex.pm/packages/libcluster_mesh)に公開してあるので、mix.exsのdepsに足せば入ります（ドキュメントは[hexdocs.pm/libcluster_mesh](https://hexdocs.pm/libcluster_mesh)）。

```elixir
def deps do
  [
    {:libcluster_mesh, "~> 0.1"}
  ]
end
```

設定は、libclusterのトポロジーとして書きます。ZTLの場合は以下のようになります。

```elixir
config :libcluster,
  topologies: [
    ztl: [
      strategy: Cluster.Strategy.LolipopZTL,
      config: [
        node_basename: "myapp",
        hostnames: ["myapp-"]
      ]
    ]
  ]
```

各ノードは、メッシュのIPv4アドレスを使ったlongnameで起動します。EPMD（ノード名から分散プロトコルのポートを引くためのデーモン）を使わず、全ノード共通の固定ポートにするのが簡単です。

```sh
elixir --name myapp@100.64.0.7 --cookie "$CLUSTER_COOKIE" \
  --erl "-start_epmd false -erl_epmd_port 45892" \
  -S mix run --no-halt
```

Erlangの分散プロトコル自体は平文ですが、通信はWireGuardで暗号化されたメッシュの中だけを流れます。4つのストラテジーはどれも実際のネットワークで動かして、`Node.list/0`の収束とノード間RPCの往復まで確認しています（Macとラズベリーパイのtailnet、本番のZTL網、NetBirdのP2P経路、3台で手組みしたWireGuardメッシュ）。

## Engawaの概要

メッシュの上にElixirクラスタが組めるようになると、今度はその上で何か動かしたくなります。メッシュの中に自分たちだけのSNSがあったら面白いですよね。そんなわけで作ったのがEngawaです。

![Engawaのノード構成](/images/mesh-native-sns-engawa/engawa-architecture.png)
*1ノード = Nostrリレー + Webクライアント + SQLite。ノード同士はErlangクラスタで同期する*

名前は、家の縁側から取りました。家の内と外の中間にあって、身内や近所の人が腰掛けていく場所です。Engawaも、メッシュに入っているマシンからは使えて、外からは入れません。誰が入れるかはメッシュ側のデバイス管理で決まるため、Engawa自身にアカウント登録はありません。招待も不要です。かわりに、初めて開いたときにブラウザがNostrの鍵ペアを生成し、それがそのまま自分のアイデンティティになります。NIP-07拡張によるログインや、手持ちのnsecのインポートにも対応しています。

1ノードは、Nostrリレー、Webクライアント、SQLiteをまとめた1つのプロセスとして動きます。各マシンでバイナリを1つ動かすと、どのノードをブラウザで開いても、タイムライン、スレッド、プロフィール、フォロー、通知、全文検索を備えたSNSが表示されます。

![Engawaのタイムライン](/images/mesh-native-sns-engawa/engawa-timeline.png)
*タイムライン。右上に、いま自分がどのノードにつながっているかが出る*

### Nostrを使う理由

投稿のデータ形式にNostrを使っているのは、レプリケーションが簡単になるからです。Nostrのイベントは鍵ペアで署名されており、IDは内容のハッシュになっています。どのノードを経由して届いても改ざんを検出でき、同じ投稿は必ず同じIDになります。そのため、ノード間の同期は「相手がまだ持っていないイベントを渡す」だけの集合の和（set union）で済みます。順序の合意とかリーダー選出とか、面倒なことは要りません。

ノードが落ちたり復帰したりしても、特別なことは何もしていません。各ノードはピアごとにカーソルを持っていて、再接続時と数分おきに差分を交換します。ノードを落としても他のノードで読み書きは続きますし、落ちていたノードも復帰後には自動的に追いつきます。

![ノード復帰時のキャッチアップ](/images/mesh-native-sns-engawa/engawa-catchup.png)
*落ちていたノードは、ピアごとのカーソルの続きから差分をもらって追いつく*

使っているのはどれも標準のNIPイベント（ノート、プロフィール、リアクション、ブースト、フォロー、削除）なので、手持ちのNostrクライアントからノードに接続できます。

### 外部メディアの扱い

サーバをメッシュアドレスにバインドしただけだと、実は外に漏れる経路が残っています。投稿に外部サイトの画像URLが貼られていて、閲覧者のブラウザがそれを取りに行くと、閲覧の事実がメッシュの外に漏れてしまうのです。そこでEngawaは、外部URLのメディアをデフォルトでは読み込まないようにしています。表示したい場合は、設定でオプトインします。

### 単一バイナリでの配布

配布には、[Burrito](https://github.com/burrito-elixir/burrito)で作った自己完結の単一バイナリを使っています。Erlangごと入っているので、動かすマシンには何もインストールする必要がありません。[v0.1.0のリリース](https://github.com/kentaro/engawa/releases/tag/v0.1.0)を公開済みで、下の`latest/download`のURLはここから最新版を落としてきます。

```sh
curl -fsSLo engawa https://github.com/kentaro/engawa/releases/latest/download/engawa-linux_x86
chmod +x engawa
ENGAWA_MESH=ztl ENGAWA_HOSTNAMES=engawa- \
ENGAWA_BIND=100.64.0.7 ENGAWA_COOKIE=... ./engawa --no-halt
```

`ENGAWA_BIND`にそのマシンのメッシュアドレスを、`ENGAWA_MESH`にどのメッシュにいるかを指定すると、あとはlibcluster_meshが他のノードを見つけてクラスタにつなぎます。バイナリは`linux_x86`、`linux_arm`、`macos_arm`、`macos_x86`の4種類で、リリースのCIがそれぞれについて、起動と`/health`の応答、クラスタのノードとして名乗れているところまでを確認します。加えてv0.1.0では、ElixirもErlangも入っていないDebian slimのイメージ3台をZTLメッシュ上でクラスタにして、163件の書き込みが3台すべてで一致することを確かめました。

![実際のネットワーク構成](/images/mesh-native-sns-engawa/engawa-network.png)
*構成例。ZTLのメッシュに入れたマシンそれぞれで、バイナリを1つ動かす*

## おわりに

3つの層は、それぞれ独立に使えます。libcluster_meshはZTLのほかにTailscale、NetBird、素のWireGuardでも動きますし、EngawaはNostrクライアントから見れば、ただのリレーの集まりです。とはいえ、作っている本人としては、ZTLで使ってもらえるのがいちばんうれしいところです。今回のLinux版とESP32版でサーバからマイコンまでクライアントが揃いましたし、これから他のサービスにはない機能もあれこれ実装していく予定です。

メッシュVPNを、社内リソースへ安全に入るための道具としてだけ使うのはもったいないと思っています。せっかく全員が対等につながる暗号化されたネットワークがあるのだから、その上で直接アプリケーションを動かすほうが面白いです。ZTLのメッシュに手元のマシンやVPS、ラズベリーパイを入れて、自分たちだけのSNSをぜひ立ててみてください。
