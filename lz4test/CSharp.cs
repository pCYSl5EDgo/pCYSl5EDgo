/*
Copyright (c) 2020, pCYSl5EDgo

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Copyright (c) 2013, Milosz Krajewski
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided
that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions
  and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions
  and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

using System;
using System.Diagnostics;
using static Definition;

public static class Definition
{
    public static readonly int[] DEBRUIJN_TABLE_32 =
    {
        0, 0, 3, 0, 3, 1, 3, 0, 3, 2, 2, 1, 3, 2, 0, 1,
        3, 3, 1, 2, 2, 2, 2, 0, 3, 1, 2, 0, 1, 0, 1, 1,
    };

    public static readonly int[] DECODER_TABLE_32 = { 0, 3, 2, 3, 0, 0, 0, 0 };

    public const int MINMATCH = 4;
    public const int SKIPSTRENGTH = 6;
    public const int MFLIMIT = 12;
    public const int MINLENGTH = 13;
    public const int MAX_DISTANCE = 0xffff;
    private const int HASH_TABLESIZE = 0x400;
    private const int HASH64K_TABLESIZE = 0x800;

    private static readonly ushort[] hashtableSmall = new ushort[HASH64K_TABLESIZE];
    private static readonly uint[] hashtableBig = new uint[HASH_TABLESIZE];
    
    public static unsafe ushort* HashtableSmall 
    {
        get
        {
            fixed (ushort* ptr = &hashtableSmall[0])
            {
                return ptr;
            }
        }
    }

    public static void ClearTableBig()
    {
        Array.Clear(hashtableBig, 0, HASH_TABLESIZE);
    }

    public static void ClearTableSmall()
    {
        Array.Clear(hashtableSmall, 0, HASH64K_TABLESIZE);
    }

    public static unsafe uint* HashtableBig
    {
        get
        {
            fixed (uint* ptr = &hashtableBig[0])
            {
                return ptr;
            }
        }
    }

    public static int MaxCount(int count) => count + (count / 255) + 16;

    public static unsafe void BlockCopy32(byte* dst, byte* src, int len)
    {
        while (len >= 4)
        {
            *(uint*)dst = *(uint*)src;
            dst += 4;
            src += 4;
            len -= 4;
        }

        if (len >= 2)
        {
            *(ushort*)dst = *(ushort*)src;
            dst += 2;
            src += 2;
            len -= 2;
        }

        if (len >= 1)
        {
            *dst = *src; /* d++; s++; l--; */
        }
    }
}

public static class Modify
{
    public static unsafe int Compress(byte[] src, byte[] dst)
    {
        fixed (byte* s = &src[0])
        fixed (byte* d = &dst[0])
        {
            var dm = MaxCount(src.Length);
            if (src.Length < 0x1000b)
            {
                ClearTableSmall();
                return CompressSmall64K(s, d, src.Length, dm);
            }
            else
            {
                ClearTableBig();
                return CompressBig(s, d, src.Length, dm);
            }
        }
    }

