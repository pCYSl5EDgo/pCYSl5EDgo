# C# Source GeneratorによるAOSOAを活用したDOTSプログラミング補助の試みとそのUnityにおける敗北

1999年12月8日は「ハリー・ポッターと賢者の石」が日本で発売された日です。故にこの記事も初投稿です。
昨日の記事は[サンマックスさん](https://twitter.com/Sunmax0731)の「[]()」でした！
明日の記事はオークマネコさんの「」です。

# はじめに

皆さんこんにちは～！ バーチャルHigh Performance C#erのスーギ・ノウコ自治区です。

きっとこの記事を読む皆さんは[巻乃もなか氏](https://twitter.com/monaka_0_0_7)のことが大好きなのですよね？<br/>
そして皆さんがUnityエンジニアであるならば、ビルドが失敗した時とかに「たすけて！もなふわすい～とる～む！！」とTwitterに書き込んだ経験があるはずです。
周囲に人がいなかったならば声に出していた人もいるでしょう。

この記事は私がもなふわすい～とる～むに助けを求めた事例について記載しています。
巻乃もなか氏についての魅力を語りつくす類の記事ではないことをご了承ください。

# 参考文献

最初にこの記事を読むに当たって理解の助けになると思われる記事を列挙します。
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

## Data Oriented Technology Stackで速くする

**しかし弾丸が数万、敵が数十万だったならば？**<br/>
前述のコードでは遅すぎますね……。<br/>
Unity ECS的にコードを書き直すと以下のような記述となります。
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
    public bool IsAlive;
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
            Position2D enemyPosition = EnemyPositionArray[enemyIndex];
            Size enemySize = EnemySizeArray[enemyIndex];
            for (int bulletIndex = 0; bulletIndex < BulletPositionArray.Length; bulletIndex++)
            {
                Position2D bulletPosition = BulletPositionArray[bulletIndex];
                Size bulletSize = BulletSizeArray[bulletIndex];

                float diffX = enemyPosition.X - bulletPosition.X;
                float diffY = enemyPosition.Y - bulletPosition.Y;
                float distanceSquared = diffX * diffX + diffY * diffY;
                float collisionRadius = enemy.Size + bullet.Size;
                bool isCollided = distanceSquared <= collisionRadius * collisionRadius;
                if (isCollided)
                {
                    ProcessCollision(enemyIndex, bulletIndex);
                }
            }
        }
    }

    private void ProcessCollision(int enemyIndex, int bulletIndex)
    {
        EnemyAliveStateArray[enemyIndex] = new AliveState { IsAlive = false };
        BulletAliveStateArray[bulletIndex] = new AliveState { IsAlive = false };
    }
}
```
</details>

なぜこれが速くなるのでしょうか？
[参照の空間的局所性](https://ja.wikipedia.org/wiki/%E5%8F%82%E7%85%A7%E3%81%AE%E5%B1%80%E6%89%80%E6%80%A7)がかなり高まっているからです。
`Unity.Collections.NativeArray<Position2D>`が示すようにx座標とy座標がペアになってメモリ上に一列にぎっちりと並んでいますね。
このため弾丸と敵との距離を計算するのが楽になっています。

とはいえ衝突時の処理をハードコーディングせねばならないので柔軟性は従来のオブジェクト指向に比べたら低下しています。

## もっともっと速くしたい

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
        Unity.Collections.NativeArray<UnityBurst.Intrinsics.v256> enemyPositionArray = EnemyPositionArray.Reinterpret<UnityBurst.Intrinsics.v256>(sizeof(UnityBurst.Intrinsics.v256));
        Unity.Collections.NativeArray<UnityBurst.Intrinsics.v256> bulletPositionArray = BulletPositionArray.Reinterpret<UnityBurst.Intrinsics.v256>(sizeof(UnityBurst.Intrinsics.v256));
        Unity.Collections.NativeArray<UnityBurst.Intrinsics.v256> enemyAliveStateArray = EnemyAliveStateArray.Reinterpret<UnityBurst.Intrinsics.v256>(sizeof(UnityBurst.Intrinsics.v256));
        Unity.Collections.NativeArray<UnityBurst.Intrinsics.v256> bulletAliveStateArray = BulletAliveStateArray.Reinterpret<UnityBurst.Intrinsics.v256>(sizeof(UnityBurst.Intrinsics.v256));
        Unity.Collections.NativeArray<UnityBurst.Intrinsics.v256> enemySizeArray = EnemySizeArray.Reinterpret<UnityBurst.Intrinsics.v256>(sizeof(UnityBurst.Intrinsics.v256));
        Unity.Collections.NativeArray<UnityBurst.Intrinsics.v256> bulletSizeArray = BulletSizeArray.Reinterpret<UnityBurst.Intrinsics.v256>(sizeof(UnityBurst.Intrinsics.v256));
        for (int enemyIndex = 0; enemyIndex < EnemyPositionArray.Length; enemyIndex++)
        {
            UnityBurst.Intrinsics.v256 enemyAliveState = enemyAliveStateArray[enemyIndex];
            UnityBurst.Intrinsics.v256 enemyPositionX = enemyPositionArray[(enemyIndex << 1)];
            UnityBurst.Intrinsics.v256 enemyPositionY = enemyPositionArray[(enemyIndex << 1) + 1];
            UnityBurst.Intrinsics.v256 enemySize = enemySizeArray[enemyIndex];

            for (int bulletIndex = 0; bulletIndex < BulletPositionArray.Length; bulletIndex++)
            {
                UnityBurst.Intrinsics.v256 bulletAliveState = bulletAliveStateArray[bulletIndex];
                UnityBurst.Intrinsics.v256 bulletPositionX = bulletPositionArray[(bulletIndex << 1)];
                UnityBurst.Intrinsics.v256 bulletPositionY = bulletPositionArray[(bulletIndex << 1) + 1];
                UnityBurst.Intrinsics.v256 bulletSize = bulletSizeArray[bulletIndex];

                for (int swapIndex = 0; swapIndex < 2; ++swapIndex)
                {
                    for (int rotateIndex = 0; rotateIndex < 4; ++rotateIndex)
                    {
                        UnityBurst.Intrinsics.v256 diffX = Unity.Burst.Intrinsics.Avx.mm256_sub_ps(enemyPositionX, bulletPositionX);
                        UnityBurst.Intrinsics.v256 diffY = Unity.Burst.Intrinsics.Avx.mm256_sub_ps(enemyPositionY, bulletPositionY);
                        UnityBurst.Intrinsics.v256 distanceSquared = Unity.Burst.Intrinsics.Avx.mm256_mul_ps(diffX, diffX);
                        distanceSquared = Unity.Burst.Intrinsics.Fma.mm256_fmadd_ps(diffY, diffY, distanceSquared);
                        UnityBurst.Intrinsics.v256 collisionRadius = Unity.Burst.Intrinsics.Avx.mm256_add_ps(enemySize, bulletSize);
                        UnityBurst.Intrinsics.v256 collisionRadiusSquared = Unity.Burst.Intrinsics.Avx.mm256_mul_ps(collisionRadius, collisionRadius);
                        UnityBurst.Intrinsics.v256 isCollided = Unity.Burst.Intrinsics.Avx.mm256_cmp_ps(distanceSquared, collisionRadiusSquared, (int)Unity.Burst.Intrinsics.Avx.CMP.LE_OQ);
                        int isCollidedMask = Unity.Burst.Intrinsics.Avx.mm256_movemask_ps(isCollided);
                        
                        ProcessCollisionFma(isCollidedMask, enemyAliveState, bulletAliveState);

                        if (swapIndex == 1 && rotateIndex == 3)
                        {
                            break;
                        }

                        Rotate(ref bulletAliveState);
                        Rotate(ref bulletPositionX);
                        Rotate(ref bulletPositionY);
                        Rotate(ref bulletSize);
                    }

                    if (swapIndex == 0)
                    {
                        Swap(ref bulletAliveState);
                        Swap(ref bulletPositionX);
                        Swap(ref bulletPositionY);
                        Swap(ref bulletSize);
                    }
                }
            }
        }
    }

    private static void Swap(ref UnityBurst.Intrinsics.v256 value)
    {
        value = Unity.Burst.Intrinsics.Avx2.mm256_permute2x128_si256(value, value, 0b0000_0001);
    }

    private static void Rotate(ref UnityBurst.Intrinsics.v256 value)
    {
        value = Unity.Burst.Intrinsics.Avx2.mm256_permutevar8x32_ps(value, new v256(1, 2, 3, 0, 1, 2, 3, 0));
    }

    private void ProcessCollisionFma(int isCollided, UnityBurst.Intrinsics.v256 enemyAliveState, UnityBurst.Intrinsics.v256 bulletAliveState)
    {
        /* 省略 */
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
                    if (Unity.Mathematics.math.any(isCollided))
                    {
                        ProcessCollision(isCollided, enemyAliveState, bulletAliveState);
                    }
                }
            }
        }
    }

    private void ProcessCollision(Unity.Mathematics.bool4x2 isCollided, AliveStateEight enemyAliveState, AliveStateEight bulletAliveState)
    {
        /* 省略 */
    }
}
```
</details>