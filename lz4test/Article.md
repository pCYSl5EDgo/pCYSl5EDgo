# [LZ4](https://github.com/lz4/lz4) of [Messagepack-CSharp](https://github.com/neuecc/Messagepack-CSharp) implemented by [WebAssembly](https://webassembly.org/)

1988年12月27日は[きみか](https://twitter.com/kimika127)さんの誕生日なので初登校です。

皆さんこんにちは～！ バーチャルHigh Performance C#erの[スーギ・ノウコ自治区](https://twitter.com/pCYSl5EDgo)です。<br>

この記事では車輪の再発明を行いたいと思います。

[この記事のデモはこちらです。](https://pCYSl5EDgo.github.io/pCYSl5EDgo/lz4test/)

# 背景

ASP.NET CoreでWEBサーバーを構築し、ブラウザとリアルタイムに通信したくなりませんか？<br>
その際にはgRPCかSignalRを利用するのが常套手段であり王道！正攻法！と言えます。

ですが！全然！足りないのですよねえ！！

## SignalRが駄目な理由

WebSocketで通信できない環境でもファールバックしてくれるナイスガイです。<br>
従来は全データをBASE64エンコードしてテキストフォーマットで送信していたそうです。

いつの頃からかよくわかりませんが、多分[AArnott](https://github.com/AArnott)さんが開発に参加した頃から[MessagePack](https://msgpack.org/ja.html)でバイナリ送信してくれるようになりました。<br>
この記事を読む方なら[Messagepack-CSharp](https://github.com/neuecc/Messagepack-CSharp)はご存知でしょう。<br>
C#大統一理論を実現する[MagicOnion](https://github.com/CySharp/MagicOnion)でも内部的に利用されています。<br>

**SignalRはブラウザJavaScriptに対応してくれていますからこれで安心ですね！**、とはいきませんでした。<br>
[MessagePack-CSharpの重要な機能にLZ4圧縮があります。](http://neue.cc/2017/03/13_550.html)<br>

これをSignalRはサポートしていないのですね。<br>
理由としてはJavaScript側の[Messagepack](https://msgpack.org/ja.html)ライブラリとして[msgpack5](https://github.com/mcollina/msgpack5)を使用しているからです。<br>
[Messagepack-CSharp](https://github.com/neuecc/Messagepack-CSharp)の[LZ4](https://github.com/lz4/lz4)機能は[Messagepack標準仕様](https://msgpack.org/ja.html)に含まれない独自拡張であるためデフォルトの[msgpack5](https://github.com/mcollina/msgpack5)が解釈してくれず機能不全を起こします。<br>
[msgpack5](https://github.com/mcollina/msgpack5)さんに独自拡張を追加することは可能ですが、SignalRチームはその努力を怠っています。<br>

### 追加検証 RFC7692

~~転送量減らしたいと思わないのかな……~~<br>
WebSocketはDEFLATE圧縮が掛かっている？みたいです？

https://github.com/aspnet/WebSockets/issues/19

上記issueを見るに2017年段階ではdeflate圧縮がper-message/frame両者ともに掛かっていないみたいです。<br>

https://github.com/dotnet/runtime/issues/31088<br>
最新リポジトリでもまだみたいですねえ……。<br>
.NET 6で実装されるのに期待するしか無いようです……。<br>
たすけて！もなふわすい～とる～む！！！<br>
~~.NET Core teamは３年以上なにやってるんでしょう？~~

## gRPCが駄目な理由

**[gRPC-web](https://github.com/grpc/grpc-web)がブラウザ―サーバー間の双方向通信をサポートしていないからです。**以上！<br>
[protobufが64bit整数をBigIntに対応付けしてくれず、文字列にシリアライズする点もかなり大きな減点対象です。](https://github.com/protocolbuffers/protobuf/issues/3666)

## ブラウザサイドLZ4

ブラウザサイドで[Messagepack-CSharp](https://github.com/neuecc/Messagepack-CSharp)の[LZ4](https://github.com/lz4/lz4)の圧縮・伸長を行えるライブラリがありさえすればだいぶ転送量が減らせて幸せになれます。<br>
この際に立ちはだかるのが[LZ4](https://github.com/lz4/lz4)の持つ２つのフォーマット仕様（Frame format, Block format）です。<br>
[Messagepack-CSharp](https://github.com/neuecc/Messagepack-CSharp)は[Block format](https://fuchsia.googlesource.com/third_party/lz4/+/HEAD/doc/lz4_Block_format.md)を使用しています。<br>
[このために、他のライブラリとの相互運用性を欠きがちです。](https://qiita.com/koshian2/items/b046ff4369f9c587ba65)

既存のJavaScriptで実装されたLZ4ライブラリ群が使えないのです。<br>
これはつらい。

# LZ4を実装しよう

Messagepack-CSharpはLZ4で使用する機能を絞って定数値として埋め込むことで速くしています。<br>
実際に実装を見てみますとほぼノリがC言語です。

## Emscripten

[Emscriptenのメモリ確保問題を解決するのめんどいのでパス。](https://qiita.com/goccy/items/1b2ff919b4b5e5a06110#emscripten%E3%81%AE%E3%83%A1%E3%83%A2%E3%83%AA%E3%82%A2%E3%83%AD%E3%82%B1%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3%E6%88%A6%E7%95%A5)。

## Rust, WebAssembly

手書きよりどうあがいてもサイズが肥大したので今回は見送りました。

## WebAssembly Text Format手書き

WebAssemblyについての個人的に重大であると思われる制約は以下の通りでした。

- 全てのローカル変数を関数の最初に列記する必要がある
  - どこのC言語？
- 戻り値のある関数については早期returnが不可能
- 制御構文の癖が強い
  - ループ系はdo-while文（のようなもの）しか無い
  - goto文に近いものがあるが、ソースコード上の先にしか勧めず戻ることは出来ない
- スタック上の値についてポインタを取得できない
- 文献について逆ポーランド記法とS式が混在している
  - 両方とも正しい

# WebAssemblyを意識したC#の書き換え

## bool型

WebAssemblyにbool型は存在しません。<br>
int, uint, long, ulongを都度使用しましょう。

Before

```csharp
bool isA = HogeFunction();
if (isA)
{
    // Do somthing
}
```

After

```csharp
int isAWhenZero = HogeFunction();
if (isAWhenZero == 0)
{
    // Do somthing
}
```

## while文

Before

```csharp
// int i, j;
while (i++ != SomeFunc(j))
{
    // Do something;
}
```

After

```csharp
// int i, j;
if (i++ != SomeFunc(j))
{
    while (true)
    {
        // Do something;
        if (i++ != SomeFunc(j)) continue;
        break;
    }
}
```

## for文

Before

```csharp
for (int i = 0; i < hoge.length; ++i)
{
    // Do something;
}
```

After

```csharp
int hogeLength;
int i;

// some pre-execution

i = 0;
if (i < hogeLength)
{
    while (true)
    {
        // Do something;
        if (++i < hogeLength) continue;
        break;
    }
}
```

## do-while文

Before

```csharp
// int i, j;
do
{
    // Do something;
}
while (i++ != SomeFunc(j));
```

After

```csharp
// int i, j;
while (true)
{
    // Do something;
    if (i++ != SomeFunc(j)) continue;
    break;
}
```

## 以前の部分に戻るgoto

Before

```csharp
// Do Something 0
LABEL0:
// Do Something 1
if (HogeFunction()) { goto LABEL0; }
// Do Something 2
```

After

```csharp
// Do Something 0
while (true)
{
    // Do Something 1
    if (HogeFunction()) { continue; }
    break;
}
// Do Something 2
```

## 後の部分に進むgoto

C#の文法では相当する表現がないため、コメントを使用して擬似的に再現しています。<br>
goto先のラベルの前までをブロックで囲むべきです。

Before

```csharp
if (FugaCondition())
{
    if (HogeFunction()) { goto LABEL0; }
    // Do Something 0
}
// Do Something 1
LABEL0:;
```

After

```csharp
{ // block before LABEL0
    if (FugaCondition())
    {
        if (HogeFunction()) { goto LABEL0; }
        // Do Something 0
    }
    // Do Something 1
} LABEL0:;
```

## 早期return

Before

```csharp
if (GuardCondition()) return 0;

// Do Something
return 1;
```

After

```csharp
if (GuardCondition())
{
    return 0;
}
else
{
    // Do Something
    return 1;
}
```

## while内で早期return

WebAssemblyの仕様上while文などのループ内で早期returnは出来ません。<br>
ソースコードの最後の部分にgotoしてそこで条件判定するしか無いです。

Before

```csharp
if (HogeFunction())
{
    while (true)
    {
        // Do Something 0
        if (GuardCondition()) { return 0; }
        // Do Something 1
        if (HogeFunction()) { continue; }
        break;
    }
}
// Do Something 2
return 1;
```

After

```csharp
// int isGuardReturnWhenOne = 0;
{ // block before RETURN
    if (HogeFunction())
    {
        while (true)
        {
            // Do Something 0
            if (GuardCondition())
            {
                isGuardReturnWhenOne = 1;
                goto RETURN;
            }
            // Do Something 1
            if (HogeFunction()) { continue; }
            break;
        }
    }
    // Do Something 2
} RETURN:;

if (isGuardReturnWhenOne == 0)
{
    return 1;
}
else
{
    return 0;
}
```

## 後置インクリメント

WebAssemblyコードがややこしくなり、理解しにくくなりますので後置インクリメントは避けましょう。

Before

```csharp
// int i, j;
HogeFunction(i * i++, j++);
```

After

```csharp
// int i, j;
HogeFunction(i * i, ++j);
++i;
```

# 実装

[実際のコードはこちらにあります。](./messagepack_lz4.wat)<br>
[WebAssemblyファイル単体だと使い勝手が最悪ですのでJavaScriptのグルーコードも記述しました。](./messagepack_lz4.js)

手書きのコツはC#コードをコメントとして記述した次の行にその行に対応したWebAssemblyを書くことです。<br>
VS CodeのWebAssembly拡張はインデントの整形の面倒を見てくれないため、複数行にまたがって記述するとコピペビリティがガクガクさがります。

# おしごと

以下の画像は全て[きみかさん](https://twitter.com/kimika127)の作品です。

- [Twitter](https://twitter.com/kimika127)
- [Home page](https://kimisaki.jp/)
- [Pixiv](https://www.pixiv.net/users/2332887)
- [GitHub](https://github.com/yKimisaki)
- [Qiita](https://qiita.com/yKimisaki)

![きみかさんかわいいよﾊｱﾊｱ](https://pbs.twimg.com/media/EqJguxKVQAAzUmB?format=jpg&name=small)
![きみかさんもなな推しているの最高だよﾊｱﾊｱ](https://pbs.twimg.com/media/EqBR7TKUYAItrjA?format=jpg&name=4096x4096)
![きみかさんﾁｮｫｶﾜｲｲ](https://pbs.twimg.com/media/EjVg1ICUcAE1KQW?format=jpg&name=large)