    public static unsafe int CompressBig(
        byte* src,
        byte* dst,
        int src_len,
        int dst_maxlen)
    {
        unchecked
        {
            var src_p = src; //var0
            var src_anchor = src_p; // var4
            var src_end = src + src_len; // var2

            var dst_p = dst; // var5
            var dst_end = dst + dst_maxlen; // var3

            var hash_table = (byte*)HashtableBig;

            int findMatchAttempts; // var7
            byte* src_p_fwd; // var8
            byte* xxx_ref; // var9
            byte* xxx_token; // var10
            uint h, h_fwd; // var11, var6
            int len, length; // var12, var13
            int diff;
            int return0 = 0;

            // Init
            if (src_len >= 13)
            {
                // First Byte
                *(uint*)(hash_table + CalcHash(src_p)) = (uint)(src_p - src);
                h_fwd = CalcHash(++src_p);

                // Main Loop
                while (true)
                {
                    findMatchAttempts = 67;
                    src_p_fwd = src_p;

                    // Find a match
                    while (true)
                    {
                        h = h_fwd;
                        src_p_fwd = (src_p = src_p_fwd) + (findMatchAttempts++ >> 6);

                        if (src_p_fwd > src_end - 12) goto leave_main_loop;

                        h_fwd = CalcHash(src_p_fwd);
                        xxx_ref = src + *(uint*)(hash_table + h);
                        *(uint*)(hash_table + h) = (uint)(src_p - src);

                        if (xxx_ref < src_p - 0xffff) continue;
                        if (*(uint*)xxx_ref != *(uint*)src_p) continue;
                        break;
                    }

                    // Catch up
                    if (src_p > src_anchor)
                    {
                        if (xxx_ref > src)
                        {
                            if (*(src_p - 1) == *(xxx_ref - 1))
                            {
                                while (true)
                                {
                                    src_p--;
                                    xxx_ref--;
                                    if (src_p > src_anchor)
                                        if (xxx_ref > src)
                                            if (*(src_p - 1) == *(xxx_ref - 1))
                                                continue;
                                    break;
                                }
                            }
                        }
                    }

                    // Encode Literal length
                    length = (int)(src_p - src_anchor);
                    xxx_token = dst_p;

                    if (++dst_p + length + (length >> 8) + 8 > dst_end)
                    {
                        return0 = 1;
                        goto leave_main_loop;
                        // Check output limit
                    }

                    if (length < 15)
                    {
                        *xxx_token = (byte)(length << 4);
                        CopyLiterals(src_anchor, dst_p, length);
                    }
                    else
                    {
                        *xxx_token = 240;
                        if ((len = length - 15) <= 254)
                        {
                            *dst_p = (byte)len;
                            CopyLiterals(src_anchor, ++dst_p, length);
                        }
                        else
                        {
                            while (true)
                            {
                                *dst_p = 255;
                                dst_p++;
                                if ((len -= 255) > 254) continue;
                                break;
                            }
                            *dst_p = (byte)len;
                            BlockCopy32(++dst_p, src_anchor, length);
                        }
                    }

                    dst_p += length;

                    while (true) // _next_match
                    {
                        // Encode Offset
                        *(ushort*)dst_p = (ushort)(src_p - xxx_ref);
                        dst_p += 2;

                        // Start Counting
                        src_p += 4;
                        xxx_ref += 4; // MinMatch already verified
                        src_anchor = src_p;

                        while (true) // leave_to_end_count
                        {
                            if (src_p < src_end - 8)
                            {
                                while (true)
                                {
                                    if ((diff = *(int*)xxx_ref ^ *(int*)src_p) == 0)
                                    {
                                        xxx_ref += 4;
                                        if ((src_p += 4) < src_end - 8) continue;
                                    }
                                    else
                                    {
                                        src_p += CalcDebruijn(diff);
                                        goto leave_to_end_count;
                                    }
                                    break;
                                }
                            }

                            if (src_p < src_end - 6)
                            {
                                if (*(ushort*)xxx_ref == *(ushort*)src_p)
                                {
                                    src_p += 2;
                                    xxx_ref += 2;
                                }
                            }

                            if (src_p < src_end - 5)
                            {
                                if (*xxx_ref == *src_p)
                                {
                                    src_p++;
                                }
                            }

                            break;
                        }

                    leave_to_end_count:
                        // Encode MatchLength
                        if (dst_p + ((len = (int)(src_p - src_anchor)) >> 8) > dst_end - 6)
                        {
                            return0 = 1;
                            goto leave_main_loop;
                            // Check output limit
                        }

                        if (len >= 15)
                        {
                            *xxx_token += 15;
                            if ((len -= 15) > 509)
                            {
                                while (true)
                                {
                                    *(ushort*)dst_p = 0xffff;
                                    dst_p += 2;
                                    if ((len -= 510) > 509) continue;
                                    break;
                                }
                            }

                            if (len > 254)
                            {
                                len -= 255;
                                *dst_p = 255;
                                dst_p++;
                            }

                            *dst_p = (byte)len;
                            dst_p++;
                        }
                        else
                        {
                            *xxx_token += (byte)len;
                        }

                        // Test end of chunk
                        if (src_p > src_end - 12)
                        {
                            src_anchor = src_p;
                            goto leave_main_loop;
                        }

                        // Fill table
                        *(uint*)(hash_table + CalcHash(src_p - 2)) = (uint)(src_p - 2 - src);

                        // Test next position
                        h = CalcHash(src_p);
                        xxx_ref = src + *(uint*)(hash_table + h);
                        *(uint*)(hash_table + h) = (uint)(src_p - src);

                        if (xxx_ref > src_p - 0x10000)
                        {
                            if (*(uint*)xxx_ref == *(uint*)src_p)
                            {
                                *(xxx_token = dst_p) = 0;
                                dst_p++;
                                continue;
                            }
                        }

                        break;
                    }

                    // Prepare next loop
                    src_anchor = src_p;
                    h_fwd = CalcHash(++src_p);
                    continue;
                }
            }

        leave_main_loop:
            if (return0 == 1)
            {
                return 0;
            }
            else
            {
                return LastLiterals(src_anchor, src_end, dst, dst_p, dst_end);
            }
        }
    }

    private static unsafe int CalcDebruijn(int diff)
    {
        fixed (void* p = &DEBRUIJN_TABLE_32[0])
        {
            var z = (byte*)p;
            return *(int*)(z + ((((uint)(diff & -diff) * 0x077CB531u) >> 27) << 2));
        }
    }

