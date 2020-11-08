[スーギ・ノウコ自治区](https://twitter.com/pcysl5edgo)の活動履歴です。

# Mono.Cecil利用OSS

## Unity DOTS用ゼロマネージドヒープアロケーションLINQライブラリ UniNativeLinq 2019年度

[エディタ拡張](https://github.com/pCYSl5EDgo/UniNativeLinq-EditorExtension)<br/>
[コアライブラリ](https://github.com/pCYSl5EDgo/UniNativeLinq-Core)

特にエディタ拡張部分は[Mono.Cecil](https://qiita.com/pCYSl5EDgo/items/4146989d08e169dde81d)を利用して必要なAPIのみを利用できるように工夫しています。
ビルドサイズ削減技術の証明にもなるでしょう。

## Unity用最速Enum.ToStringライブラリ UniEnumExtension 2019年度

https://github.com/pCYSl5EDgo/UniEnumExtension

Mono.Cecilを利用してenumのToString()を高速な関数呼び出しに置換します。<br/>
場合によっては定数文字列に置換しますので実行時間をゼロにしたりできます。

## C++のconstexprをC#でも使いたいので作ったライブラリ dotnet-constexpr 2019年度

https://booth.pm/ja/items/1609135<br/>
[解説記事](https://qiita.com/pCYSl5EDgo/items/5846ce9255bf81b37807)

使い所が限られますけれどもコンパイル時計算という美しい概念に魅了されて作りました。<br/>
Mono.CecilによるIL weavingの華と言えるでしょう。

# GitHub Action OSS

## setup-unity 2019年度

https://github.com/pCYSl5EDgo/setup-unity

[GabLeRoux](https://gableroux.com/)氏の提供するUnityがインストールされたDocker imageは非常に便利です。
しかし、beta版やalpha版を利用できないのが常々残念でした。

そのため、beta, alphaをインストールするGitHub Actionを自作しました。

## create-unitypackage 2019年度

https://github.com/pCYSl5EDgo/create-unitypackage

[setup-unity](https://github.com/pCYSl5EDgo/setup-unity)や[GabLeRoux氏のDocker image](https://hub.docker.com/r/gableroux/unity3d/)を利用してunitypackageを生成するのは4分以上必要です。<br/>
unitypackage自体は特殊なフォルダ規則をしたtar.gzipファイルでしたので、shellスクリプトを頑張ることでUnityを使用せず作成できます。<br/>
数秒でCIが終わるようになって大満足の高速化でした。

https://github.com/pCYSl5EDgo/unitypackage は上記GitHub ActionからNode.js向けライブラリとして機能を独立させたものです。

## cat 2019年度

https://github.com/pCYSl5EDgo/cat

GitHub Actionはworkflowの変数と、各job内の環境変数の間に断絶があります。<br/>
この断絶を少しでも埋めるためにcatを実装しました。

# その他OSS

## UniUnsafeIO 2019年度

https://github.com/pCYSl5EDgo/UniUnsafeIO

Unity native C++ pluginの練習として作成しました。<br/>
Unity AsyncReadManagerの対になるように頑張って作っています。

## asmdef Scripting Defines 2020年度

https://github.com/pCYSl5EDgo/asmdefScriptingDefines

UnityのScripting Define Symbolsは2020でようやく配列として扱えるようになりました。<br/>
しかし、asmdef毎にScripting Define Symbolsを定義したくなりませんか？　私はなりました。なので作りました。

## EmbedResourceCSharp 2020年度

https://github.com/pCYSl5EDgo/EmbedResourceCSharp

C# Source Generatorの練習として良い感じに埋め込みリソースを扱えるようにしました。

# OSS Contribution

## MessagePack-CSharp

2020年度はほとんど[MessagePack-CSharp](https://github.com/neuecc/MessagePack-CSharp)に貢献していました。

- [mpc.exeのstring-keyの20%高速化](https://github.com/neuecc/MessagePack-CSharp/pull/861)
- [sbyte[]などのprimitive型配列の20倍SIMD高速化](https://github.com/neuecc/MessagePack-CSharp/pull/988)
- [ReadOnlySpan<byte>最適化](https://github.com/neuecc/MessagePack-CSharp/pull/1044)
- [一般化unmaned structフォーマッタ改善](https://github.com/neuecc/MessagePack-CSharp/pull/1053)

や他にも単なるリファクタリングなど色々貢献しています。Contributorとしては4位に現在なっています。

## Voiceer

https://github.com/negipoyoc/Voiceer

[GitHub Actionによるunitypackageの作成の自動化をするPull Requestを作成し、mergeしてもらいました。](https://github.com/negipoyoc/Voiceer/pull/9)

# 記事

[Qiita記事](https://qiita.com/pCYSl5EDgo)

GitHub ActionからUnity ECSまで様々なテーマについて記述しています。<br/>
特に[Mono.Cecilについての入門記事](https://qiita.com/pCYSl5EDgo/items/4146989d08e169dde81d)は日本語で書かれた資料の中で一番まとまりつつわかりやすい資料であると言えます。

## WASM仕様和訳

https://github.com/pCYSl5EDgo/WASMSpec

WASMに興味があり、一部を邦訳しました。<br/>
どんな仕様が現時点で不足していて、何があれば実用に耐えるのかを把握できました。

# ロビー活動

## Unity IL2CPP最適化 2020年度

[Unity Forum](forum.unity.com)でIl2CPPに関して最適化の要望を行い内部ロードマップに追加してもらいました。

### typeof(T) == typeof(struct型の具体的な名前)最適化

https://forum.unity.com/threads/il2cpp-proposal-replace-typeof-t-typeof-struct-type-il-sequence-with-constant-boolean-value.986313/#post-6406563

RyuJITで行われる最適化がIL2CPPで行われていませんでした。<br/>
ビルドサイズ削減につながりますし、実行速度も向上しますし、RyuJITのその最適化を前提としたコードを十分活かせるようになります。

### ReadOnlySpan<byte>最適化

https://forum.unity.com/threads/il2cpp-ldsflda-privateimplementationdetails-improvement-proposal.983847/

IL2CPPの詳細な挙動に踏み込んで大胆にシンプルにしてもらえるようお願いしました。