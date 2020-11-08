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

# Single Instruction Multiple Data

## 伝統的なオブジェクト指向設計

一部のゲームジャンル（STG、RTS）ではよく似た計算式を大量のオブジェクトに適用する類の計算を行います。

例えば敵(Enemy)が1万体出て来てそれをひたすら撃ち落とすというシューティングゲームがあるとします。<br/>
普通のオブジェクト指向で敵と弾丸をモデリングして書いてみると多分次のような記述になるのではないでしょうか。

<details><summary>モデル.cs</summary>

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
</details>

そしてObjectiveEnemyとObjectiveBulletの衝突判定はおそらくこうなるでしょう。

<details><summary>衝突判定.cs</summary>

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
</details>

この設計で特に問題はないと考える人は多いはずです。<br/>
**実際問題になることはまずありません。**

## Data Oriented Technology Stack(DOTS)で速くする

**しかし弾丸が数万、敵が数十万だったならば？**<br/>
前述のコードでは遅すぎますね……。<br/>
Unity ECS的にコードを書き直すと以下のような記述となります。<br/>
型については名前空間を含めて完全な名前を書いていますのでわからないものについては検索してください。

<details><summary>モデル.cs</summary>

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
</details>

<details><summary>衝突判定用IJob.cs</summary>

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
</details>

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

<details><summary>モデル.cs</summary>

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
</details>

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
    public Unity.Mathematics.float4x4 XY;
}
```

この`AnotherPosition2DEight`は効率的なSIMD演算を阻害します。特にXとY同士で計算しようとすると非常に非効率になります。<br/>
X座標はX座標と、Y座標はY座標とお付き合いするべきだと思うの。

x86/64系CPUでSIMDを使う際に注意してほしいことなのですけれども、**比較演算の結果のtrueは比較対象の型の幅の全bitが1になっています**。<br/>
故に`enum AliveState`はDeadが-1でAliveが0とすることで、それぞれ`true`と`false`に対応させているのですね。

比較演算でtrueなら全bit1となる仕様はx86/64系とARM系の両方で保証されています。RISC-Vとかはよくわかりませんが、Unity使用者なら気にせずともよいでしょう。

以下は衝突判定の実装部分です。<br/>
Unity.Burst.Intrinsicsを利用している記事では多分日本語では初かそうでなくても２番目なんじゃないですかね……？

<details><summary>長いソースコード</summary>

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
</details>

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

C#9をサポートしたRoslynバージョン3.8からはC# Source Generatorという