    public static unsafe int CompressSmall64K(
        byte* src,
        byte* dst,
        int src_len,
        int dst_maxlen)
    {
        unchecked
        {
            var src_p = src;
            var src_anchor = src_p;
            var src_end = src + src_len;

            var dst_p = dst;
            var dst_end = dst + dst_maxlen;

            var hash_table = (byte*)HashtableSmall;

            int findMatchAttempts;
            byte* src_p_fwd;
            byte* xxx_ref;
            byte* xxx_token;
            uint h, h_fwd;
            int len, length;
            int diff;
            int return0 = 0;

            // Init
            if (src_len >= 13)
            {
                // First Byte
                h_fwd = CalcHash64K(++src_p);

                // Main Loop
                while (true)
                {
                    findMatchAttempts = 67;
                    src_p_fwd = src_p;

                    // Find a match
                    while (true)
                    {
                        h = h_fwd;
                        src_p_fwd = (src_p = src_p_fwd) + (findMatchAttempts++ >> 6);

                        if (src_p_fwd > src_end - 12) goto leave_main_loop;

                        h_fwd = CalcHash64K(src_p_fwd);
                        xxx_ref = src + *(ushort*)(hash_table + h);
                        *(ushort*)(hash_table + h) = (ushort)(src_p - src);

                        if (*(uint*)xxx_ref != *(uint*)src_p) continue;
                        break;
                    }

                    // Catch up
                    if (src_p > src_anchor)
                    {
                        if (xxx_ref > src)
                        {
                            if (*(src_p - 1) == *(xxx_ref - 1))
                            {
                                while (true)
                                {
                                    src_p--;
                                    xxx_ref--;

                                    if (src_p > src_anchor)
                                        if (xxx_ref > src)
                                            if (*(src_p - 1) == *(xxx_ref - 1))
                                                continue;
                                    break;
                                }
                            }
                        }
                    }

                    // Encode Literal length
                    length = (int)(src_p - src_anchor);
                    xxx_token = dst_p;

                    if (++dst_p + length + (length >> 8) + 8 > dst_end)
                    {
                        return0 = 1;
                        goto leave_main_loop;
                        // Check output limit
                    }

                    if (length < 15)
                    {
                        *xxx_token = (byte)(length << 4);
                        CopyLiterals(src_anchor, dst_p, length);
                    }
                    else
                    {
                        *xxx_token = 240;
                        if ((len = length - 15) <= 254)
                        {
                            *dst_p = (byte)len;
                            CopyLiterals(src_anchor, ++dst_p, length);
                        }
                        else
                        {
                            while (true)
                            {
                                *dst_p = 255;
                                dst_p++;
                                if ((len -= 255) > 254) continue;
                                break;
                            }
                            *dst_p = (byte)len;
                            BlockCopy32(++dst_p, src_anchor, length);
                        }
                    }

                    dst_p += length;

                    while (true) // _next_match
                    {
                        // Encode Offset
                        *(ushort*)dst_p = (ushort)(src_p - xxx_ref);
                        dst_p += 2;

                        // Start Counting
                        src_p += 4;
                        xxx_ref += 4; // MinMatch already verified
                        src_anchor = src_p;

                        while (true) // leave_to_end_count
                        {
                            if (src_p < src_end - 8)
                            {
                                while (true)
                                {
                                    if ((diff = *(int*)xxx_ref ^ *(int*)src_p) == 0)
                                    {
                                        xxx_ref += 4;
                                        if ((src_p += 4) < src_end - 8) continue;
                                    }
                                    else
                                    {
                                        src_p += CalcDebruijn(diff);
                                        goto leave_to_end_count;
                                    }
                                    break;
                                }
                            }

                            if (src_p < src_end - 6)
                            {
                                if (*(ushort*)xxx_ref == *(ushort*)src_p)
                                {
                                    src_p += 2;
                                    xxx_ref += 2;
                                }
                            }

                            if (src_p < src_end - 5)
                            {
                                if (*xxx_ref == *src_p)
                                {
                                    src_p++;
                                }
                            }

                            break;
                        }

                    leave_to_end_count:
                        // Encode MatchLength
                        if (dst_p + ((len = (int)(src_p - src_anchor)) >> 8) > dst_end - 6)
                        {
                            return0 = 1;
                            goto leave_main_loop;
                            // Check output limit
                        }

                        if (len >= 15)
                        {
                            *xxx_token += 15;
                            if ((len -= 15) > 509)
                            {
                                while (true)
                                {
                                    *(ushort*)dst_p = 0xffff;
                                    dst_p += 2;
                                    if ((len -= 510) > 509) continue;
                                    break;
                                }
                            }

                            if (len > 254)
                            {
                                len -= 255;
                                *dst_p = 255;
                                dst_p++;
                            }

                            *dst_p = (byte)len;
                            dst_p++;
                        }
                        else
                        {
                            *xxx_token += (byte)len;
                        }

                        // Test end of chunk
                        if (src_p > src_end - 12)
                        {
                            src_anchor = src_p;
                            goto leave_main_loop;
                        }

                        // Fill table
                        *(ushort*)(hash_table + CalcHash64K(src_p - 2)) = (ushort)(src_p - 2 - src);

                        // Test next position
                        h = CalcHash64K(src_p);
                        xxx_ref = src + *(ushort*)(hash_table + h);
                        *(ushort*)(hash_table + h) = (ushort)(src_p - src);

                        if (*(uint*)xxx_ref == *(uint*)src_p)
                        {
                            *(xxx_token = dst_p) = 0;
                            dst_p++;
                            continue;
                        }

                        break;
                    }

                    // Prepare next loop
                    src_anchor = src_p;
                    h_fwd = CalcHash64K(++src_p);
                    continue;
                }
            }

        leave_main_loop:
            if (return0 == 1)
            {
                return 0;
            }
            else
            {
                return LastLiterals(src_anchor, src_end, dst, dst_p, dst_end);
            }
        }
    }


