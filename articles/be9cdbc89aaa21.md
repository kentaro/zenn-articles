---
title: "GPTのAPIとTCPサーバを経由してしゃべりできるようにしてみた"
emoji: "💬"
type: "tech"
topics: [ChatGPT, GPT, Elixir]
published: true
---

「[Elixirで例の電子公告みたいなTelnetサーバを作ってみた](https://zenn.dev/kentarok/articles/b0811cabf55861)」なんて記事を書いていたら、温故知新 + 最新技術ということで、AIと組み合わせてみたくなりました。

というわけでやってみたのが以下です。GPTのAPIとTCPサーバを経由してしゃべりできるというものです。

https://twitter.com/kentaro/status/1699446998917918754

ソースコードはこちら。

https://github.com/kentaro/telgpt

いや別に、ローカルで実行するだけならTCPサーバを経由する必要はまったくないのですが……。どこかにデプロイしたら、慣れ親しんだコマンドでおしゃべりできるというのはいいですよね。

ところで、`telnet`コマンドだとうまくハンドリングできない問題があって、クライアントとして`nc`コマンドを使っていますが、そのあたりももうちょっと深掘りしたいところです。
