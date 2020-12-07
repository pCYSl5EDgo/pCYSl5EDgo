# C# Source GeneratorによるAOSOAを活用したDOTSプログラミング補助の試みとそのUnityにおける敗北

1999年12月8日は「ハリー・ポッターと賢者の石」が日本で発売された日です。故にこの記事も初投稿です。

この記事は、[もなふわすい～とる～む Advent Calendar 2020](https://adventar.org/calendars/5183)の8日目です。<br/>
昨日の記事は[サンマックスさん](https://twitter.com/Sunmax0731)の「[もなふわすい～とる～む in the VRChat](https://qiita.com/Sunmax0731/private/cd90b674fe33b530c6bf)」でした！<br/>
明日の記事はオークマネコさんの「」です。

# はじめに

皆さんこんにちは～！ バーチャルHigh Performance C#erのスーギ・ノウコ自治区です。

きっとこの記事を読む皆さんは[巻乃もなか氏](https://twitter.com/monaka_0_0_7)のことが大好きなのですよね？<br/>
そして皆さんがUnityエンジニアであるならば、ビルドが失敗した時とかに「たすけて！もなふわすい～とる～む！！」とTwitterに書き込んだ経験があるはずです。<br/>
周囲に人がいなかったならば声に出していた人もいるでしょう。

この記事は私がもなふわすい～とる～むに助けを求めた事例について記載しています。<br/>
巻乃もなか氏についての魅力を語りつくす類の記事ではないことをご了承ください。

大体ここに書いた内容はSHOWROOM社のエンジニアにとっては常識らしいのですごいですね。

# これを読む際の理解を助けるもなふわな記事たち

最初にこの記事を読むに当たって理解の助けになると思われる記事を列挙します。<br/>
この記事内でも都度解説を行う予定ですが、最初に読んでおくといいかもしれません。

## もなふわすい～とる～む

- [巻乃もなか氏のTwitter](https://twitter.com/monaka_0_0_7)

## 計算機科学

- [参照局所性](https://ja.wikipedia.org/wiki/%E5%8F%82%E7%85%A7%E3%81%AE%E5%B1%80%E6%89%80%E6%80%A7)

## SIMDプログラミング

### 総論・基礎

- [Array of Struct of Arrayについてわかっている人にとってはわかりやすい解説サイト](https://www.isus.jp/hpc/memory-layout/)
- [IntelのSingle Instruction Multiple Dataに関する命令をまとめた良いサイト](https://www.officedaytime.com/tips/simd.html)
- [Intel interinsics公式解説サイト](https://software.intel.com/sites/landingpage/IntrinsicsGuide/)

### C#におけるSIMDプログラミング

- [.NET Core Hardware Intrinsicsに関するufcpp.netのページ](https://ufcpp.net/blog/2018/12/hdintrinsic/)

### UnityにおけるSIMDプログラミング

- [C#×LLVM=アセンブラ！？　〜詳説・Burstコンパイラー〜](https://www.slideshare.net/UnityTechnologiesJapan002/cllvmburst-188106750)
- [BurstCompilerによる高速化の実例](https://learning.unity3d.jp/4968/)
- [Unity BurstCompiler User Guides](https://docs.unity3d.com/Packages/com.unity.burst@1.4/manual/index.html)

## C# Source Generator

- [イントロ](https://devblogs.microsoft.com/dotnet/introducing-c-source-generators/)
- [例](https://devblogs.microsoft.com/dotnet/new-c-source-generator-samples/)

## Roslynによる構文解析

- [MSDocsの公式API記述](https://docs.microsoft.com/ja-jp/dotnet/api/microsoft.codeanalysis.csharp?view=roslyn-dotnet)
- [MSDocsのHow to use](https://docs.microsoft.com/ja-jp/dotnet/csharp/roslyn-sdk/)

# 執筆者環境

筆者は随時バージョンアップしています。

- Unity 2020.2.0b13
- Burst 1.4.1
- Visual Studio 2019 16.8.1
- .NET 5.0.100

# Single Instruction Multiple Data

## 伝統的なオブジェクト指向設計

一部のゲームジャンル（STG、RTS）ではよく似た計算式を大量のオブジェクトに適用する類の計算を行います。

例えば敵(Enemy)が1万体出て来てそれをひたすら撃ち落とすというシューティングゲームがあるとします。<br/>
普通のオブジェクト指向で敵と弾丸をモデリングして書いてみると多分次のような記述になるのではないでしょうか。

<details><summary>モデル.cs</summary><div>

```csharp
public interface IPosition2D
{
    float X { get; set; }
    float Y { get; set; }
}

public interface ISizeCalculatable
{
    float Size { get; }
}

public interface IMortal
{
    void Die();
}

public abstract class ObjectiveEnemy : IPosition2D, ISizeCalculatable, IMortal
{
    public abstract float X { get; set; }
    public abstract float Y { get; set; }
    public abstract float Size { get; }

    /* 他にもいっぱいメンバがいます */

    public abstract void Die();
}

public abstract class ObjectiveBullet : IPosition2D, ISizeCalculatable, IMortal
{
    public abstract float X { get; set; }
    public abstract float Y { get; set; }
    public abstract float Size { get; }

    /* 他にもいっぱいメンバがいます */

    public abstract void Die();
}

public interface ICollisionProcessor
{
}

public interface ICollisionProcessor<T0, T1> : ICollisionProcessor
{
    void ProcessCollision(T0 item0, T1 item1);
}
```

</div></details>

そしてObjectiveEnemyとObjectiveBulletの衝突判定はおそらくこうなるでしょう。

<details><summary>衝突判定.cs</summary><div>

```csharp
// IEnumerable<ObjectiveEnemy> enemyCollection;
// IEnumerable<ObjectiveBullet> bulletCollection;
// IEnumerable<ICollisionProcessor> processors;
foreach (ObjectiveEnemy enemy in enemyCollection)
{
    foreach (ObjectiveBullet bullet in bulletCollection)
    {
        float diffX = enemy.X - bullet.X;
        float diffY = enemy.Y - bullet.Y;
        float distanceSquared = diffX * diffX + diffY * diffY;
        float collisionRadius = enemy.Size + bullet.Size;
        bool isCollided = distanceSquared <= collisionRadius * collisionRadius;
        if (isCollided)
        {
            foreach (ICollisionProcessor processor in processors)
            {
                if (processor is ICollisionProcessor<ObjectiveEnemy, ObjectiveBullet> enemyBulletProcessor)
                {
                    enemyBulletProcessor.ProcessCollision(enemy, bullet);
                }
            }
        }
    }
}

public sealed class CollisionKiller : ICollisionProcessor<ObjectiveEnemy, ObjectiveBullet>
{
    public void ProcessCollision(ObjectiveEnemy item0, ObjectiveBullet item1)
    {
        item0?.Die();
        item1?.Die();
    }
}
```

</div></details>

この設計で特に問題はないと考える人は多いはずです。<br/>
**実際問題になることはまずありません。**

## Data Oriented Technology Stack(DOTS)で速くする

**しかし弾丸が数万、敵が数十万だったならば？**<br/>
前述のコードでは遅すぎますね……。<br/>
Unity ECS的にコードを書き直すと以下のような記述となります。<br/>
型については名前空間を含めて完全な名前を書いていますのでわからないものについては検索してください。

<details><summary>モデル.cs</summary><div>

```csharp
public struct Position2D : Unity.Entities.IComponentData
{
    public float X;
    public float Y;
}

public struct Size : Unity.Entities.IComponentData
{
    public float Value;
}

public struct AliveState : Unity.Entities.IComponentData
{
    public bool Value;
}
```

</div></details>

<details><summary>衝突判定用IJob.cs</summary><div>

```csharp
[Unity.Burst.BurstCompile]
public struct EnemyBulletCollisionJob : Unity.Jobs.IJob
{
    public Unity.Collections.NativeArray<Position2D> EnemyPositionArray;
    public Unity.Collections.NativeArray<Size> EnemySizeArray;
    public Unity.Collections.NativeArray<AliveState> EnemyAliveStateArray;
    public Unity.Collections.NativeArray<Position2D> BulletPositionArray;
    public Unity.Collections.NativeArray<Size> BulletSizeArray;
    public Unity.Collections.NativeArray<AliveState> BulletAliveStateArray;

    public void Execute()
    {
        for (int enemyIndex = 0; enemyIndex < EnemyPositionArray.Length; enemyIndex++)
        {
            AliveState enemyAliveState = EnemyAliveStateArray[enemyIndex];
            if (!enemyAliveState.Value) continue;

            Position2D enemyPosition = EnemyPositionArray[enemyIndex];
            Size enemySize = EnemySizeArray[enemyIndex];
            for (int bulletIndex = 0; bulletIndex < BulletPositionArray.Length; bulletIndex++)
            {
                AliveState bulletAliveState = BulletAliveStateArray[bulletIndex];
                if (!bulletAliveState.Value) continue;

                Position2D bulletPosition = BulletPositionArray[bulletIndex];
                Size bulletSize = BulletSizeArray[bulletIndex];

                float diffX = enemyPosition.X - bulletPosition.X;
                float diffY = enemyPosition.Y - bulletPosition.Y;
                float distanceSquared = diffX * diffX + diffY * diffY;
                float collisionRadius = enemy.Size + bullet.Size;
                bool isNotCollided = distanceSquared > collisionRadius * collisionRadius;
                if (isNotCollided) continue;

                BulletAliveStateArray[bulletIndex] = new AliveState() { Value = false };
                enemyAliveState.Value = false;
            }

            EnemyAliveStateArray[enemyIndex] = enemyAliveState;
        }
    }
}
```

</div></details>

なぜこれが速くなるのでしょうか？<br/>
[参照の空間的局所性](https://ja.wikipedia.org/wiki/%E5%8F%82%E7%85%A7%E3%81%AE%E5%B1%80%E6%89%80%E6%80%A7)がかなり高まっているからです。<br/>
`Unity.Collections.NativeArray<Position2D>`が示すようにx座標とy座標がペアになってメモリ上に一列にぎっちりと並んでいますね。<br/>
このため弾丸と敵との距離を計算するのが楽になっています。

衝突判定も結構甘めになっています。<br/>
しかし、弾丸が複数の敵に同時に当たるということはあまり考えにくいので特に問題にはならないと思います。

## もっともっと速くしたい

８つのデータをひとまとめにしましょう。

現代で一般的なSIMDには128bit幅SIMDと256bit幅SIMDという種別が存在します。<br/>
ARM系CPUでは128bit幅が主流です。x86/64系は32bitCPUなら128bit幅、64bitCPUなら256bit幅が標準的にサポートされています。

私はx64系CPUでWindowsで動作するプログラムを主にターゲットにしていますので8つ組のモデルを作ることにします。<br/>
ARMのみの場合４つ組を使う方が素直でしょうね。

<details><summary>モデル.cs</summary><div>

```csharp
public struct AliveStateEight
{
    public Unity.Mathematics.int4x2 Value;

    public enum AliveState
    {
        Alive = 0,
        Dead = -1,
    }

    public unsafe void Rotate()
    {
        fixed (void* pointer = &Value)
        {
            int temp = Value.c0.x;
            Unity.Collections.LowLevel.Unsafe.UnsafeUtility.MemMove(destination: pointer, source: (float*)pointer + 1, size: sizeof(float) * 7);
            Value.c1.w = temp;
        }
    }
}

public struct Position2DEight
{
    public Unity.Mathematics.float4x2 X;
    public Unity.Mathematics.float4x2 Y;

    public unsafe void Rotate()
    {
        fixed (void* pointer = &X)
        {
            float temp = X.c0.x;
            Unity.Collections.LowLevel.Unsafe.UnsafeUtility.MemMove(destination: pointer, source: (float*)pointer + 1, size: sizeof(float) * 7);
            X.c1.w = temp;
        }

        fixed (void* pointer = &Y)
        {
            float temp = Y.c0.x;
            Unity.Collections.LowLevel.Unsafe.UnsafeUtility.MemMove(destination: pointer, source: (float*)pointer + 1, size: sizeof(float) * 7);
            Y.c1.w = temp;
        }
    }
}

public struct SizeEight
{
    public Unity.Mathematics.float4x2 Value;

    public unsafe void Rotate()
    {
        fixed (void* pointer = &Value)
        {
            float temp = Value.c0.x;
            Unity.Collections.LowLevel.Unsafe.UnsafeUtility.MemMove(destination: pointer, source: (float*)pointer + 1, size: sizeof(float) * 7);
            Value.c1.w = temp;
        }
    }
}
```

</div></details>

8つ組にするといいましたが、どうするのかというのも重要です。`Position2DEight`を御覧ください。

```csharp
public struct Position2DEight
{
    public Unity.Mathematics.float4x2 X;
    public Unity.Mathematics.float4x2 Y;
}
```

XとYがそれぞれ8つ組になっていますね？<br/>
これが大事なのです。
仮にXとYのペアを8つ組にしたら次のようなコードになるでしょう。

```csharp
public struct AnotherPosition2DEight
{
    public Unity.Mathematics.float2 XY0;
    public Unity.Mathematics.float2 XY1;
    public Unity.Mathematics.float2 XY2;
    public Unity.Mathematics.float2 XY3;
    public Unity.Mathematics.float2 XY4;
    public Unity.Mathematics.float2 XY5;
    public Unity.Mathematics.float2 XY6;
    public Unity.Mathematics.float2 XY7;
}
```

この`AnotherPosition2DEight`は効率的なSIMD演算を阻害します。特にXとY同士で計算しようとすると非常に非効率になります。<br/>
X座標はX座標と、Y座標はY座標とお付き合いするべきだと思いますわね。 ~~バ美肉エンジニアのねぎぽよしさんはizmさんとお付き合いするべき~~

x86/64系CPUでSIMDを使う際に注意してほしいことなのですけれども、**比較演算の結果のtrueは比較対象の型の幅の全bitが1になっています**。<br/>
故に`enum AliveState`はDeadが-1でAliveが0とすることで、それぞれ`true`と`false`に対応させているのですね。

比較演算でtrueなら全bit1となる仕様はx86/64系とARM系の両方で保証されています。RISC-Vとかはよくわかりませんが、Unity使用者なら気にせずともよいでしょう。

以下は衝突判定の実装部分です。<br/>
Unity.Burst.Intrinsicsを利用している記事では多分日本語では初かそうでなくても２番目なんじゃないですかね……？

<details><summary>長いソースコード</summary><div>

```csharp
[Unity.Burst.BurstCompile]
public struct EnemyBulletCollisionJob : Unity.Jobs.IJob
{
    public Unity.Collections.NativeArray<AliveStateEight> EnemyAliveStateArray;
    public Unity.Collections.NativeArray<Position2DEight> EnemyPositionArray;
    public Unity.Collections.NativeArray<SizeEight> EnemySizeArray;
    public Unity.Collections.NativeArray<AliveStateEight> BulletAliveStateArray;
    public Unity.Collections.NativeArray<Position2DEight> BulletPositionArray;
    public Unity.Collections.NativeArray<SizeEight> BulletSizeArray;

    public void Execute()
    {
        if (Unity.Burst.Intrinsics.X86.Fma.IsFmaSupported)
        {
            ExecuteFma();
        }
        else
        {
            ExecuteOrdinal();
        }
    }

    private unsafe void ExecuteFma()
    {
        Unity.Collections.NativeArray<Unity.Burst.Intrinsics.v256> enemyPositionArray = EnemyPositionArray.Reinterpret<Unity.Burst.Intrinsics.v256>(sizeof(Unity.Burst.Intrinsics.v256));
        Unity.Collections.NativeArray<Unity.Burst.Intrinsics.v256> bulletPositionArray = BulletPositionArray.Reinterpret<Unity.Burst.Intrinsics.v256>(sizeof(Unity.Burst.Intrinsics.v256));
        Unity.Collections.NativeArray<Unity.Burst.Intrinsics.v256> enemyAliveStateArray = EnemyAliveStateArray.Reinterpret<Unity.Burst.Intrinsics.v256>(sizeof(Unity.Burst.Intrinsics.v256));
        Unity.Collections.NativeArray<Unity.Burst.Intrinsics.v256> bulletAliveStateArray = BulletAliveStateArray.Reinterpret<Unity.Burst.Intrinsics.v256>(sizeof(Unity.Burst.Intrinsics.v256));
        Unity.Collections.NativeArray<Unity.Burst.Intrinsics.v256> enemySizeArray = EnemySizeArray.Reinterpret<Unity.Burst.Intrinsics.v256>(sizeof(Unity.Burst.Intrinsics.v256));
        Unity.Collections.NativeArray<Unity.Burst.Intrinsics.v256> bulletSizeArray = BulletSizeArray.Reinterpret<Unity.Burst.Intrinsics.v256>(sizeof(Unity.Burst.Intrinsics.v256));
        for (int enemyIndex = 0; enemyIndex < EnemyPositionArray.Length; enemyIndex++)
        {
            Unity.Burst.Intrinsics.v256 enemyAliveState = enemyAliveStateArray[enemyIndex];
            Unity.Burst.Intrinsics.v256 enemyPositionX = enemyPositionArray[(enemyIndex << 1)];
            Unity.Burst.Intrinsics.v256 enemyPositionY = enemyPositionArray[(enemyIndex << 1) + 1];
            Unity.Burst.Intrinsics.v256 enemySize = enemySizeArray[enemyIndex];

            for (int bulletIndex = 0; bulletIndex < BulletPositionArray.Length; bulletIndex++)
            {
                Unity.Burst.Intrinsics.v256 bulletAliveState = bulletAliveStateArray[bulletIndex];
                Unity.Burst.Intrinsics.v256 bulletPositionX = bulletPositionArray[(bulletIndex << 1)];
                Unity.Burst.Intrinsics.v256 bulletPositionY = bulletPositionArray[(bulletIndex << 1) + 1];
                Unity.Burst.Intrinsics.v256 bulletSize = bulletSizeArray[bulletIndex];

                for (int swapIndex = 0; swapIndex < 2; ++swapIndex, Swap(ref bulletAliveState), Swap(ref bulletPositionX), Swap(ref bulletPositionY), Swap(ref bulletSize))
                {
                    for (int rotateIndex = 0; rotateIndex < 4; ++rotateIndex, Rotate(ref bulletAliveState), Rotate(ref bulletPositionX), Rotate(ref bulletPositionY), Rotate(ref bulletSize))
                    {
                        // float diffX = enemy.X - bullet.X;
                        Unity.Burst.Intrinsics.v256 diffX = Unity.Burst.Intrinsics.Avx.mm256_sub_ps(enemyPositionX, bulletPositionX);
                        // float diffY = enemy.Y - bullet.Y;
                        Unity.Burst.Intrinsics.v256 diffY = Unity.Burst.Intrinsics.Avx.mm256_sub_ps(enemyPositionY, bulletPositionY);
                        // float distanceSquared = diffY * diffY + (diffX * diffX);
                        Unity.Burst.Intrinsics.v256 distanceSquared = Unity.Burst.Intrinsics.Fma.mm256_fmadd_ps(diffY, diffY, Unity.Burst.Intrinsics.Avx.mm256_mul_ps(diffX, diffX));
                        Unity.Burst.Intrinsics.v256 collisionRadius = Unity.Burst.Intrinsics.Avx.mm256_add_ps(enemySize, bulletSize);
                        Unity.Burst.Intrinsics.v256 collisionRadiusSquared = Unity.Burst.Intrinsics.Avx.mm256_mul_ps(collisionRadius, collisionRadius);
                        Unity.Burst.Intrinsics.v256 isCollided = Unity.Burst.Intrinsics.Avx.mm256_cmp_ps(distanceSquared, collisionRadiusSquared, (int)Unity.Burst.Intrinsics.Avx.CMP.LE_OQ);
                        // Deadが-1 == trueなのです
                        Unity.Burst.Intrinsics.v256 anyDead = Unity.Burst.Intrinsics.Avx.mm256_or_ps(enemyAliveState, bulletAliveState);
                        Unity.Burst.Intrinsics.v256 isValidCollision = Unity.Burst.Intrinsics.Avx.mm256_andnot_ps(anyDead, isCollided);
                        enemyAliveState = Unity.Burst.Intrinsics.Avx.mm256_or_ps(isValidCollision, enemyAliveState);
                        bulletAliveState = Unity.Burst.Intrinsics.Avx.mm256_or_ps(isValidCollision, bulletAliveState);
                    }
                }

                bulletAliveStateArray[bulletIndex] = bulletAliveState;
            }

            enemyAliveStateArray[enemyIndex] = enemyAliveState;
        }
    }

    private static void Swap(ref Unity.Burst.Intrinsics.v256 value)
    {
        value = Unity.Burst.Intrinsics.Avx2.mm256_permute2x128_si256(value, value, 0b0000_0001);
    }

    private static void Rotate(ref Unity.Burst.Intrinsics.v256 value)
    {
        value = Unity.Burst.Intrinsics.Avx2.mm256_permutevar8x32_ps(value, new v256(1, 2, 3, 0, 1, 2, 3, 0));
    }

    private void ExecuteOrdinal()
    {
        for (int enemyIndex = 0; enemyIndex < EnemyPositionArray.Length; enemyIndex++)
        {
            AliveStateEight enemyAliveState = EnemyAliveStateArray[enemyIndex];
            Position2DEight enemyPosition = EnemyPositionArray[enemyIndex];
            SizeEight enemySize = EnemySizeArray[enemyIndex];
            
            for (int bulletIndex = 0; bulletIndex < BulletPositionArray.Length; bulletIndex++)
            {
                AliveStateEight bulletAliveState = BulletAliveStateArray[bulletIndex];
                Position2DEight bulletPosition = BulletPositionArray[bulletIndex];
                SizeEight bulletSize = BulletSizeArray[bulletIndex];

                for (int rotateIndex = 0; rotateIndex < 8; ++rotateIndex, bulletAliveState.Rotate(), bulletPosition.Rotate(), bulletSize.Rotate())
                {
                    Unity.Mathematics.float4x2 diffX = enemyPosition.X - bulletPosition.X;
                    Unity.Mathematics.float4x2 diffY = enemyPosition.Y - bulletPosition.Y;
                    Unity.Mathematics.float4x2 distanceSquared = diffX * diffX + diffY * diffY;
                    Unity.Mathematics.float4x2 collisionRadius = enemy.Size + bullet.Size;
                    Unity.Mathematics.bool4x2 isCollided = distanceSquared <= collisionRadius * collisionRadius;
                    Unity.Mathematics.bool4x2 isBulletAlive = bulletAliveState.Value == default(int4x2);
                    Unity.Mathematics.bool4x2 isEnemyAlive = enemyAliveState.Value == default(int4x2);
                    Unity.Mathematics.bool4x2 isValidCollision = isBulletAlive & isEnemyAlive & isCollided;
                    bulletAliveState.Value.c0 = Unity.Mathematics.math.select(bulletAliveState.Value.c0, new int4(-1, -1, -1, -1), isValidCollision.c0);
                    bulletAliveState.Value.c1 = Unity.Mathematics.math.select(bulletAliveState.Value.c1, new int4(-1, -1, -1, -1), isValidCollision.c1);
                    enemyAliveState.Value.c0 = Unity.Mathematics.math.select(enemyAliveState.Value.c0, new int4(-1, -1, -1, -1), isValidCollision.c0);
                    enemyAliveState.Value.c1 = Unity.Mathematics.math.select(enemyAliveState.Value.c1, new int4(-1, -1, -1, -1), isValidCollision.c1);
                }

                BulletAliveStateArray[bulletIndex] = bulletAliveState;
            }

            EnemyAliveStateArray[enemyIndex] = enemyAliveState;
        }
    }
}
```

</div></details>

Burst Intrinsicsを使う際にはCPUがどの程度対応しているのかを把握することが重要です。<br/>
今回はAVX2のFma関数を利用しますので、`bool Unity.Burst.Intrinsics.Fma.IsFmaSupported`プロパティで場合分けをしました。

Fmaが動かない環境向けのフォールバックコードをきちんと用意しておく必要がありますので、総コード量は単純に倍以上になりがちです。


```csharp
Unity.Burst.Intrinsics.v256 diffX = Unity.Burst.Intrinsics.Avx.mm256_sub_ps(enemyPositionX, bulletPositionX);
Unity.Burst.Intrinsics.v256 diffY = Unity.Burst.Intrinsics.Avx.mm256_sub_ps(enemyPositionY, bulletPositionY);
Unity.Burst.Intrinsics.v256 distanceSquared = Unity.Burst.Intrinsics.Fma.mm256_fmadd_ps(diffY, diffY, Unity.Burst.Intrinsics.Avx.mm256_mul_ps(diffX, diffX));
```

~~ここが`AnotherPosition2DEight`と`Position2DEight`の差別化ポイントでしょうね。<br/>~~
考えたら`mm256_hadd_ps`とかあるので今回は差別化できなかったです……<br/>
Position3Dとかnot power of 2な構造なら今回のようにAOSOAにすると上手くいくって言いたいのです。<br/>
題材設定ミスってますね……　たすけて！もなふわすい～とる～む！！！

# C# Source Generatorでコーディングをらくちんにしよう！

`もっともっと速くしたい`のモデル部分の実装は非常に規則的に`DOTSで速くする`実装から生成可能です。<br/>
大した手間ではないっちゃないのですが、モデル部分を考える際はプリミティブ型で考えたいですよね。<br/>
そして、それに対応する８つ組の型を自動生成してほしいですよね？

Roslynバージョン3.6からはC# Source Generatorというものを使えばコンパイル時にソースコードを自動生成できるのです！<br/>
ついでにRoslyn 3.8はC#9も使えるのでぜひ使いましょう！<br/>
目下の所最大の問題はUnity2020.2はRoslyn 3.8を同梱していないということですが……。どうして3.5なの……？<br/>
たすけて！もなふわすい～とる～む！！

いやまあコンパイル時ソースコード自動生成は[従来からRoslynを利用してdotnet global toolで実現](https://github.com/neuecc/MessagePack-CSharp)とか出来ていましたが……。<br/>
C# Source Generator触っているうちにデバッグの利便性を考えるとコア部分を切り出した上で、まずはConsoleアプリとして構築し、それが上手く動いたらC# Source Generatorにした方が楽だという知見も得てしまって……。<br/>
更にエディタが重くなったり不安定になるとかいう副作用もあるので……。
たすけて！もなふわすい～とる～む！

実装すればするほどリアルタイムでソースコードが生成されるからエディタ体験がエラーで中断されない程度しか利用者に利点がないC# Source Generatorくんちゃん……<br/>

## 実現例

<details><summary>モデル部分</summary><div>

```csharp
[Eight]
public partial struct AliveState
{
    public State Value;

    public enum State
    {
        Alive,
        Dead = -1,
    }
}

[Eight]
public partial struct Size
{
    public float Value;
}

[Eight]
public partial struct Position2D
{
    public float X;
    public float Y;
}
```
</div></details>

<details><summary>衝突判定実装部分は以下の通りです。</summary><div>

```csharp
[CollisionType(
    new[] { typeof(Position2D), typeof(AliveState), typeof(Size) }, new[] { true, false, true }, "Enemy",
    new[] { typeof(Position2D), typeof(AliveState), typeof(Size) }, new[] { true, false, true }, "Bullet"
)]
public static partial class CollisionHolder
{
    [MethodIntrinsicsKind(IntrinsicsKind.Fma)]
    private static void Exe2(
        ref v256 enemyX, ref v256 enemyY, ref v256 enemyAliveState, ref v256 enemySize,
        ref v256 bulletX, ref v256 bulletY, ref v256 bulletAliveState, ref v256 bulletSize
    )
    {
        if (X86.Fma.IsFmaSupported)
        {
            var diffX = X86.Avx.mm256_sub_ps(enemyX, bulletX);
            var xSquare = X86.Avx.mm256_mul_ps(diffX, diffX);
            var diffY = X86.Avx.mm256_sub_ps(enemyY, bulletY);
            var lengthSquare = X86.Fma.mm256_fmadd_ps(diffY, diffY, xSquare);
            
            var radius = X86.Avx.mm256_add_ps(enemySize, bulletSize);
            var radiusSquare = X86.Avx.mm256_mul_ps(radius, radius);
            var cmp = X86.Avx.mm256_cmp_ps(lengthSquare, radiusSquare, (int)X86.Avx.CMP.LT_OQ);
            
            var hit = X86.Avx.mm256_andnot_ps(X86.Avx.mm256_or_ps(enemyAliveState, bulletAliveState), cmp);
            enemyAliveState = X86.Avx.mm256_or_ps(enemyAliveState, hit);
            bulletAliveState = X86.Avx.mm256_or_ps(bulletAliveState, hit);
        }
    }

    [MethodIntrinsicsKind(IntrinsicsKind.Ordinal)]
    private static void Exe(
        ref float4 enemyX, ref float4 enemyY, ref int4 enemyAliveState, ref float4 enemySize,
        ref float4 bulletX, ref float4 bulletY, ref int4 bulletAliveState, ref float4 bulletSize
    )
    {
        var x0 = enemyX - bulletX;
        var y0 = enemyY - bulletY;
        var radius = enemySize + bulletSize;
        var cmp = enemyAliveState == 0 & bulletAliveState == 0 & x0 * x0 + y0 * y0 < radius * radius;
        enemyAliveState = math.select(enemyAliveState, -1, cmp);
        bulletAliveState = math.select(bulletAliveState, -1, cmp);
    }

    [CollisionCloseMethod(IntrinsicsKind.Ordinal, 1, nameof(AliveState.Value))]
    private static int4 Close(int4 a0, int4 a1)
    {
        return (a0 | a1);
    }

    [CollisionCloseMethod(IntrinsicsKind.Fma, 1, nameof(AliveState.Value))]
    private static v256 Close2(v256 a0, v256 a1)
    {
        if (X86.Fma.IsFmaSupported)
        {
            return X86.Avx.mm256_or_ps(a0, a1);
        }
        else
        {
            throw new NotSupportedException();
        }
    }
}
```
</div></details>

記述がふわっとスッキリした感じがありませんか？<br/>
定型的な記述を少なくし、本質的な部分にのみ注力できるようになっていますね？

<details><summary>上のコードからこのような衝突判定用二重ループコードが自動生成されています。</summary><div>

```csharp
static partial class  CollisionHolder
{
    [global::Unity.Burst.BurstCompile]
    public unsafe partial struct Job : global::Unity.Jobs.IJob
    {
        [global::Unity.Collections.ReadOnly] public global::Unity.Collections.NativeArray<ComponentTypes.Position2D.Eight> EnemyPosition2D;
        public global::Unity.Collections.NativeArray<ComponentTypes.AliveState.Eight> EnemyAliveState;
        [global::Unity.Collections.ReadOnly] public global::Unity.Collections.NativeArray<ComponentTypes.Size.Eight> EnemySize;
        [global::Unity.Collections.ReadOnly] public global::Unity.Collections.NativeArray<ComponentTypes.Position2D.Eight> BulletPosition2D;
        public global::Unity.Collections.NativeArray<ComponentTypes.AliveState.Eight> BulletAliveState;
        [global::Unity.Collections.ReadOnly] public global::Unity.Collections.NativeArray<ComponentTypes.Size.Eight> BulletSize;

        public void Execute()
        {
            if (global::Unity.Burst.Intrinsics.X86.Fma.IsFmaSupported)
            {
                const int next1 = 0b00_11_10_01;
                const int next2 = 0b01_00_11_10;
                const int next3 = 0b10_01_00_11;

                var outerPointer0 = (byte*)global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(EnemyPosition2D);
                var outerPointer1 = (byte*)global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(EnemyAliveState);
                var outerPointer2 = (byte*)global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(EnemySize);
                var innerOriginalPointer0 = (byte*)global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(BulletPosition2D);
                var innerOriginalPointer1 = (byte*)global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(BulletAliveState);
                var innerOriginalPointer2 = (byte*)global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(BulletSize);

                for (
                    var outerIndex = 0;
                    outerIndex < EnemyPosition2D.Length;
                    ++outerIndex,
                    outerPointer0 += sizeof(ComponentTypes.Position2D.Eight),
                    outerPointer1 += sizeof(ComponentTypes.AliveState.Eight),
                    outerPointer2 += sizeof(ComponentTypes.Size.Eight)
                )
                {
                    var outer0_X = outerPointer0 + (0 << 5);
                    var outer0_Y = outerPointer0 + (1 << 5);
                    var outer1_Value = outerPointer1 + (0 << 5);
                    var outer2_Value = outerPointer2 + (0 << 5);

                    var outer0_X0 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(outer0_X);
                    var outer0_Y0 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(outer0_Y);
                    var outer1_Value0 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(outer1_Value);
                    var outer2_Value0 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(outer2_Value);

                    var outer0_X1 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_X0, next1);
                    var outer0_Y1 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_Y0, next1);
                    var outer1_Value1 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value0, next1);
                    var outer2_Value1 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer2_Value0, next1);
                    var outer0_X2 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_X0, next2);
                    var outer0_Y2 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_Y0, next2);
                    var outer1_Value2 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value0, next2);
                    var outer2_Value2 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer2_Value0, next2);
                    var outer0_X3 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_X0, next3);
                    var outer0_Y3 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_Y0, next3);
                    var outer1_Value3 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value0, next3);
                    var outer2_Value3 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer2_Value0, next3);

                    var outer0_X4 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer0_X0, outer0_X0, 0b0000_0001);
                    var outer0_Y4 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer0_Y0, outer0_Y0, 0b0000_0001);
                    var outer1_Value4 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer1_Value0, outer1_Value0, 0b0000_0001);
                    var outer2_Value4 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer2_Value0, outer2_Value0, 0b0000_0001);

                    var outer0_X5 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_X4, next1);
                    var outer0_Y5 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_Y4, next1);
                    var outer1_Value5 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value4, next1);
                    var outer2_Value5 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer2_Value4, next1);
                    var outer0_X6 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_X4, next2);
                    var outer0_Y6 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_Y4, next2);
                    var outer1_Value6 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value4, next2);
                    var outer2_Value6 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer2_Value4, next2);
                    var outer0_X7 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_X4, next3);
                    var outer0_Y7 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer0_Y4, next3);
                    var outer1_Value7 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value4, next3);
                    var outer2_Value7 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer2_Value4, next3);

                    var innerPointer0 = innerOriginalPointer0;
                    var innerPointer1 = innerOriginalPointer1;
                    var innerPointer2 = innerOriginalPointer2;
                    for (
                        var innerIndex = 0;
                        innerIndex < BulletPosition2D.Length;
                        ++innerIndex,
                        innerPointer0 += sizeof(ComponentTypes.Position2D.Eight),
                        innerPointer1 += sizeof(ComponentTypes.AliveState.Eight),
                        innerPointer2 += sizeof(ComponentTypes.Size.Eight)
                    )
                    {
                        var inner0_X = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(innerPointer0 + (0 << 5));
                        var inner0_Y = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(innerPointer0 + (1 << 5));
                        var inner1_Value = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(innerPointer1 + (0 << 5));
                        var inner2_Value = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(innerPointer2 + (0 << 5));

                        Exe2(ref outer0_X0, ref outer0_Y0, ref outer1_Value0, ref outer2_Value0, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        Exe2(ref outer0_X1, ref outer0_Y1, ref outer1_Value1, ref outer2_Value1, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        Exe2(ref outer0_X2, ref outer0_Y2, ref outer1_Value2, ref outer2_Value2, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        Exe2(ref outer0_X3, ref outer0_Y3, ref outer1_Value3, ref outer2_Value3, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        Exe2(ref outer0_X4, ref outer0_Y4, ref outer1_Value4, ref outer2_Value4, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        Exe2(ref outer0_X5, ref outer0_Y5, ref outer1_Value5, ref outer2_Value5, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        Exe2(ref outer0_X6, ref outer0_Y6, ref outer1_Value6, ref outer2_Value6, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        Exe2(ref outer0_X7, ref outer0_Y7, ref outer1_Value7, ref outer2_Value7, ref inner0_X, ref inner0_Y, ref inner1_Value, ref inner2_Value);
                        global::Unity.Burst.Intrinsics.X86.Avx.mm256_store_ps(innerPointer1 + (0 << 5), inner1_Value);
                    }

                    outer1_Value0 = Close2(outer1_Value0, global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer1_Value4, outer1_Value4, 0b0000_0001));
                    outer1_Value1 = Close2(outer1_Value1, global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer1_Value5, outer1_Value5, 0b0000_0001));
                    outer1_Value2 = Close2(outer1_Value2, global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer1_Value6, outer1_Value6, 0b0000_0001));
                    outer1_Value3 = Close2(outer1_Value3, global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute2f128_ps(outer1_Value7, outer1_Value7, 0b0000_0001));
                    outer1_Value1 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value1, 0b10_01_00_11);
                    outer1_Value2 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value2, 0b01_00_11_10);
                    outer1_Value3 = global::Unity.Burst.Intrinsics.X86.Avx.mm256_permute_ps(outer1_Value3, 0b00_11_10_01);
                    global::Unity.Burst.Intrinsics.X86.Avx.mm256_store_ps(outer1_Value, Close2(Close2(outer1_Value0, outer1_Value1), Close2(outer1_Value2, outer1_Value3)));
                }
                return;
            }

            {
                for (var outerIndex = 0; outerIndex < EnemyPosition2D.Length; ++outerIndex)
                {
                    var outer0 = EnemyPosition2D[outerIndex];
                    var outer1 = EnemyAliveState[outerIndex];
                    var outer2 = EnemySize[outerIndex];
                    ref var outer0_X0 = ref outer0.X;
                    ref var outer0_X0_c0 = ref outer0_X0.c0;
                    var outer0_X1_c0 = outer0_X0.c0.wxyz;
                    var outer0_X2_c0 = outer0_X0.c0.zwxy;
                    var outer0_X3_c0 = outer0_X0.c0.yzwx;
                    ref var outer0_X0_c1 = ref outer0_X0.c1;
                    var outer0_X1_c1 = outer0_X0_c1.wxyz;
                    var outer0_X2_c1 = outer0_X0_c1.zwxy;
                    var outer0_X3_c1 = outer0_X0_c1.yzwx;
                    ref var outer0_Y0 = ref outer0.Y;
                    ref var outer0_Y0_c0 = ref outer0_Y0.c0;
                    var outer0_Y1_c0 = outer0_Y0.c0.wxyz;
                    var outer0_Y2_c0 = outer0_Y0.c0.zwxy;
                    var outer0_Y3_c0 = outer0_Y0.c0.yzwx;
                    ref var outer0_Y0_c1 = ref outer0_Y0.c1;
                    var outer0_Y1_c1 = outer0_Y0_c1.wxyz;
                    var outer0_Y2_c1 = outer0_Y0_c1.zwxy;
                    var outer0_Y3_c1 = outer0_Y0_c1.yzwx;
                    ref var outer1_Value0 = ref outer1.Value;
                    ref var outer1_Value0_c0 = ref outer1_Value0.c0;
                    var outer1_Value1_c0 = outer1_Value0.c0.wxyz;
                    var outer1_Value2_c0 = outer1_Value0.c0.zwxy;
                    var outer1_Value3_c0 = outer1_Value0.c0.yzwx;
                    ref var outer1_Value0_c1 = ref outer1_Value0.c1;
                    var outer1_Value1_c1 = outer1_Value0_c1.wxyz;
                    var outer1_Value2_c1 = outer1_Value0_c1.zwxy;
                    var outer1_Value3_c1 = outer1_Value0_c1.yzwx;
                    ref var outer2_Value0 = ref outer2.Value;
                    ref var outer2_Value0_c0 = ref outer2_Value0.c0;
                    var outer2_Value1_c0 = outer2_Value0.c0.wxyz;
                    var outer2_Value2_c0 = outer2_Value0.c0.zwxy;
                    var outer2_Value3_c0 = outer2_Value0.c0.yzwx;
                    ref var outer2_Value0_c1 = ref outer2_Value0.c1;
                    var outer2_Value1_c1 = outer2_Value0_c1.wxyz;
                    var outer2_Value2_c1 = outer2_Value0_c1.zwxy;
                    var outer2_Value3_c1 = outer2_Value0_c1.yzwx;
                    for (var innerIndex = 0; innerIndex < BulletPosition2D.Length; ++innerIndex)
                    {
                        var inner0 = BulletPosition2D[innerIndex];
                        var inner1 = BulletAliveState[innerIndex];
                        var inner2 = BulletSize[innerIndex];
                        ref var inner0_X = ref inner0.X;
                        ref var inner0_Y = ref inner0.Y;
                        ref var inner1_Value = ref inner1.Value;
                        ref var inner2_Value = ref inner2.Value;

                        Exe(ref outer0_X0_c0, ref outer0_Y0_c0, ref outer1_Value0_c0, ref outer2_Value0_c0, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X0_c0, ref outer0_Y0_c0, ref outer1_Value0_c0, ref outer2_Value0_c0, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        Exe(ref outer0_X0_c1, ref outer0_Y0_c1, ref outer1_Value0_c1, ref outer2_Value0_c1, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X0_c1, ref outer0_Y0_c1, ref outer1_Value0_c1, ref outer2_Value0_c1, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        Exe(ref outer0_X1_c0, ref outer0_Y1_c0, ref outer1_Value1_c0, ref outer2_Value1_c0, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X1_c0, ref outer0_Y1_c0, ref outer1_Value1_c0, ref outer2_Value1_c0, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        Exe(ref outer0_X1_c1, ref outer0_Y1_c1, ref outer1_Value1_c1, ref outer2_Value1_c1, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X1_c1, ref outer0_Y1_c1, ref outer1_Value1_c1, ref outer2_Value1_c1, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        Exe(ref outer0_X2_c0, ref outer0_Y2_c0, ref outer1_Value2_c0, ref outer2_Value2_c0, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X2_c0, ref outer0_Y2_c0, ref outer1_Value2_c0, ref outer2_Value2_c0, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        Exe(ref outer0_X2_c1, ref outer0_Y2_c1, ref outer1_Value2_c1, ref outer2_Value2_c1, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X2_c1, ref outer0_Y2_c1, ref outer1_Value2_c1, ref outer2_Value2_c1, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        Exe(ref outer0_X3_c0, ref outer0_Y3_c0, ref outer1_Value3_c0, ref outer2_Value3_c0, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X3_c0, ref outer0_Y3_c0, ref outer1_Value3_c0, ref outer2_Value3_c0, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        Exe(ref outer0_X3_c1, ref outer0_Y3_c1, ref outer1_Value3_c1, ref outer2_Value3_c1, ref inner0_X.c0, ref inner0_Y.c0, ref inner1_Value.c0, ref inner2_Value.c0);
                        Exe(ref outer0_X3_c1, ref outer0_Y3_c1, ref outer1_Value3_c1, ref outer2_Value3_c1, ref inner0_X.c1, ref inner0_Y.c1, ref inner1_Value.c1, ref inner2_Value.c1);
                        BulletAliveState[innerIndex] = inner1;
                    }

                    outer1_Value0.c0 = Close(Close(outer1_Value0.c0, outer1_Value1_c0.yzwx), Close(outer1_Value2_c0.zwxy, outer1_Value3_c0.wxyz));
                    outer1_Value0.c1 = Close(Close(outer1_Value0.c1, outer1_Value1_c1.yzwx), Close(outer1_Value2_c1.zwxy, outer1_Value3_c1.wxyz));
                    EnemyAliveState[outerIndex] = outer1;
                }
            }
        }
    }
}
```
</div></details>

高効率なボイラープレートコードを自動で生成してくれるのは大変ありがたいものだと私は思います。<br/>
以下のコードは最高効率からは少しだけ劣りますが、定型的なコードとしては最大限高速化されているものだと言えると思います。<br/>
これより速く効率の良いものが欲しいのであるならばもなな部長に「たすけて！」と求めるしか無いでしょう。巻乃さんなら作れます。

## 実際どの程度速いのか

今現在私が作り直しているシューティングゲームだとシェーダーも専用のそれに作り直していることもあり、10万ユニット位の移動でも60FPSを保てています。<br/>

# 如何にしてコードを生成するのか

コード生成するのにもかなりボイラープレートコードが必要でした。<br/>
特にRoslynを用いて属性の解釈を行う場合、コンストラクタ引数を相手にするのが一番手間が少ないのですが、それでも配列を相手にすると型の検証やらナニやらで大変面倒です……<br/>
何度「たすけて！もなふわすi～z～m！」を叫んだことでしょうか……

<details><summary>コード生成時に参照する属性.cs</summary><div>

```csharp
using System;
using Unity.Burst.Intrinsics;
using Unity.Mathematics;

namespace MyAttribute
{
    public enum IntrinsicsKind
    {
        Ordinal,
        Fma,
    }

    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct)]
    public class SingleLoopTypeAttribute : Attribute
    {
        public readonly Type[] TypeArray;
        public readonly bool[] IsReadOnlyArray;
        public readonly string NamePrefix;
        public readonly Type[] OtherTypeArray;
        public readonly bool[] OtherIsReadOnlyArray;
        public readonly string[] OtherNameArray;
        public readonly Type[] TableTypeArray;
        public readonly bool[] TableIsReadOnlyArray;
        public readonly string[] TableNameArray;

        public SingleLoopTypeAttribute(Type[] typeArray, bool[] isReadOnlyArray, string namePrefix) : this(typeArray, isReadOnlyArray, namePrefix, Array.Empty<Type>(), Array.Empty<bool>(), Array.Empty<string>()) { }

        public SingleLoopTypeAttribute(Type[] typeArray, bool[] isReadOnlyArray, string namePrefix, Type[] otherTypeArray, bool[] otherIsReadOnlyArray, string[] otherNameArray) : this(typeArray, isReadOnlyArray, namePrefix, otherTypeArray, otherIsReadOnlyArray, otherNameArray, Array.Empty<Type>(), Array.Empty<bool>(), Array.Empty<string>()) { }

        public SingleLoopTypeAttribute(Type[] typeArray, bool[] isReadOnlyArray, string namePrefix, Type[] otherTypeArray, bool[] otherIsReadOnlyArray, string[] otherNameArray, Type[] tableTypeArray, bool[] tableIsReadOnlyArray, string[] tableNameArray)
        {
            TypeArray = typeArray;
            IsReadOnlyArray = isReadOnlyArray;
            NamePrefix = namePrefix;
            OtherTypeArray = otherTypeArray;
            OtherIsReadOnlyArray = otherIsReadOnlyArray;
            OtherNameArray = otherNameArray;
            TableTypeArray = tableTypeArray;
            TableIsReadOnlyArray = tableIsReadOnlyArray;
            TableNameArray = tableNameArray;
        }
    }

    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Struct)]
    public class CollisionTypeAttribute : Attribute
    {
        public readonly Type[] OuterTypeArray;
        public readonly bool[] OuterIsReadOnlyArray;
        public readonly string OuterNamePrefix;
        public readonly Type[] InnerTypeArray;
        public readonly bool[] InnerIsReadOnlyArray;
        public readonly string InnerNamePrefix;
        public readonly Type[] OtherTypeArray;
        public readonly bool[] OtherIsReadOnlyArray;
        public readonly string[] OtherNameArray;
        public readonly Type[] TableTypeArray;
        public readonly bool[] TableIsReadOnlyArray;
        public readonly string[] TableNameArray;

        public CollisionTypeAttribute(Type[] outerTypeArray, bool[] outerIsReadOnlyArray, string outerNamePrefix, Type[] innerTypeArray, bool[] innerIsReadOnlyArray, string innerNamePrefix) : this(outerTypeArray, outerIsReadOnlyArray, outerNamePrefix, innerTypeArray, innerIsReadOnlyArray, innerNamePrefix, Array.Empty<Type>(), Array.Empty<bool>(), Array.Empty<string>()) { }

        public CollisionTypeAttribute(Type[] outerTypeArray, bool[] outerIsReadOnlyArray, string outerNamePrefix, Type[] innerTypeArray, bool[] innerIsReadOnlyArray, string innerNamePrefix, Type[] otherTypeArray, bool[] otherIsReadOnlyArray, string[] otherNameArray) : this(outerTypeArray, outerIsReadOnlyArray, outerNamePrefix, innerTypeArray, innerIsReadOnlyArray, innerNamePrefix, otherTypeArray, otherIsReadOnlyArray, otherNameArray, Array.Empty<Type>(), Array.Empty<bool>(), Array.Empty<string>()) { }

        public CollisionTypeAttribute(Type[] outerTypeArray, bool[] outerIsReadOnlyArray, string outerNamePrefix, Type[] innerTypeArray, bool[] innerIsReadOnlyArray, string innerNamePrefix, Type[] otherTypeArray, bool[] otherIsReadOnlyArray, string[] otherNameArray, Type[] tableTypeArray, bool[] tableIsReadOnlyArray, string[] tableNameArray)
        {
            OuterTypeArray = outerTypeArray;
            OuterIsReadOnlyArray = outerIsReadOnlyArray;
            OuterNamePrefix = outerNamePrefix;
            InnerTypeArray = innerTypeArray;
            InnerIsReadOnlyArray = innerIsReadOnlyArray;
            InnerNamePrefix = innerNamePrefix;
            OtherTypeArray = otherTypeArray;
            OtherIsReadOnlyArray = otherIsReadOnlyArray;
            OtherNameArray = otherNameArray;
            TableTypeArray = tableTypeArray;
            TableIsReadOnlyArray = tableIsReadOnlyArray;
            TableNameArray = tableNameArray;
        }
    }

    [AttributeUsage(AttributeTargets.Method)]
    public class MethodIntrinsicsKindAttribute : Attribute
    {
        public readonly IntrinsicsKind Intrinsics;

        public MethodIntrinsicsKindAttribute(IntrinsicsKind intrinsics)
        {
            Intrinsics = intrinsics;
        }
    }

    [AttributeUsage(AttributeTargets.Method)]
    public class CollisionCloseMethodAttribute : Attribute
    {
        public readonly IntrinsicsKind Intrinsics;
        public readonly int FieldIndex;
        public readonly string FieldName;

        public CollisionCloseMethodAttribute(IntrinsicsKind intrinsics, int fieldIndex, string fieldName)
        {
            Intrinsics = intrinsics;
            FieldIndex = fieldIndex;
            FieldName = fieldName;
        }
    }

    public class EightAttribute : Attribute { }

    public class CountableAttribute : Attribute { }
}
```
</div></details>

万が一リフレクションしたいという場合に備えて一応記述しておりますが、C# Source Generatorから使用する分に限ればフィールド定義も不要で、コンストラクタの内部の記述も不要な可能性はあります。<br/>

<details><summary>アナライザーコード本体.cs</summary><div>

```csharp
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Text;
using System.Collections.Generic;
using System.Text;
using MyAnalyzer.Templates;

namespace MyAnalyzer
{
    [Generator]
    public class MyGenerator : ISourceGenerator
    {
        public void Initialize(GeneratorInitializationContext context)
        {
            // System.Diagnostics.Debugger.Launch();
            context.RegisterForSyntaxNotifications(() => new SyntaxReceiver());
        }

        public void Execute(GeneratorExecutionContext context)
        {
            if (!(context.SyntaxReceiver is SyntaxReceiver receiver))
            {
                return;
            }

            var buffer = new StringBuilder();
            ExtractTypeSymbols(receiver, context.Compilation, out var eightBaseTypes, out var countableBaseTypes, out var collisionTemplates, out var singleLoopTemplates);

            foreach (var namedTypeSymbol in eightBaseTypes)
            {
                var template = new EightTemplate(namedTypeSymbol);
                buffer.AppendLine(template.TransformText());
            }
            
            foreach (var (namedTypeSymbol, attributeData) in countableBaseTypes)
            {
                var template = new CountableTemplate(namedTypeSymbol, attributeData);
                buffer.AppendLine(template.TransformText());
            }

            collisionTemplates.ForEach(template => buffer.AppendLine(template.TransformText()));
            singleLoopTemplates.ForEach(template => buffer.AppendLine(template.TransformText()));

            var encoding = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);
            var text = buffer.ToString();
            context.AddSource("MyAnalyzerResult.cs", SourceText.From(text, encoding));
        }

        private static void ExtractTypeSymbols(SyntaxReceiver receiver, Compilation compilation, out List<INamedTypeSymbol> eightBaseTypes, out List<(INamedTypeSymbol, AttributeData)> countableBaseTypes, out List<CollisionTemplate> collisionTemplates, out List<SingleLoopTemplate> singleLoopTemplates)
        {
            var eight = compilation.GetTypeByMetadataName("MyAttribute.EightAttribute") ?? throw new System.NullReferenceException();
            var countable = compilation.GetTypeByMetadataName("MyAttribute.CountableAttribute") ?? throw new System.NullReferenceException();
            var collisionType = compilation.GetTypeByMetadataName("MyAttribute.CollisionTypeAttribute") ?? throw new System.NullReferenceException();
            var intrinsicsKindMethod = compilation.GetTypeByMetadataName("MyAttribute.MethodIntrinsicsKindAttribute") ?? throw new System.NullReferenceException();
            var collisionCloseMethod = compilation.GetTypeByMetadataName("MyAttribute.CollisionCloseMethodAttribute") ?? throw new System.NullReferenceException();
            var loopType = compilation.GetTypeByMetadataName("MyAttribute.SingleLoopTypeAttribute") ?? throw new System.NullReferenceException();

            var candidateTypesCount = receiver.CandidateTypes.Count;
            eightBaseTypes = new(candidateTypesCount);
            countableBaseTypes = new(candidateTypesCount);
            collisionTemplates = new(candidateTypesCount);
            singleLoopTemplates = new(candidateTypesCount);
            foreach (var candidate in receiver.CandidateTypes)
            {
                var model = compilation.GetSemanticModel(candidate.SyntaxTree);
                var type = model.GetDeclaredSymbol(candidate);
                if (type is null)
                {
                    continue;
                }

                if (type.IsUnmanagedType)
                {
                    foreach (var attributeData in type.GetAttributes())
                    {
                        var attributeClass = attributeData.AttributeClass;
                        if (attributeClass is null)
                        {
                            continue;
                        }

                        if (SymbolEqualityComparer.Default.Equals(attributeClass, eight))
                        {
                            eightBaseTypes.Add(type);
                            break;
                        }

                        if (SymbolEqualityComparer.Default.Equals(attributeClass, countable))
                        {
                            countableBaseTypes.Add((type, attributeData));
                            break;
                        }
                    }
                }
                else
                {
                    {
                        var template = CollisionTemplate.TryCreate(collisionType, intrinsicsKindMethod, collisionCloseMethod, type);
                        if (template is not null)
                        {
                            collisionTemplates.Add(template);
                        }
                    }
                    {
                        var template = SingleLoopTemplate.TryCreate(loopType, intrinsicsKindMethod, type);
                        if (template is not null)
                        {
                            singleLoopTemplates.Add(template);
                        }
                    }
                }
            }
        }
    }

    internal class SyntaxReceiver : ISyntaxReceiver
    {
        public List<TypeDeclarationSyntax> CandidateTypes { get; } = new();

        public void OnVisitSyntaxNode(SyntaxNode syntaxNode)
        {
            if (!(syntaxNode is TypeDeclarationSyntax typeDeclarationSyntax)
                || typeDeclarationSyntax.AttributeLists.Count <= 0)
            {
                return;
            }

            foreach (var modifier in typeDeclarationSyntax.Modifiers)
            {
                if (modifier.Text != "partial")
                {
                    continue;
                }

                CandidateTypes.Add(typeDeclarationSyntax);
                return;
            }
        }
    }
}
```
</div></details>

`Initializeで`SyntaxReceiver`というものを登録します。<br/>
これはC#の[構文木](https://ja.wikipedia.org/wiki/%E6%8A%BD%E8%B1%A1%E6%A7%8B%E6%96%87%E6%9C%A8)の各ノードを走査するものです。<br/>
走査中に条件を満足する候補Nodeをリストに収録するという使い方が標準的でしょう。<br/>
私は実際設計原則にこだわるのはあほらしいと思いますが、しかし、このVisitorパターンではNodeの具体的な型を調べなくてはなりません。<br/>
ポリモーフィズムに真っ向から喧嘩を売っていますね。「たすけて！もなふわすい～とる～む！」

今回のコード生成では対象の型の中にネストされた特別な型を生成します。<br/>
そのため`partial`修飾子が指定されている型のみをスクリーニングしました。

その後`void Execute(GeneratorExecutionContext context)`メソッドが実行されます。<br/>
なぜ`Initialize`と`Execute`が分離しているのか、その詳細な理由はMDCのSHOWROOM社員のゴリラ氏がご存知でしょう。

`Execute`内では`ExtractTypeSymbols(receiver, context.Compilation, out var eightBaseTypes, out var countableBaseTypes, out var collisionTemplates, out var singleLoopTemplates);`を呼び出しています。<br/>
SyntaxReceiverが雑に収集した候補の型をここで精査します。

```csharp
var eight = compilation.GetTypeByMetadataName("MyAttribute.EightAttribute") ?? throw new System.NullReferenceException();
var countable = compilation.GetTypeByMetadataName("MyAttribute.CountableAttribute") ?? throw new System.NullReferenceException();
var collisionType = compilation.GetTypeByMetadataName("MyAttribute.CollisionTypeAttribute") ?? throw new System.NullReferenceException();
var intrinsicsKindMethod = compilation.GetTypeByMetadataName("MyAttribute.MethodIntrinsicsKindAttribute") ?? throw new System.NullReferenceException();
var collisionCloseMethod = compilation.GetTypeByMetadataName("MyAttribute.CollisionCloseMethodAttribute") ?? throw new System.NullReferenceException();
var loopType = compilation.GetTypeByMetadataName("MyAttribute.SingleLoopTypeAttribute") ?? throw new System.NullReferenceException();
```

まず最初に属性を用意します。<br/>
処理対象のUnityプロジェクトに型がきちんとリンクされていない場合`null`になるのでぬるりと死にます。

```csharp
var model = compilation.GetSemanticModel(candidate.SyntaxTree);
var type = model.GetDeclaredSymbol(candidate);
if (type is null)
{
    continue;
}
```

実際対象の型を表すSyntaxNodeから型の諸々具体的な情報を得たいと思います。<br/>
よくわからないのですが、セマンティックモデルを取得してから型のSymbolを得る必要がありました。


```csharp
if (type.IsUnmanagedType)
{
    foreach (var attributeData in type.GetAttributes())
    {
        var attributeClass = attributeData.AttributeClass;
        if (attributeClass is null)
        {
            continue;
        }
```

`NamedTypeSymbol`に対してC#7.3から導入された`unmanaged`制約を満たすかどうかを`IsUnmanagedType`プロパティで調べ、その真偽に応じて処理を振り分けます。<br/>
unamangedな構造体であるならばその型に付与された属性を列挙して検査します。

```csharp
if (SymbolEqualityComparer.Default.Equals(attributeClass, eight))
{
    eightBaseTypes.Add(type);
    break;
}
```

属性型シンボルの等値性比較は`==`演算子では不正確です。<br/>
これを知らず、もなふわすい～とる～むにたすけを求めたこともありました。<br/>
`SymbolEqualityComparer`クラスこそが巻乃もなかさんの齎した福音であり、救済です。<br/>
`Default`と`IncludeNullability`の２つのメンバーが生えていますが、基本的に前者を利用して等値性比較をしていきます。(後者はC#8から導入されたnullable reference type用アノテーションまで考慮した等値性比較を行います。)

```csharp
var template = SingleLoopTemplate.TryCreate(loopType, intrinsicsKindMethod, type);
if (template is not null)
{
    singleLoopTemplates.Add(template);
}
```

そして候補を元にT4のランタイムテキストテンプレートクラスオブジェクトを`TryCreate`で作成します。

<details><summary>ちなみにアナライザ―のcsprojはこの通りです。</summary><div>

かなりT4に依存していることがわかります。

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
	  <LangVersion>9.0</LangVersion>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.CodeAnalysis.CSharp.Workspaces" Version="3.8.0" />
    <PackageReference Include="System.CodeDom" Version="4.7.0" />
  </ItemGroup>

  <ItemGroup>
    <None Update="Templates\CollisionTemplate.tt">
      <Generator>TextTemplatingFilePreprocessor</Generator>
      <LastGenOutput>CollisionTemplate.cs</LastGenOutput>
    </None>
    <None Update="Templates\CountableTemplate.tt">
      <Generator>TextTemplatingFilePreprocessor</Generator>
      <LastGenOutput>CountableTemplate.cs</LastGenOutput>
    </None>
    <None Update="Templates\EightTemplate.tt">
      <Generator>TextTemplatingFilePreprocessor</Generator>
      <LastGenOutput>EightTemplate.cs</LastGenOutput>
    </None>
    <None Update="Templates\SingleLoopTemplate.tt">
      <Generator>TextTemplatingFilePreprocessor</Generator>
      <LastGenOutput>SingleLoopTemplate.cs</LastGenOutput>
    </None>
  </ItemGroup>

  <ItemGroup>
    <Service Include="{508349b6-6b84-4df5-91f0-309beebad82d}" />
  </ItemGroup>

  <ItemGroup>
    <Compile Update="Templates\CollisionTemplate.cs">
      <DesignTime>True</DesignTime>
      <AutoGen>True</AutoGen>
      <DependentUpon>CollisionTemplate.tt</DependentUpon>
    </Compile>
    <Compile Update="Templates\CountableTemplate.cs">
      <DesignTime>True</DesignTime>
      <AutoGen>True</AutoGen>
      <DependentUpon>CountableTemplate.tt</DependentUpon>
    </Compile>
    <Compile Update="Templates\EightTemplate.cs">
      <DesignTime>True</DesignTime>
      <AutoGen>True</AutoGen>
      <DependentUpon>EightTemplate.tt</DependentUpon>
    </Compile>
    <Compile Update="Templates\SingleLoopTemplate.cs">
      <DesignTime>True</DesignTime>
      <AutoGen>True</AutoGen>
      <DependentUpon>SingleLoopTemplate.tt</DependentUpon>
    </Compile>
  </ItemGroup>

</Project>
```
</div></details>

<details><summary>SingleLoopTemplate.cs</summary><div>

```csharp
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using Microsoft.CodeAnalysis;

namespace MyAnalyzer.Templates
{
    public partial class SingleLoopTemplate
    {
        public readonly INamedTypeSymbol TypeSymbol;
        public readonly TypeStruct[] Outers;
        public readonly TypeStruct[] Others;
        public readonly TypeStruct[] Tables;

        public readonly MethodStruct Ordinal;
        public readonly MethodStruct? Fma;

        public SingleLoopTemplate(INamedTypeSymbol typeSymbol, TypeStruct[] outers, TypeStruct[] others, TypeStruct[] tables, MethodStruct ordinal, MethodStruct? fma)
        {
            TypeSymbol = typeSymbol;
            Outers = outers;
            Others = others;
            Tables = tables;
            Ordinal = ordinal;
            Fma = fma;
        }

        public static SingleLoopTemplate? TryCreate(ISymbol loopType, ISymbol intrinsicsKindMethod, INamedTypeSymbol typeSymbol)
        {
            var comparer = SymbolEqualityComparer.Default;
            if (!InterpretLoopType(loopType, typeSymbol, comparer, out var outers, out var others, out var tables))
            {
                return default;
            }

            if (!CollectLoop(intrinsicsKindMethod, typeSymbol, comparer, outers, others, tables, out var ordinal, out var fma))
            {
                return default;
            }

            return new(typeSymbol, outers, others, tables, ordinal, fma);
        }

        private static bool InterpretLoopType(ISymbol loopType, INamedTypeSymbol typeSymbol, SymbolEqualityComparer comparer, out TypeStruct[] outers, out TypeStruct[] others, out TypeStruct[] tables)
        {
            outers = Array.Empty<TypeStruct>();
            others = Array.Empty<TypeStruct>();
            tables = Array.Empty<TypeStruct>();

            var typeAttr = typeSymbol.GetAttributes().SingleOrDefault(x => comparer.Equals(x.AttributeClass, loopType));
            if (typeAttr is null)
            {
                return false;
            }

            var arguments = typeAttr.ConstructorArguments;
            var length = arguments.Length;
            if (length < 2)
            {
                return false;
            }

            if (!TypeStruct.InterpretCollisionTypeLoopFields(arguments[0].Values, arguments[1].Values, arguments[2].Value as string, out outers))
            {
                return false;
            }

            if (length == 3)
            {
                return true;
            }

            if (length < 6)
            {
                return false;
            }

            if (!TypeStruct.InterpretCollisionTypeLoopFields(arguments[3].Values, arguments[4].Values, arguments[5].Values, out others))
            {
                return false;
            }

            if (length == 6)
            {
                return true;
            }

            if (length < 9)
            {
                return false;
            }

            return TypeStruct.InterpretCollisionTypeLoopFields(arguments[6].Values, arguments[7].Values, arguments[8].Values, out tables);
        }


        private static bool CollectLoop(ISymbol loopMethod, INamedTypeSymbol typeSymbol, SymbolEqualityComparer comparer, TypeStruct[] outers, TypeStruct[] others, TypeStruct[] tables, out MethodStruct ordinal, out MethodStruct? fma)
        {
            var isOrdinalInitialized = false;
            ordinal = default;
            fma = default;
            List<ParameterStruct> parameterOuters = new();
            List<ParameterStruct> parameterOthers = new();
            List<ParameterStruct> parameterTables = new();
            foreach (var member in typeSymbol.GetMembers())
            {
                if (member is not IMethodSymbol methodSymbol)
                {
                    continue;
                }

                var attributeData = member.GetAttributes().SingleOrDefault(x => comparer.Equals(x.AttributeClass, loopMethod));
                var array = attributeData?.ConstructorArguments;
                if (array?[0].Value is not int kind)
                {
                    continue;
                }

                var intrinsicsKind = (IntrinsicsKind)kind;
                switch (intrinsicsKind)
                {
                    case IntrinsicsKind.Ordinal:
                    case IntrinsicsKind.Fma:
                        break;
                    default:
                        return false;
                }

                parameterOuters.Clear();
                parameterOthers.Clear();
                parameterTables.Clear();
                var parameters = methodSymbol.Parameters;
                var parameterIndex = 0;
                for (var typeIndex = 0; typeIndex < outers.Length; ++typeIndex)
                {
                    var typeStruct = outers[typeIndex];
                    foreach (var member2 in typeStruct.Symbol.GetMembers())
                    {
                        if (member2 is not IFieldSymbol fieldSymbol || fieldSymbol.IsStatic)
                        {
                            continue;
                        }

                        parameterOuters.Add(new(parameters[parameterIndex++], typeIndex, fieldSymbol.Name));
                    }
                }

                for (var typeIndex = 0; typeIndex < others.Length; ++typeIndex)
                {
                    parameterOthers.Add(new(parameters[parameterIndex++], typeIndex, string.Empty));
                }

                for (var typeIndex = 0; typeIndex < tables.Length; ++typeIndex, parameterIndex += 2)
                {
                    parameterTables.Add(new(parameters[parameterIndex], typeIndex, string.Empty));
                }

                switch (intrinsicsKind)
                {
                    case IntrinsicsKind.Ordinal:
                        isOrdinalInitialized = true;
                        ordinal = new MethodStruct(methodSymbol, parameterOuters.ToArray(), parameterOthers.ToArray(), parameterTables.ToArray());
                        break;
                    case IntrinsicsKind.Fma:
                        fma = new MethodStruct(methodSymbol, parameterOuters.ToArray(), parameterOthers.ToArray(), parameterTables.ToArray());
                        break;
                }
            }

            return isOrdinalInitialized;
        }

        public readonly struct MethodStruct
        {
            public readonly IMethodSymbol Symbol;
            public readonly ParameterStruct[] Outers;
            public readonly ParameterStruct[] Others;
            public readonly ParameterStruct[] Tables;

            public MethodStruct(IMethodSymbol symbol, ParameterStruct[] outers, ParameterStruct[] others, ParameterStruct[] tables)
            {
                Symbol = symbol;
                Outers = outers;
                Others = others;
                Tables = tables;
            }
        }
    }

    public readonly struct TypeStruct
    {
        public readonly INamedTypeSymbol Symbol;
        public readonly bool IsReadOnly;
        public readonly string Name;

        public TypeStruct(INamedTypeSymbol symbol, bool isReadOnly, string name)
        {
            Symbol = symbol;
            IsReadOnly = isReadOnly;
            Name = name;
        }

        public static bool InterpretCollisionTypeLoopFields(ImmutableArray<TypedConstant> types, ImmutableArray<TypedConstant> bools, string? prefix, out TypeStruct[] answer)
        {
            answer = Array.Empty<TypeStruct>();
            if (prefix is null)
            {
                return false;
            }

            if (types.Length == 0 || types.Length != bools.Length)
            {
                return false;
            }

            answer = new TypeStruct[types.Length];
            for (var i = 0; i < answer.Length; i++)
            {
                if (types[i].Value is not INamedTypeSymbol typeSymbol || bools[i].Value is not bool boolValue)
                {
                    return false;
                }

                answer[i] = new(typeSymbol, boolValue, prefix + typeSymbol.Name);
            }

            return true;
        }

        public static bool InterpretCollisionTypeLoopFields(ImmutableArray<TypedConstant> types, ImmutableArray<TypedConstant> bools, ImmutableArray<TypedConstant> names, out TypeStruct[] answer)
        {
            answer = Array.Empty<TypeStruct>();
            if (types.Length == 0 || types.Length != bools.Length)
            {
                return false;
            }

            answer = new TypeStruct[types.Length];
            for (var i = 0; i < answer.Length; i++)
            {
                if (types[i].Value is not INamedTypeSymbol typeSymbol)
                {
                    return false;
                }

                if (bools[i].Value is not bool boolValue)
                {
                    return false;
                }

                if (names[i].Value is not string nameValue)
                {
                    return false;
                }

                answer[i] = new(typeSymbol, boolValue, nameValue);
            }

            return true;
        }
    }
}
```
</div></details>

デバッガビリティのために条件文を一纏めにしていません。<br/>
C# Source Generatorのデバッグは非常にめんどくさいため、多少文字数は増えてもデバッガビリティを上げましょう。もなふわすい～とお祈りタイムが減ります。

上記処理では属性のコンストラクタ引数である`TypedConstant`オブジェクトを良い感じに解釈していっています。<br/>
[C#の属性に持たせられる情報は非常に限定的です。](https://docs.microsoft.com/ja-jp/dotnet/csharp/language-reference/language-specification/attributes#attribute-parameter-types)<br/>
そのため、自作の構造体を使用したい場合でも諦めざるを得ません。<br/>
無敵のダーク巻乃さんがMSに命令してくれたらなんとかなると思うのですが……

さて、`TryCreate`で適切なオブジェクトを生成した後は`TransformText`でソースコードを生成します。<br/>
以下がそのテンプレートコードです。

<details><summary>SingleLoop.tt</summary><div>

```
<#@ template language="C#" #>
<#@ assembly name="System.Core" #>
<#@ import namespace="System.Linq" #>
<#@ import namespace="System.Text" #>
<#@ import namespace="System.Collections.Generic" #>
namespace <#= TypeSymbol.ContainingNamespace.ToDisplayString() #>
{
    <#= TypeSymbol.IsStatic ? "static " : "" #>partial <#= TypeSymbol.IsValueType ? "struct " : "class " #> <#= TypeSymbol.Name #>
    {
        [global::Unity.Burst.BurstCompile]
        public unsafe partial struct Job : global::Unity.Jobs.IJob
        {
<# for (var index = 0; index < Outers.Length; ++index) {
    var item = Outers[index]; #>
            <# if (item.IsReadOnly) { #>[global::Unity.Collections.ReadOnly] <# } #>public global::Unity.Collections.NativeArray<<#= item.Symbol.ToDisplayString() #>.Eight> <#= item.Name #>;
<# } #>
<# for (var index = 0; index < Others.Length; ++index) {
    var item = Others[index]; 
    if (item.IsReadOnly) { #>
            public <#= item.Symbol.ToDisplayString() #> <#= item.Name #>;
<# } else { #>
            [global::Unity.Collections.LowLevel.Unsafe.NativeDisableContainerSafetyRestrictionAttribute] 
            public global::Unity.Collections.NativeArray<<#= item.Symbol.ToDisplayString() #>> <#= item.Name #>;
<# } #>
<# } #>
<# for (var index = 0; index < Tables.Length; ++index) {
    var item = Tables[index]; #>
            <# if (item.IsReadOnly) { #>[global::Unity.Collections.ReadOnly] <# } else { #>[global::Unity.Collections.LowLevel.Unsafe.NativeDisableContainerSafetyRestrictionAttribute] <# } #>

            public global::Unity.Collections.NativeArray<<#= item.Symbol.ToDisplayString() #>> <#= item.Name #>;
<# } #>

            public void Execute()
            {
<# for (var index = 0; index < Tables.Length; ++index) {
    var item = Tables[index];
    if (item.IsReadOnly) { #>
                var tablePointer<#= index #> = global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeReadOnlyPtr(<#= item.Name #>);
<# } else { #>
                var tablePointer<#= index #> = global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(<#= item.Name #>);
<# } #>
<# } #>
<# if (Fma.HasValue) { var method = Fma.Value; #>
                if (global::Unity.Burst.Intrinsics.X86.Fma.IsFmaSupported)
                {
<# for (var index = 0; index < Others.Length; ++index) {
    var item = Others[index];
    if (item.IsReadOnly) { #>
                    var other<#= index #> = new global::Unity.Burst.Intrinsics.v256(<#= item.Name #>, <#= item.Name #>, <#= item.Name #>, <#= item.Name #>, <#= item.Name #>, <#= item.Name #>, <#= item.Name #>, <#= item.Name #>);
<# } else { #>
                    var other<#= index #> = <#= item.Name #>[0];
<# } #>
<# } #>
<# for (var index = 0; index < Outers.Length; ++index) {
    var item = Outers[index]; #>
                    var outerPointer<#= index #> = (byte*)global::Unity.Collections.LowLevel.Unsafe.NativeArrayUnsafeUtility.GetUnsafeBufferPointerWithoutChecks(<#= item.Name #>);
<# } #>

                    for (
                        var outerIndex = 0;
                        outerIndex < <#= Outers[0].Name #>.Length;
                        ++outerIndex<# for (var index = 0; index < Outers.Length; ++index) { #>,
                        outerPointer<#= index #> += sizeof(<#= Outers[index].Symbol.ToDisplayString() #>.Eight)<# } #>

                    )
                    {
<# for (var index = 0; index < method.Outers.Length; ++index) {
    var item = method.Outers[index];
    var fieldIndex = item.GetIndex(Outers[item.Index].Symbol); #>
                        var outer<#= item.Index #>_<#= item.Name #> = global::Unity.Burst.Intrinsics.X86.Avx.mm256_load_ps(outerPointer<#= item.Index #> + (<#= fieldIndex #> << 5));
<# } #>
<# { 
      var parameter = method.Outers[0]; #>
                        <#= method.Symbol.Name #>(ref outer<#= parameter.Index #>_<#= parameter.Name #><# for (var index = 1; index < method.Outers.Length; ++index) { parameter = method.Outers[index]; #>, ref outer<#= parameter.Index #>_<#= parameter.Name #><# } for (var index = 0; index < method.Others.Length; ++index) { parameter = method.Others[index]; #>, ref other<#= parameter.Index #><# } for (var index = 0; index < method.Tables.Length; ++index) { parameter = method.Tables[index]; #>, tablePointer<#= parameter.Index #>, <#= Tables[parameter.Index].Name #>.Length<# } #>);
<# } #>
<# for (var index = 0; index < method.Outers.Length; ++index) {
    var item = method.Outers[index];
    var typeItem = Outers[item.Index];
    if (typeItem.IsReadOnly) { continue; }
    var fieldIndex = item.GetIndex(typeItem.Symbol); #>
                        global::Unity.Burst.Intrinsics.X86.Avx.mm256_store_ps(outerPointer<#= item.Index #> + (<#= fieldIndex #> << 5), outer<#= item.Index #>_<#= item.Name #>);
<# } #>
                    }
<# for (var index = 0; index < Others.Length; ++index) {
    var item = Others[index];
    if (item.IsReadOnly) { continue; } #>

                    <#= item.Name #>[0] = other<#= index #>;
<# } #>
                    return;
                }

<# } #>
<# { var method = Ordinal; #>
                {
<# for (var index = 0; index < Others.Length; ++index) {
    var item = Others[index];
    if (item.IsReadOnly) { #>
                    var other<#= index #> = new global::Unity.Mathematics.<#= item.Symbol.ToDisplayString() #>4(<#= item.Name #>, <#= item.Name #>, <#= item.Name #>, <#= item.Name #>);
<# } else { #>
                    var other<#= index #> = <#= item.Name #>[0];
<# } #>
<# } #>

                    for (var outerIndex = 0; outerIndex < <#= Outers[0].Name #>.Length; ++outerIndex)
                    {
<# for (var index = 0; index < Outers.Length; ++index) {
    var item = Outers[index]; #>
                        var outer<#= index #> = <#= item.Name #>[outerIndex];
<# } #>
<# for (var cIndex0 = 0; cIndex0 < 2; ++cIndex0) {
      var parameter = method.Outers[0]; #>
                        <#= method.Symbol.Name #>(ref outer<#= parameter.Index #>.<#= parameter.Name #>.c<#= cIndex0 #><# for (var index = 1; index < method.Outers.Length; ++index) { parameter = method.Outers[index]; #>, ref outer<#= parameter.Index #>.<#= parameter.Name #>.c<#= cIndex0 #><# } for (var index = 0; index < method.Others.Length; ++index) { parameter = method.Others[index]; #>, ref other<#= parameter.Index #><# } for (var index = 0; index < method.Tables.Length; ++index) { parameter = method.Tables[index]; #>, tablePointer<#= parameter.Index #>, <#= Tables[parameter.Index].Name #>.Length<# } #>);
<# } #>
<# for (var index = 0; index < Outers.Length; ++index) {
    var item = Outers[index];
    if (item.IsReadOnly) { continue; } #>
                        <#= item.Name #>[outerIndex] = outer<#= index #>;
<# } #>
                    }
<# for (var index = 0; index < Others.Length; ++index) {
    var item = Others[index];
    if (item.IsReadOnly) { continue; } #>

                    <#= item.Name #>[0] = other<#= index #>;
<# } #>
                }
<# } #>
            }
        }
    }
}
```
</div></details>

<details><summary>.tt</summary><div>

```
```
</div></details>