    private static unsafe uint CalcHash(byte* pointer)
    {
        return ((*(uint*)pointer * 2654435761u) >> 22) << 2;
    }

    private static unsafe uint CalcHash64K(byte* pointer)
    {
        return ((*(uint*)pointer * 2654435761u) >> 21) << 1;
    }

    private static unsafe int LastLiterals(byte* src_anchor, byte* src_end, byte* dst, byte* dst_p, byte* dst_end)
    {
        var srcRestLength = (int)(src_end - src_anchor);
        int lastRun;
        if (dst_p + ((srcRestLength << 8) + 495) / 255 > dst_end)
        {
            return 0;
        }
        else
        {
            lastRun = srcRestLength;
            if (lastRun >= 15)
            {
                *dst_p = 15 << 4;
                dst_p++;
                lastRun -= 15;
                if (lastRun > 254)
                {
                    while (true)
                    {
                        *dst_p = 255;
                        dst_p++;
                        lastRun -= 255;
                        if (lastRun > 254) continue;
                        break;
                    }
                }

                *dst_p = (byte)lastRun;
            }
            else
            {
                *dst_p = (byte)(lastRun << 4);
            }

            BlockCopy32(++dst_p, src_anchor, srcRestLength);
            // End
            return (int)(dst_p + srcRestLength - dst);
        }
    }

    private static unsafe void CopyLiterals(byte* src, byte* dst, int dst_length)
    {
        var p = dst + dst_length;
        while (true)
        {
            *(ulong*)dst = *(ulong*)src;
            dst += 8;
            src += 8;
            if (dst < p) continue;
            break;
        }
    }

    public static unsafe int Decompress(
        byte* src,
        byte* dst,
        int dst_len)
    {
        unchecked
        {
            fixed (void* decoder = &DECODER_TABLE_32[0])
            {
                byte* decoder_table = (byte*)decoder;
                var src_p = src;
                byte* xxx_ref;

                var dst_p = dst;
                var dst_end = dst + dst_len;
                byte* dst_cpy;

                uint xxx_token;
                int length, len;
                int isError;

                // Main Loop
                while (true)
                {
                    // get run length
                    xxx_token = *src_p;
                    src_p++;
                    if ((length = (int)(xxx_token >> 4)) == 15)
                    {
                        while (true)
                        {
                            length += (len = *src_p++);
                            if (len == 255) continue;
                            break;
                        }
                    }

                    // copy literals
                    if ((dst_cpy = dst_p + length) + 8 > dst_end)
                    {
                        if (dst_cpy == dst_end)
                        {
                            BlockCopy32(dst_p, src_p, length);
                            src_p += length;
                            isError = 0;
                        }
                        else
                        {
                            // Error : not enough place for another match (min 4) + 5 literals
                            isError = 1;
                        }

                        goto leave_main_loop;
                        // EOF
                    }

                    while (true)
                    {
                        *(uint*)dst_p = *(uint*)src_p;
                        *(uint*)(dst_p += 4) = *(uint*)(src_p += 4);
                        src_p += 4;
                        if ((dst_p += 4) < dst_cpy) continue;
                        break;
                    }
                    src_p -= dst_p - dst_cpy;
                    dst_p = dst_cpy;

                    // get offset
                    xxx_ref = dst_cpy - *(ushort*)src_p;
                    src_p += 2;
                    if (xxx_ref < dst)
                    {
                        // Error : offset outside destination buffer
                        isError = 1;
                        goto leave_main_loop;
                    }

                    // get match length
                    if ((length = (int)(xxx_token & 15)) == 15)
                    {
                        if (*src_p == 255)
                        {
                            while (true)
                            {
                                length += 255;
                                if (*++src_p == 255) continue;
                                break;
                            }
                        }

                        length += *src_p;
                        src_p++;
                    }

                    // copy repeated sequence
                    if (dst_p - xxx_ref < 4)
                    {
                        dst_p[0] = xxx_ref[0];
                        dst_p[1] = xxx_ref[1];
                        dst_p[2] = xxx_ref[2];
                        dst_p[3] = xxx_ref[3];
                        xxx_ref += 4;
                        dst_p += 4;
                        xxx_ref = xxx_ref - *(int*)(decoder_table + ((dst_p - xxx_ref) << 2));
                        *(uint*)dst_p = *(uint*)xxx_ref;
                    }
                    else
                    {
                        *(uint*)dst_p = *(uint*)xxx_ref;
                        dst_p += 4;
                        xxx_ref += 4;
                    }

                    if ((dst_cpy = dst_p + length) + 8 <= dst_end)
                    {
                        while (true)
                        {
                            *(uint*)dst_p = *(uint*)xxx_ref;
                            *(uint*)(dst_p += 4) = *(uint*)(xxx_ref += 4);
                            xxx_ref += 4;
                            if ((dst_p += 4) < dst_cpy) continue;
                            break;
                        }

                        dst_p = dst_cpy; // correction
                    }
                    else
                    {
                        if (dst_cpy + 5 <= dst_end)
                        {
                            while (true)
                            {
                                *(uint*)dst_p = *(uint*)xxx_ref;
                                *(uint*)(dst_p += 4) = *(uint*)(xxx_ref += 4);
                                xxx_ref += 4;
                                if ((dst_p += 4) + 8 < dst_end) continue;
                                break;
                            }

                            if (dst_p < dst_cpy)
                            {
                                while (true)
                                {
                                    *dst_p = *xxx_ref;
                                    xxx_ref++;
                                    if (++dst_p < dst_cpy) continue;
                                    break;
                                }
                            }

                            dst_p = dst_cpy;
                        }
                        else
                        {
                            // Error : last 5 bytes must be literals
                            isError = 1;
                            goto leave_main_loop;
                        }
                    }

                    continue;
                } // leave_main_loop

            leave_main_loop:
                if (isError == 1)
                {
                    return (int)(src - src_p);
                }
                else
                {
                    return (int)(src_p - src);
                }
            }
        }
    }
}

public static class Original
{
    public static unsafe int Compress(byte[] src, byte[] dst)
    {
        fixed (byte* s = &src[0])
        fixed (byte* d = &dst[0])
        {
            var dm = MaxCount(src.Length);
            if (src.Length < 0x1000b)
            {
                ClearTableSmall();
                return CompressSmall64K(s, d, src.Length, dm);
            }
            else
            {
                ClearTableBig();
                return CompressBig(s, d, src.Length, dm);
            }
        }
    }
    
    public static unsafe int CompressBig(
        byte* src,
        byte* dst,
        int src_len,
        int dst_maxlen)
    {
        unchecked
        {
            byte* _p;
            var src_p = src;
            var src_base = src_p;
            var src_anchor = src_p;
            var src_end = src_p + src_len;
            var src_mflimit = src_end - MFLIMIT;

            var dst_p = dst;
            var dst_end = dst_p + dst_maxlen;

            var src_LASTLITERALS = src_end - 5;
            var src_LASTLITERALS_1 = src_LASTLITERALS - 1;

            var src_LASTLITERALS_STEPSIZE_1 = src_LASTLITERALS - (4 - 1);
            var dst_LASTLITERALS_1 = dst_end - (1 + 5);
            var dst_LASTLITERALS_3 = dst_end - (2 + 1 + 5);

            // Init
            if (src_len < MINLENGTH)
            {
                goto _last_literals;
            }

            // First Byte
            HashtableBig[(*(uint*)src_p * 2654435761u) >> 22] = (uint)(src_p - src_base);
            src_p++;
            var h_fwd = (*(uint*)src_p * 2654435761u) >> 22;

            // Main Loop
            while (true)
            {
                var findMatchAttempts = (1 << SKIPSTRENGTH) + 3;
                var src_p_fwd = src_p;
                byte* xxx_ref;
                byte* xxx_token;

                // Find a match
                uint h;
                do
                {
                    h = h_fwd;
                    var step = findMatchAttempts++ >> SKIPSTRENGTH;
                    src_p = src_p_fwd;
                    src_p_fwd = src_p + step;

                    if (src_p_fwd > src_mflimit)
                    {
                        goto _last_literals;
                    }

                    h_fwd = (*(uint*)src_p_fwd * 2654435761u) >> 22;
                    xxx_ref = src_base + HashtableBig[h];
                    HashtableBig[h] = (uint)(src_p - src_base);
                }
                while ((xxx_ref < src_p - MAX_DISTANCE) || ((*(uint*)xxx_ref) != (*(uint*)src_p)));

                // Catch up
                while ((src_p > src_anchor) && (xxx_ref > src) && (src_p[-1] == xxx_ref[-1]))
                {
                    src_p--;
                    xxx_ref--;
                }

                // Encode Literal length
                var length = (int)(src_p - src_anchor);
                xxx_token = dst_p++;

                if (dst_p + length + (length >> 8) > dst_LASTLITERALS_3)
                {
                    return 0; // Check output limit
                }

                if (length >= 15)
                {
                    var len = length - 15;
                    *xxx_token = 15 << 4;
                    if (len > 254)
                    {
                        do
                        {
                            *dst_p++ = 255;
                            len -= 255;
                        }
                        while (len > 254);
                        *dst_p++ = (byte)len;
                        BlockCopy32(dst_p, src_anchor, length);
                        dst_p += length;
                        goto _next_match;
                    }

                    *dst_p++ = (byte)len;
                }
                else
                {
                    *xxx_token = (byte)(length << 4);
                }

                // Copy Literals
                _p = dst_p + length;
                do
                {
                    *(uint*)dst_p = *(uint*)src_anchor;
                    dst_p += 4;
                    src_anchor += 4;
                    *(uint*)dst_p = *(uint*)src_anchor;
                    dst_p += 4;
                    src_anchor += 4;
                }
                while (dst_p < _p);
                dst_p = _p;

            _next_match:

                // Encode Offset
                *(ushort*)dst_p = (ushort)(src_p - xxx_ref);
                dst_p += 2;

                // Start Counting
                src_p += MINMATCH;
                xxx_ref += MINMATCH; // MinMatch already verified
                src_anchor = src_p;

                while (src_p < src_LASTLITERALS_STEPSIZE_1)
                {
                    var diff = (*(int*)xxx_ref) ^ (*(int*)src_p);
                    if (diff == 0)
                    {
                        src_p += 4;
                        xxx_ref += 4;
                        continue;
                    }

                    src_p += DEBRUIJN_TABLE_32[((uint)(diff & -diff) * 0x077CB531u) >> 27];
                    goto _endCount;
                }

                if ((src_p < src_LASTLITERALS_1) && ((*(ushort*)xxx_ref) == (*(ushort*)src_p)))
                {
                    src_p += 2;
                    xxx_ref += 2;
                }

                if ((src_p < src_LASTLITERALS) && (*xxx_ref == *src_p))
                {
                    src_p++;
                }

            _endCount:

                // Encode MatchLength
                length = (int)(src_p - src_anchor);

                if (dst_p + (length >> 8) > dst_LASTLITERALS_1)
                {
                    return 0; // Check output limit
                }

                if (length >= 15)
                {
                    *xxx_token += 15;
                    length -= 15;
                    for (; length > 509; length -= 510)
                    {
                        *dst_p++ = 255;
                        *dst_p++ = 255;
                    }

                    if (length > 254)
                    {
                        length -= 255;
                        *dst_p++ = 255;
                    }

                    *dst_p++ = (byte)length;
                }
                else
                {
                    *xxx_token += (byte)length;
                }

                // Test end of chunk
                if (src_p > src_mflimit)
                {
                    src_anchor = src_p;
                    break;
                }

                // Fill table
                HashtableBig[(*(uint*)(src_p - 2) * 2654435761u) >> 22] = (uint)(src_p - 2 - src_base);

                // Test next position
                h = (*(uint*)src_p * 2654435761u) >> 22;
                xxx_ref = src_base + HashtableBig[h];
                HashtableBig[h] = (uint)(src_p - src_base);

                if ((xxx_ref > src_p - (MAX_DISTANCE + 1)) && ((*(uint*)xxx_ref) == (*(uint*)src_p)))
                {
                    xxx_token = dst_p++;
                    *xxx_token = 0;
                    goto _next_match;
                }

                // Prepare next loop
                src_anchor = src_p++;
                h_fwd = (*(uint*)src_p * 2654435761u) >> 22;
            }

        _last_literals:

            // Encode Last Literals
            {
                var lastRun = (int)(src_end - src_anchor);

                if (dst_p + lastRun + 1 + ((lastRun + 255 - 15) / 255) > dst_end)
                {
                    return 0;
                }

                if (lastRun >= 15)
                {
                    *dst_p++ = 15 << 4;
                    lastRun -= 15;
                    for (; lastRun > 254; lastRun -= 255)
                    {
                        *dst_p++ = 255;
                    }

                    *dst_p++ = (byte)lastRun;
                }
                else
                {
                    *dst_p++ = (byte)(lastRun << 4);
                }

                BlockCopy32(dst_p, src_anchor, (int)(src_end - src_anchor));
                dst_p += src_end - src_anchor;
            }

            // End
            return (int)(dst_p - dst);
        }
    }

    public static unsafe int CompressSmall64K(
        byte* src,
        byte* dst,
        int src_len,
        int dst_maxlen)
    {
        unchecked
        {
            byte* _p;
            var src_p = src;
            var src_anchor = src_p;
            var src_base = src_p;
            var src_end = src_p + src_len;
            var src_mflimit = src_end - MFLIMIT;

            var dst_p = dst;
            var dst_end = dst_p + dst_maxlen;

            var src_LASTLITERALS = src_end - 5;
            var src_LASTLITERALS_1 = src_LASTLITERALS - 1;

            var src_LASTLITERALS_STEPSIZE_1 = src_LASTLITERALS - (4 - 1);
            var dst_LASTLITERALS_1 = dst_end - (1 + 5);
            var dst_LASTLITERALS_3 = dst_end - (2 + 1 + 5);

            int len, length;

            uint h, h_fwd;

            // Init
            if (src_len < MINLENGTH)
            {
                goto _last_literals;
            }

            // First Byte
            src_p++;
            h_fwd = (*(uint*)src_p * 2654435761u) >> 21;

            // Main Loop
            while (true)
            {
                var findMatchAttempts = (1 << SKIPSTRENGTH) + 3;
                var src_p_fwd = src_p;
                byte* xxx_ref;
                byte* xxx_token;

                // Find a match
                do
                {
                    h = h_fwd;
                    var step = findMatchAttempts++ >> SKIPSTRENGTH;
                    src_p = src_p_fwd;
                    src_p_fwd = src_p + step;

                    if (src_p_fwd > src_mflimit)
                    {
                        goto _last_literals;
                    }

                    h_fwd = (*(uint*)src_p_fwd * 2654435761u) >> 21;
                    xxx_ref = src_base + HashtableSmall[h];
                    HashtableSmall[h] = (ushort)(src_p - src_base);
                }
                while ((*(uint*)xxx_ref) != (*(uint*)src_p));

                // Catch up
                while ((src_p > src_anchor) && (xxx_ref > src) && (src_p[-1] == xxx_ref[-1]))
                {
                    src_p--;
                    xxx_ref--;
                }

                // Encode Literal length
                length = (int)(src_p - src_anchor);
                xxx_token = dst_p++;

                if (dst_p + length + (length >> 8) > dst_LASTLITERALS_3)
                {
                    return 0; // Check output limit
                }

                if (length >= 15)
                {
                    len = length - 15;
                    *xxx_token = 15 << 4;
                    if (len > 254)
                    {
                        do
                        {
                            *dst_p++ = 255;
                            len -= 255;
                        }
                        while (len > 254);
                        *dst_p++ = (byte)len;
                        BlockCopy32(dst_p, src_anchor, length);
                        dst_p += length;
                        goto _next_match;
                    }

                    *dst_p++ = (byte)len;
                }
                else
                {
                    *xxx_token = (byte)(length << 4);
                }

                // Copy Literals
                _p = dst_p + length;
                do
                {
                    *(uint*)dst_p = *(uint*)src_anchor;
                    dst_p += 4;
                    src_anchor += 4;
                    *(uint*)dst_p = *(uint*)src_anchor;
                    dst_p += 4;
                    src_anchor += 4;
                }
                while (dst_p < _p);
                dst_p = _p;

            _next_match:

                // Encode Offset
                *(ushort*)dst_p = (ushort)(src_p - xxx_ref);
                dst_p += 2;

                // Start Counting
                src_p += MINMATCH;
                xxx_ref += MINMATCH; // MinMatch verified
                src_anchor = src_p;

                while (src_p < src_LASTLITERALS_STEPSIZE_1)
                {
                    var diff = (*(int*)xxx_ref) ^ (*(int*)src_p);
                    if (diff == 0)
                    {
                        src_p += 4;
                        xxx_ref += 4;
                        continue;
                    }

                    src_p += DEBRUIJN_TABLE_32[((uint)(diff & -diff) * 0x077CB531u) >> 27];
                    goto _endCount;
                }

                if ((src_p < src_LASTLITERALS_1) && ((*(ushort*)xxx_ref) == (*(ushort*)src_p)))
                {
                    src_p += 2;
                    xxx_ref += 2;
                }

                if ((src_p < src_LASTLITERALS) && (*xxx_ref == *src_p))
                {
                    src_p++;
                }

            _endCount:

                // Encode MatchLength
                len = (int)(src_p - src_anchor);

                if (dst_p + (len >> 8) > dst_LASTLITERALS_1)
                {
                    return 0; // Check output limit
                }

                if (len >= 15)
                {
                    *xxx_token += 15;
                    len -= 15;
                    for (; len > 509; len -= 510)
                    {
                        *dst_p++ = 255;
                        *dst_p++ = 255;
                    }

                    if (len > 254)
                    {
                        len -= 255;
                        *dst_p++ = 255;
                    }

                    *dst_p++ = (byte)len;
                }
                else
                {
                    *xxx_token += (byte)len;
                }

                // Test end of chunk
                if (src_p > src_mflimit)
                {
                    src_anchor = src_p;
                    break;
                }

                // Fill table
                HashtableSmall[(*(uint*)(src_p - 2) * 2654435761u) >> 21] = (ushort)(src_p - 2 - src_base);

                // Test next position
                h = (*(uint*)src_p * 2654435761u) >> 21;
                xxx_ref = src_base + HashtableSmall[h];
                HashtableSmall[h] = (ushort)(src_p - src_base);

                if ((*(uint*)xxx_ref) == (*(uint*)src_p))
                {
                    xxx_token = dst_p++;
                    *xxx_token = 0;
                    goto _next_match;
                }

                // Prepare next loop
                src_anchor = src_p++;
                h_fwd = (*(uint*)src_p * 2654435761u) >> 21;
            }

        _last_literals:

            // Encode Last Literals
            {
                var lastRun = (int)(src_end - src_anchor);
                if (dst_p + lastRun + 1 + ((lastRun - 15 + 255) / 255) > dst_end)
                {
                    return 0;
                }

                if (lastRun >= 15)
                {
                    *dst_p++ = 15 << 4;
                    lastRun -= 15;
                    for (; lastRun > 254; lastRun -= 255)
                    {
                        *dst_p++ = 255;
                    }

                    *dst_p++ = (byte)lastRun;
                }
                else
                {
                    *dst_p++ = (byte)(lastRun << 4);
                }

                BlockCopy32(dst_p, src_anchor, (int)(src_end - src_anchor));
                dst_p += src_end - src_anchor;
            }

            // End
            return (int)(dst_p - dst);
        }
    }

    public static unsafe int Decompress(
        byte* src,
        byte* dst,
        int dst_len)
    {
        unchecked
        {
            var src_p = src;
            byte* xxx_ref;

            var dst_p = dst;
            var dst_end = dst_p + dst_len;
            byte* dst_cpy;

            var dst_LASTLITERALS = dst_end - 5;
            var dst_COPYLENGTH = dst_end - 8;
            var dst_COPYLENGTH_STEPSIZE_4 = dst_end - 8 - (4 - 4);

            uint xxx_token;

            // Main Loop
            while (true)
            {
                int length;

                // get runlength
                xxx_token = *src_p++;
                if ((length = (int)(xxx_token >> 4)) == 15)
                {
                    int len;
                    for (; (len = *src_p++) == 255; length += 255)
                    {
                        /* do nothing */
                    }

                    length += len;
                }

                // copy literals
                dst_cpy = dst_p + length;

                if (dst_cpy > dst_COPYLENGTH)
                {
                    if (dst_cpy != dst_end)
                    {
                        goto _output_error; // Error : not enough place for another match (min 4) + 5 literals
                    }

                    BlockCopy32(dst_p, src_p, length);
                    src_p += length;
                    break; // EOF
                }

                do
                {
                    *(uint*)dst_p = *(uint*)src_p;
                    dst_p += 4;
                    src_p += 4;
                    *(uint*)dst_p = *(uint*)src_p;
                    dst_p += 4;
                    src_p += 4;
                }
                while (dst_p < dst_cpy);
                src_p -= dst_p - dst_cpy;
                dst_p = dst_cpy;

                // get offset
                xxx_ref = dst_cpy - (*(ushort*)src_p);
                src_p += 2;
                if (xxx_ref < dst)
                {
                    goto _output_error; // Error : offset outside destination buffer
                }

                // get matchlength
                if ((length = (int)(xxx_token & 15)) == 15)
                {
                    for (; *src_p == 255; length += 255)
                    {
                        src_p++;
                    }

                    length += *src_p++;
                }

                // copy repeated sequence
                if ((dst_p - xxx_ref) < 4)
                {
                    const int dec64 = 0;

                    dst_p[0] = xxx_ref[0];
                    dst_p[1] = xxx_ref[1];
                    dst_p[2] = xxx_ref[2];
                    dst_p[3] = xxx_ref[3];
                    dst_p += 4;
                    xxx_ref += 4;
                    xxx_ref -= DECODER_TABLE_32[dst_p - xxx_ref];
                    *(uint*)dst_p = *(uint*)xxx_ref;
                    dst_p += 4 - 4;
                    xxx_ref -= dec64;
                }
                else
                {
                    *(uint*)dst_p = *(uint*)xxx_ref;
                    dst_p += 4;
                    xxx_ref += 4;
                }

                dst_cpy = dst_p + length - (4 - 4);

                if (dst_cpy > dst_COPYLENGTH_STEPSIZE_4)
                {
                    if (dst_cpy > dst_LASTLITERALS)
                    {
                        goto _output_error; // Error : last 5 bytes must be literals
                    }

                    {
                        do
                        {
                            *(uint*)dst_p = *(uint*)xxx_ref;
                            dst_p += 4;
                            xxx_ref += 4;
                            *(uint*)dst_p = *(uint*)xxx_ref;
                            dst_p += 4;
                            xxx_ref += 4;
                        }
                        while (dst_p < dst_COPYLENGTH);
                    }

                    while (dst_p < dst_cpy)
                    {
                        *dst_p++ = *xxx_ref++;
                    }

                    dst_p = dst_cpy;
                    continue;
                }

                do
                {
                    *(uint*)dst_p = *(uint*)xxx_ref;
                    dst_p += 4;
                    xxx_ref += 4;
                    *(uint*)dst_p = *(uint*)xxx_ref;
                    dst_p += 4;
                    xxx_ref += 4;
                }
                while (dst_p < dst_cpy);
                dst_p = dst_cpy; // correction
            }

            // end of decoding
            return (int)(src_p - src);

        // write overflow error detected
        _output_error:
            return (int)-(src_p - src);
        }
    }
}