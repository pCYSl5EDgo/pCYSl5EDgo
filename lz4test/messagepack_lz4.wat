(;
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
;)

(module
    (memory (export "mainMemory") 1)
    (global $src (export "sourceOffset") i32 (i32.const 0x10a0))
    ;; private static readonly int[] DEBRUIJN_TABLE_32 = new int[32] 32 * 4 = 128
    ;; {
    ;;     0, 0, 3, 0, 3, 1, 3, 0, 3, 2, 2, 1, 3, 2, 0, 1,
    ;;     3, 3, 1, 2, 2, 2, 2, 0, 3, 1, 2, 0, 1, 0, 1, 1,
    ;; };
    (data $DEBRUIJN_TABLE_32 (offset (i32.const 0)) "\00\00\00\00\00\00\00\00\03\00\00\00\00\00\00\00\03\00\00\00\01\00\00\00\03\00\00\00\00\00\00\00\03\00\00\00\02\00\00\00\02\00\00\00\01\00\00\00\03\00\00\00\02\00\00\00\00\00\00\00\01\00\00\00\03\00\00\00\03\00\00\00\01\00\00\00\02\00\00\00\02\00\00\00\02\00\00\00\02\00\00\00\00\00\00\00\03\00\00\00\01\00\00\00\02\00\00\00\00\00\00\00\01\00\00\00\00\00\00\00\01\00\00\00\01\00\00\00")
    ;; private static readonly int[] DECODER_TABLE_32 = new int[8] { 0, 3, 2, 3, 0, 0, 0, 0 }; = 8 * 4 = 32;
    (data $DECODER_TABLE_32 (offset (i32.const 0x80)) "\00\00\00\00\03\00\00\00\02\00\00\00\03\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00")

    (func $CalcCompressMaximumOutputLength (param $src_len i32) (result i32)
        ;; return src_len + (src_len / 255) + 16;
        local.get $src_len
        i32.const 16
        i32.add
        local.get $src_len
        i32.const 255
        i32.div_s
        i32.add
    )

    (func $Compress (param $src_len i32) (param $dst_maxlen i32) (result i32)
        (local $src_end i32)
        ;; clear hash table
        i32.const 0xa0 i32.const 0 i32.const 0x1000 memory.fill
        
        ;; src_end = src + src_len
        global.get $src local.get $src_len i32.add local.set $src_end

        ;; if (src_len < 0x1000b)
        local.get $src_len i32.const 0x1000b i32.lt_u
        ;; if params not currently supported.
        if (result i32)
            global.get $src local.get $src_len local.get $src_end local.get $src_end local.get $dst_maxlen i32.add
            call $CompressSmall
        else
            global.get $src local.get $src_len local.get $src_end local.get $src_end local.get $dst_maxlen i32.add
            call $CompressBig
        end
        return
    )

    (func $CompressBig (param $src_p i32) (param $src_len i32) (param $src_end i32) (param $dst_end i32) (result i32)
        (local $src_anchor i32)
        (local $dst_p i32)
        (local $findMatchAttempts i32)
        (local $src_p_fwd i32)
        (local $xxx_ref i32)
        (local $xxx_token i32)
        (local $h i32)
        (local $h_fwd i32)
        (local $len i32)
        (local $length i32)
        (local $diff i32)
        (local $return0 i32)
        
        ;; src_anchor = src_p;
        local.get $src_p local.set $src_anchor
        ;; dst_p = src_end;
        local.get $src_end local.set $dst_p
        ;; if (src_len >= 13)
        local.get $src_len i32.const 13 i32.ge_u
        if $before_return (result)
            ;; First Byte
            ;; *(uint*)(hash_table + CalcHash(src_p)) = (uint)(src_p - src);
            local.get $src_p i32.load i32.const 2654435761 i32.mul i32.const 22 i32.shr_u i32.const 2 i32.shl i32.const 0xa0 i32.add local.get $src_p global.get $src i32.sub i32.store
            ;; h_fwd = CalcHash(++src_p);
            local.get $src_p i32.const 1 i32.add local.tee $src_p i32.load i32.const 2654435761 i32.mul i32.const 22 i32.shr_u i32.const 2 i32.shl local.set $h_fwd

            loop $main (result)
                ;; findMatchAttempts = 67;
                i32.const 67 local.set $findMatchAttempts
                ;; src_p_fwd = src_p;
                local.get $src_p local.set $src_p_fwd

                ;; Find a match
                loop (result)
                    ;; h = h_fwd;
                    local.get $h_fwd local.set $h
                    ;; src_p_fwd = (src_p = src_p_fwd) + (findMatchAttempts++ >> 6);
                    local.get $src_p_fwd local.tee $src_p local.get $findMatchAttempts local.get $findMatchAttempts i32.const 1 i32.add local.set $findMatchAttempts i32.const 6 i32.shr_s i32.add local.set $src_p_fwd

                    ;; if (src_p_fwd + 12 > src_end) goto leave_main_loop;
                    local.get $src_p_fwd i32.const 12 i32.add local.get $src_end i32.gt_u br_if $before_return

                    ;; h_fwd = CalcHash(src_p_fwd);
                    local.get $src_p_fwd i32.load i32.const 2654435761 i32.mul i32.const 22 i32.shr_u i32.const 2 i32.shl local.set $h_fwd
                    ;; xxx_ref = src + *(uint*)(hash_table + h);
                    i32.const 0xa0 local.get $h i32.add i32.load global.get $src i32.add local.set $xxx_ref
                    ;; *(uint*)(hash_table + h) = (uint)(src_p - src);
                    i32.const 0xa0 local.get $h i32.add local.get $src_p global.get $src i32.sub i32.store

                    ;; if (xxx_ref + 0xffff < src_p) continue;
                    local.get $xxx_ref i32.const 0xffff i32.add local.get $src_p i32.lt_u br_if 0
                    ;; if (*(uint*)xxx_ref != *(uint*)src_p) continue;
                    local.get $xxx_ref i32.load local.get $src_p i32.load i32.ne br_if 0
                    ;; break;
                end

                ;; Catch up
                ;; if (src_p > src_anchor)
                local.get $src_p local.get $src_anchor i32.gt_u
                if (result)
                    ;; if (xxx_ref > src)
                    local.get $xxx_ref global.get $src i32.gt_s
                    if (result)
                        ;; if (*(src_p - 1) == *(xxx_ref - 1))
                        local.get $src_p i32.const 1 i32.sub i32.load8_u local.get $xxx_ref i32.const 1 i32.sub i32.load8_u i32.eq
                        if (result)
                            loop $catch_up (result)
                                ;; src_p--;
                                local.get $src_p i32.const 1 i32.sub local.set $src_p
                                ;; xxx_ref--;
                                local.get $xxx_ref i32.const 1 i32.sub local.set $xxx_ref

                                ;; if (src_p > src_anchor)
                                local.get $src_p local.get $src_anchor i32.gt_u
                                if (result)
                                    ;; if (xxx_ref > src)
                                    local.get $xxx_ref global.get $src i32.gt_s
                                    if (result)
                                        ;; if (*(src_p - 1) == *(xxx_ref - 1))
                                        local.get $src_p i32.const 1 i32.sub i32.load8_u local.get $xxx_ref i32.const 1 i32.sub i32.load8_u i32.eq
                                        ;; continue;
                                        br_if $catch_up
                                    end
                                end
                                ;; break;
                            end
                        end
                    end
                end

                ;; Encode Literal length
                ;; length = (int)(src_p - src_anchor);
                local.get $src_p local.get $src_anchor i32.sub local.set $length
                ;; xxx_token = dst_p;
                local.get $dst_p local.set $xxx_token

                ;; if (++dst_p + length + (length >> 8) + 8 > dst_end)
                local.get $dst_p i32.const 1 i32.add local.tee $dst_p i32.const 8 i32.add local.get $length i32.add local.get $length i32.const 8 i32.shr_u i32.add local.get $dst_end i32.gt_u
                if (result)
                    ;; return0 = 1;
                    i32.const 1 local.set $return0
                    ;; goto leave_main_loop;
                    br $before_return
                end

                ;; if (length < 15)
                local.get $length i32.const 15 i32.lt_u
                if (result)
                    ;; *xxx_token = (byte)(length << 4);
                    local.get $xxx_token local.get $length i32.const 4 i32.shl i32.store8
                    ;; CopyLiterals(src_anchor, dst_p, length);
                    local.get $src_anchor local.get $dst_p local.get $length call $CopyLiterals
                else
                    ;; *xxx_token = 240;
                    local.get $xxx_token i32.const 240 i32.store8
                    ;; if ((len = length - 15) <= 254)
                    local.get $length i32.const 15 i32.sub local.tee $len i32.const 254 i32.le_s
                    if (result)
                        ;; *dst_p = (byte)len;
                        local.get $dst_p local.get $len i32.store8
                        ;; CopyLiterals(src_anchor, ++dst_p, length);
                        local.get $src_anchor local.get $dst_p i32.const 1 i32.add local.tee $dst_p local.get $length call $CopyLiterals
                    else
                        loop (result)
                            ;; *dst_p = 255;
                            local.get $dst_p i32.const 255 i32.store8
                            ;; dst_p++;
                            local.get $dst_p i32.const 1 i32.add local.set $dst_p
                            ;; if ((len -= 255) > 254) continue;
                            local.get $len i32.const 255 i32.sub local.tee $len i32.const 254 i32.gt_s br_if 0
                            ;; break;
                        end
                        ;; *dst_p = (byte)len;
                        local.get $dst_p local.get $len i32.store8
                        ;; BlockCopy32(++dst_p, src_anchor, length);
                        local.get $dst_p i32.const 1 i32.add local.tee $dst_p local.get $src_anchor local.get $length memory.copy
                    end
                end

                ;; dst_p += length;
                local.get $dst_p local.get $length i32.add local.set $dst_p

                loop $next_match (result)
                    ;; Encode Offset
                    ;; *(ushort*)dst_p = (ushort)(src_p - xxx_ref);
                    local.get $dst_p local.get $src_p local.get $xxx_ref i32.sub i32.store16
                    ;; dst_p += 2;
                    local.get $dst_p i32.const 2 i32.add local.set $dst_p

                    ;; Start Counting
                    ;; src_p += 4;
                    local.get $src_p i32.const 4 i32.add local.set $src_p
                    ;; xxx_ref += 4; // MinMatch already verified
                    local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                    ;; src_anchor = src_p;
                    local.get $src_p local.set $src_anchor

                    block $before_end_count (result)
                        ;; if (src_p < src_end - 8)
                        local.get $src_p local.get $src_end i32.const 8 i32.sub i32.lt_u
                        if (result)
                            loop $before_end_count_loop (result)
                                ;; if ((diff = *(int*)xxx_ref ^ *(int*)src_p) == 0)
                                local.get $xxx_ref i32.load local.get $src_p i32.load i32.xor local.tee $diff i32.eqz
                                if (result)
                                    ;; xxx_ref += 4;
                                    local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                                    ;; if ((src_p += 4) < src_end - 8) continue;
                                    local.get $src_p i32.const 4 i32.add local.tee $src_p local.get $src_end i32.const 8 i32.sub i32.lt_u
                                    br_if $before_end_count_loop
                                else
                                    ;; src_p += CalcDebruijn(diff);
                                    local.get $src_p local.get $diff call $CalcDebruijn i32.add local.set $src_p
                                    ;; goto leave_to_end_count;
                                    br $before_end_count
                                end
                                ;; break;
                            end $before_end_count_loop
                        end

                        ;; if (src_p < src_end - 6)
                        local.get $src_p local.get $src_end i32.const 6 i32.sub i32.lt_u
                        if (result)
                            ;; if (*(ushort*)xxx_ref == *(ushort*)src_p)
                            local.get $xxx_ref i32.load16_u local.get $src_p i32.load16_u i32.eq
                            if (result)
                                ;; src_p += 2;
                                local.get $src_p i32.const 2 i32.add local.set $src_p
                                ;; xxx_ref += 2;
                                local.get $xxx_ref i32.const 2 i32.add local.set $xxx_ref
                            end
                        end

                        ;; if (src_p < src_end - 5)
                        local.get $src_p local.get $src_end i32.const 6 i32.sub i32.lt_u
                        if (result)
                            ;; if (*xxx_ref == *src_p)
                            local.get $xxx_ref i32.load8_u local.get $src_p i32.load8_u i32.eq
                            if (result)
                                ;; src_p++;
                                local.get $src_p i32.const 1 i32.add local.set $src_p
                            end
                        end

                        ;; break;
                    end $before_end_count

                    ;; Encode MatchLength
                    ;; if (dst_p + ((len = (int)(src_p - src_anchor)) >> 8) > dst_end - 6)
                    local.get $dst_p local.get $src_p local.get $src_anchor i32.sub local.tee $len i32.const 8 i32.shr_s i32.add local.get $dst_end i32.const 6 i32.sub i32.gt_s
                    if (result)
                        ;; return0 = 1;
                        i32.const 1
                        local.set $return0
                        ;; goto leave_main_loop;
                        br $before_return
                    end

                    ;; if (len >= 15)
                    local.get $len i32.const 15 i32.ge_s
                    if (result)
                        ;; *xxx_token += 15;
                        local.get $xxx_token local.get $xxx_token i32.load8_u i32.const 15 i32.add i32.store8
                        ;; if ((len -= 15) > 509)
                        local.get $len i32.const 15 i32.sub local.tee $len i32.const 509 i32.gt_s
                        if (result)
                            loop (result)
                                ;; *(ushort*)dst_p = 0xffff;
                                local.get $dst_p i32.const 0xffff i32.store16
                                ;; dst_p += 2;
                                local.get $dst_p i32.const 2 i32.add local.set $dst_p
                                ;; if ((len -= 510) > 509) continue;
                                local.get $len i32.const 510 i32.sub local.tee $len i32.const 509 i32.gt_s br_if 0
                                ;; break;
                            end
                        end

                        ;; if (len > 254)
                        local.get $len i32.const 254 i32.gt_s
                        if (result)
                            ;; len -= 255;
                            local.get $len i32.const 255 i32.sub local.set $len
                            ;; *dst_p = 255;
                            local.get $dst_p i32.const 255 i32.store8
                            ;; dst_p++;
                            local.get $dst_p i32.const 1 i32.add local.set $dst_p
                        end

                        ;; *dst_p = (byte)len;
                        local.get $dst_p local.get $len i32.store8
                        ;; dst_p++;
                        local.get $dst_p i32.const 1 i32.add local.set $dst_p
                    else
                        ;; *xxx_token += (byte)len;
                        local.get $xxx_token local.get $xxx_token i32.load8_u local.get $len i32.add i32.store8
                    end

                    ;; Test end of chunk
                    ;; if (src_p > src_end - 12)
                    local.get $src_p local.get $src_end i32.const 12 i32.sub i32.gt_s
                    if (result)
                        ;; src_anchor = src_p;
                        local.get $src_p local.set $src_anchor
                        ;; goto leave_main_loop;
                        br $before_return
                    end

                    ;; Fill table
                    ;; *(uint*)(hash_table + CalcHash(src_p - 2)) = (uint)(src_p - 2 - src);
                    local.get $src_p i32.const 2 i32.sub i32.load i32.const 2654435761 i32.mul i32.const 22 i32.shr_u i32.const 2 i32.shl i32.const 0xa0 i32.add
                    local.get $src_p i32.const 2 i32.sub global.get $src i32.sub
                    i32.store

                    ;; Test next position
                    ;; h = CalcHash(src_p);
                    local.get $src_p i32.load i32.const 2654435761 i32.mul i32.const 22 i32.shr_u i32.const 2 i32.shl local.set $h
                    ;; xxx_ref = src + *(uint*)(hash_table + h);
                    global.get $src i32.const 0xa0 local.get $h i32.add i32.load i32.add local.set $xxx_ref
                    ;; *(uint*)(hash_table + h) = (uint)(src_p - src);
                    i32.const 0xa0 local.get $h i32.add local.get $src_p global.get $src i32.sub i32.store

                    ;; if (xxx_ref > src_p - 0x10000)
                    local.get $xxx_ref local.get $src_p i32.const 0x10000 i32.sub i32.gt_s
                    if (result)
                        ;; if (*(uint*)xxx_ref == *(uint*)src_p)
                        local.get $xxx_ref i32.load local.get $src_p i32.load i32.eq
                        if (result)
                            ;; *(xxx_token = dst_p) = 0;
                            local.get $dst_p local.tee $xxx_token i32.const 0 i32.store8
                            ;; dst_p++;
                            local.get $dst_p i32.const 1 i32.add local.set $dst_p
                            ;; continue;
                            br $next_match
                        end
                    end
                    ;; break;
                end

                ;; Prepare next loop
                ;; src_anchor = src_p;
                local.get $src_p local.set $src_anchor
                ;; h_fwd = CalcHash(++src_p);
                local.get $src_p i32.const 1 i32.add local.tee $src_p i32.load i32.const 2654435761 i32.mul i32.const 22 i32.shr_u i32.const 2 i32.shl local.set $h_fwd
                br $main
            end $main
        end $before_return

        ;; if (return0 == 0)
        local.get $return0 i32.eqz
        if (result i32)
            ;; return LastLiterals(src_anchor, src_end, dst_p, dst_end);
            local.get $src_anchor local.get $src_end local.get $dst_p local.get $dst_end
            call $LastLiterals
        else
            i32.const 0
        end
        return
    )

    (func $CompressSmall (param $src_p i32) (param $src_len i32) (param $src_end i32) (param $dst_end i32) (result i32)
        (local $src_anchor i32)
        (local $dst_p i32)
        (local $findMatchAttempts i32)
        (local $src_p_fwd i32)
        (local $xxx_ref i32)
        (local $xxx_token i32)
        (local $h i32)
        (local $h_fwd i32)
        (local $len i32)
        (local $length i32)
        (local $diff i32)
        (local $return0 i32)
        
        ;; src_anchor = src_p;
        local.get $src_p local.set $src_anchor
        ;; dst_p = src_end;
        local.get $src_end local.set $dst_p
        ;; if (src_len >= 13)
        local.get $src_len i32.const 13 i32.ge_u
        if $before_return (result)
            ;; First Byte
            ;; h_fwd = CalcHash64K(++src_p);
            local.get $src_p i32.const 1 i32.add local.tee $src_p i32.load i32.const 2654435761 i32.mul i32.const 21 i32.shr_u i32.const 1 i32.shl local.set $h_fwd

            loop $main (result)
                ;; findMatchAttempts = 67;
                i32.const 67 local.set $findMatchAttempts
                ;; src_p_fwd = src_p;
                local.get $src_p local.set $src_p_fwd

                ;; Find a match
                loop (result)
                    ;; h = h_fwd;
                    local.get $h_fwd local.set $h
                    ;; src_p_fwd = (src_p = src_p_fwd) + (findMatchAttempts++ >> 6);
                    local.get $src_p_fwd local.tee $src_p local.get $findMatchAttempts local.get $findMatchAttempts i32.const 1 i32.add local.set $findMatchAttempts i32.const 6 i32.shr_s i32.add local.set $src_p_fwd

                    ;; if (src_p_fwd + 12 > src_end) goto leave_main_loop;
                    local.get $src_p_fwd i32.const 12 i32.add local.get $src_end i32.gt_u br_if $before_return

                    ;; h_fwd = CalcHash64K(src_p_fwd);
                    local.get $src_p_fwd i32.load i32.const 2654435761 i32.mul i32.const 21 i32.shr_u i32.const 1 i32.shl local.set $h_fwd
                    ;; xxx_ref = src + *(ushort*)(hash_table + h);
                    i32.const 0xa0 local.get $h i32.add i32.load16_u global.get $src i32.add local.set $xxx_ref
                    ;; *(ushort*)(hash_table + h) = (ushort)(src_p - src);
                    i32.const 0xa0 local.get $h i32.add local.get $src_p global.get $src i32.sub i32.store16

                    ;; if (*(uint*)xxx_ref != *(uint*)src_p) continue;
                    local.get $xxx_ref i32.load local.get $src_p i32.load i32.ne br_if 0
                    ;; break;
                end

                ;; Catch up
                ;; if (src_p > src_anchor)
                local.get $src_p local.get $src_anchor i32.gt_u
                if (result)
                    ;; if (xxx_ref > src)
                    local.get $xxx_ref global.get $src i32.gt_s
                    if (result)
                        ;; if (*(src_p - 1) == *(xxx_ref - 1))
                        local.get $src_p i32.const 1 i32.sub i32.load8_u local.get $xxx_ref i32.const 1 i32.sub i32.load8_u i32.eq
                        if (result)
                            loop $catch_up (result)
                                ;; src_p--;
                                local.get $src_p i32.const 1 i32.sub local.set $src_p
                                ;; xxx_ref--;
                                local.get $xxx_ref i32.const 1 i32.sub local.set $xxx_ref

                                ;; if (src_p > src_anchor)
                                local.get $src_p local.get $src_anchor i32.gt_u
                                if (result)
                                    ;; if (xxx_ref > src)
                                    local.get $xxx_ref global.get $src i32.gt_s
                                    if (result)
                                        ;; if (*(src_p - 1) == *(xxx_ref - 1))
                                        local.get $src_p i32.const 1 i32.sub i32.load8_u local.get $xxx_ref i32.const 1 i32.sub i32.load8_u i32.eq
                                        ;; continue;
                                        br_if $catch_up
                                    end
                                end
                                ;; break;
                            end
                        end
                    end
                end

                ;; Encode Literal length
                ;; length = (int)(src_p - src_anchor);
                local.get $src_p local.get $src_anchor i32.sub local.set $length
                ;; xxx_token = dst_p;
                local.get $dst_p local.set $xxx_token

                ;; if (++dst_p + length + (length >> 8) + 8 > dst_end)
                local.get $dst_p i32.const 1 i32.add local.tee $dst_p i32.const 8 i32.add local.get $length i32.add local.get $length i32.const 8 i32.shr_u i32.add local.get $dst_end i32.gt_u
                if (result)
                    ;; return0 = 1;
                    i32.const 1 local.set $return0
                    ;; goto leave_main_loop;
                    br $before_return
                end

                ;; if (length < 15)
                local.get $length i32.const 15 i32.lt_u
                if (result)
                    ;; *xxx_token = (byte)(length << 4);
                    local.get $xxx_token local.get $length i32.const 4 i32.shl i32.store8
                    ;; CopyLiterals(src_anchor, dst_p, length);
                    local.get $src_anchor local.get $dst_p local.get $length call $CopyLiterals
                else
                    ;; *xxx_token = 240;
                    local.get $xxx_token i32.const 240 i32.store8
                    ;; if ((len = length - 15) <= 254)
                    local.get $length i32.const 15 i32.sub local.tee $len i32.const 254 i32.le_s
                    if (result)
                        ;; *dst_p = (byte)len;
                        local.get $dst_p local.get $len i32.store8
                        ;; CopyLiterals(src_anchor, ++dst_p, length);
                        local.get $src_anchor local.get $dst_p i32.const 1 i32.add local.tee $dst_p local.get $length call $CopyLiterals
                    else
                        loop (result)
                            ;; *dst_p = 255;
                            local.get $dst_p i32.const 255 i32.store8
                            ;; dst_p++;
                            local.get $dst_p i32.const 1 i32.add local.set $dst_p
                            ;; if ((len -= 255) > 254) continue;
                            local.get $len i32.const 255 i32.sub local.tee $len i32.const 254 i32.gt_s br_if 0
                            ;; break;
                        end
                        ;; *dst_p = (byte)len;
                        local.get $dst_p local.get $len i32.store8
                        ;; BlockCopy32(++dst_p, src_anchor, length);
                        local.get $dst_p i32.const 1 i32.add local.tee $dst_p local.get $src_anchor local.get $length memory.copy
                    end
                end

                ;; dst_p += length;
                local.get $dst_p local.get $length i32.add local.set $dst_p

                loop $next_match (result)
                    ;; Encode Offset
                    ;; *(ushort*)dst_p = (ushort)(src_p - xxx_ref);
                    local.get $dst_p local.get $src_p local.get $xxx_ref i32.sub i32.store16
                    ;; dst_p += 2;
                    local.get $dst_p i32.const 2 i32.add local.set $dst_p

                    ;; Start Counting
                    ;; src_p += 4;
                    local.get $src_p i32.const 4 i32.add local.set $src_p
                    ;; xxx_ref += 4; // MinMatch already verified
                    local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                    ;; src_anchor = src_p;
                    local.get $src_p local.set $src_anchor

                    block $before_end_count (result)
                        ;; if (src_p < src_end - 8)
                        local.get $src_p local.get $src_end i32.const 8 i32.sub i32.lt_u
                        if (result)
                            loop $before_end_count_loop (result)
                                ;; if ((diff = *(int*)xxx_ref ^ *(int*)src_p) == 0)
                                local.get $xxx_ref i32.load local.get $src_p i32.load i32.xor local.tee $diff i32.eqz
                                if (result)
                                    ;; xxx_ref += 4;
                                    local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                                    ;; if ((src_p += 4) < src_end - 8) continue;
                                    local.get $src_p i32.const 4 i32.add local.tee $src_p local.get $src_end i32.const 8 i32.sub i32.lt_u
                                    br_if $before_end_count_loop
                                else
                                    ;; src_p += CalcDebruijn(diff);
                                    local.get $src_p local.get $diff call $CalcDebruijn i32.add local.set $src_p
                                    ;; goto leave_to_end_count;
                                    br $before_end_count
                                end
                                ;; break;
                            end $before_end_count_loop
                        end

                        ;; if (src_p < src_end - 6)
                        local.get $src_p local.get $src_end i32.const 6 i32.sub i32.lt_u
                        if (result)
                            ;; if (*(ushort*)xxx_ref == *(ushort*)src_p)
                            local.get $xxx_ref i32.load16_u local.get $src_p i32.load16_u i32.eq
                            if (result)
                                ;; src_p += 2;
                                local.get $src_p i32.const 2 i32.add local.set $src_p
                                ;; xxx_ref += 2;
                                local.get $xxx_ref i32.const 2 i32.add local.set $xxx_ref
                            end
                        end

                        ;; if (src_p < src_end - 5)
                        local.get $src_p local.get $src_end i32.const 6 i32.sub i32.lt_u
                        if (result)
                            ;; if (*xxx_ref == *src_p)
                            local.get $xxx_ref i32.load8_u local.get $src_p i32.load8_u i32.eq
                            if (result)
                                ;; src_p++;
                                local.get $src_p i32.const 1 i32.add local.set $src_p
                            end
                        end

                        ;; break;
                    end $before_end_count

                    ;; Encode MatchLength
                    ;; if (dst_p + ((len = (int)(src_p - src_anchor)) >> 8) > dst_end - 6)
                    local.get $dst_p local.get $src_p local.get $src_anchor i32.sub local.tee $len i32.const 8 i32.shr_s i32.add local.get $dst_end i32.const 6 i32.sub i32.gt_s
                    if (result)
                        ;; return0 = 1;
                        i32.const 1
                        local.set $return0
                        ;; goto leave_main_loop;
                        br $before_return
                    end

                    ;; if (len >= 15)
                    local.get $len i32.const 15 i32.ge_s
                    if (result)
                        ;; *xxx_token += 15;
                        local.get $xxx_token local.get $xxx_token i32.load8_u i32.const 15 i32.add i32.store8
                        ;; if ((len -= 15) > 509)
                        local.get $len i32.const 15 i32.sub local.tee $len i32.const 509 i32.gt_s
                        if (result)
                            loop (result)
                                ;; *(ushort*)dst_p = 0xffff;
                                local.get $dst_p i32.const 0xffff i32.store16
                                ;; dst_p += 2;
                                local.get $dst_p i32.const 2 i32.add local.set $dst_p
                                ;; if ((len -= 510) > 509) continue;
                                local.get $len i32.const 510 i32.sub local.tee $len i32.const 509 i32.gt_s br_if 0
                                ;; break;
                            end
                        end

                        ;; if (len > 254)
                        local.get $len i32.const 254 i32.gt_s
                        if (result)
                            ;; len -= 255;
                            local.get $len i32.const 255 i32.sub local.set $len
                            ;; *dst_p = 255;
                            local.get $dst_p i32.const 255 i32.store8
                            ;; dst_p++;
                            local.get $dst_p i32.const 1 i32.add local.set $dst_p
                        end

                        ;; *dst_p = (byte)len;
                        local.get $dst_p local.get $len i32.store8
                        ;; dst_p++;
                        local.get $dst_p i32.const 1 i32.add local.set $dst_p
                    else
                        ;; *xxx_token += (byte)len;
                        local.get $xxx_token local.get $xxx_token i32.load8_u local.get $len i32.add i32.store8
                    end

                    ;; Test end of chunk
                    ;; if (src_p > src_end - 12)
                    local.get $src_p local.get $src_end i32.const 12 i32.sub i32.gt_s
                    if (result)
                        ;; src_anchor = src_p;
                        local.get $src_p local.set $src_anchor
                        ;; goto leave_main_loop;
                        br $before_return
                    end

                    ;; Fill table
                    ;; *(ushort*)(hash_table + CalcHash64K(src_p - 2)) = (ushort)(src_p - 2 - src);
                    local.get $src_p i32.const 2 i32.sub i32.load i32.const 2654435761 i32.mul i32.const 21 i32.shr_u i32.const 1 i32.shl i32.const 0xa0 i32.add
                    local.get $src_p i32.const 2 i32.sub global.get $src i32.sub
                    i32.store16

                    ;; Test next position
                    ;; h = CalcHash64K(src_p);
                    local.get $src_p i32.load i32.const 2654435761 i32.mul i32.const 21 i32.shr_u i32.const 1 i32.shl local.set $h
                    ;; xxx_ref = src + *(ushort*)(hash_table + h);
                    global.get $src i32.const 0xa0 local.get $h i32.add i32.load16_u i32.add local.set $xxx_ref
                    ;; *(ushort*)(hash_table + h) = (ushort)(src_p - src);
                    i32.const 0xa0 local.get $h i32.add local.get $src_p global.get $src i32.sub i32.store16

                    ;; if (*(uint*)xxx_ref == *(uint*)src_p)
                    local.get $xxx_ref i32.load local.get $src_p i32.load i32.eq
                    if (result)
                        ;; *(xxx_token = dst_p) = 0;
                        local.get $dst_p local.tee $xxx_token i32.const 0 i32.store8
                        ;; dst_p++;
                        local.get $dst_p i32.const 1 i32.add local.set $dst_p
                        ;; continue;
                        br $next_match
                    end
                    ;; break;
                end

                ;; Prepare next loop
                ;; src_anchor = src_p;
                local.get $src_p local.set $src_anchor
                ;; h_fwd = CalcHash64K(++src_p);
                local.get $src_p i32.const 1 i32.add local.tee $src_p i32.load i32.const 2654435761 i32.mul i32.const 21 i32.shr_u i32.const 1 i32.shl local.set $h_fwd
                br $main
            end $main
        end $before_return

        ;; if (return0 == 0)
        local.get $return0 i32.eqz
        if (result i32)
            ;; return LastLiterals(src_anchor, src_end, dst_p, dst_end);
            local.get $src_anchor local.get $src_end local.get $dst_p local.get $dst_end
            call $LastLiterals
        else
            i32.const 0
        end
        return
    )

    (func $Decompress (param $src_len i32) (param $dst_len i32) (result i32)
        (local $src_p i32)
        (local $src_end i32)
        (local $xxx_ref i32)
        (local $xxx_token i32) ;; uint32
        (local $length i32)
        (local $len i32)
        (local $isError i32)
        (local $dst_p i32)
        (local $dst_end i32)
        (local $dst_cpy i32)

        ;; dst_end = (dst_p = src_end = (src_p = src) + src_len) + dst_len
        global.get $src local.tee $src_p local.get $src_len i32.add local.tee $src_end local.tee $dst_p local.get $dst_len i32.add local.set $dst_end

        block $return (result)
            loop $main (result)
                ;; xxx_token = *src_p;
                local.get $src_p i32.load8_u local.set $xxx_token
                ;; src_p++;
                local.get $src_p i32.const 1 i32.add local.set $src_p
                ;; if ((length = (int)(xxx_token >> 4)) == 15)
                local.get $xxx_token i32.const 4 i32.shr_u local.tee $length i32.const 15 i32.eq
                if (result)
                    loop (result)
                        ;; length += (len = *src_p++);
                        local.get $src_p local.get $src_p i32.const 1 i32.add local.set $src_p i32.load8_u local.tee $len local.get $length i32.add local.set $length
                        ;; if (len == 255) continue;
                        local.get $len i32.const 255 i32.eq br_if 0
                        ;; break;
                    end
                end

                ;; copy literals
                ;; if ((dst_cpy = dst_p + length) + 8 > dst_end)
                local.get $dst_p local.get $length i32.add local.tee $dst_cpy i32.const 8 i32.add local.get $dst_end i32.gt_s
                if (result)
                    ;; if (dst_cpy == dst_end)
                    local.get $dst_cpy local.get $dst_end i32.eq
                    if (result)
                        ;; BlockCopy32(dst_p, src_p, length);
                        local.get $dst_p local.get $src_p local.get $length memory.copy
                        ;; src_p += length;
                        local.get $src_p local.get $length i32.add local.set $src_p
                    else
                        ;; isError = 1;
                        i32.const 1 local.set $isError
                    end

                    br $return
                end

                loop (result)
                    ;; *(uint*)dst_p = *(uint*)src_p;
                    local.get $dst_p local.get $src_p i32.load i32.store
                    ;; *(uint*)(dst_p += 4) = *(uint*)(src_p += 4);
                    local.get $dst_p i32.const 4 i32.add local.tee $dst_p local.get $src_p i32.const 4 i32.add local.tee $src_p i32.load i32.store
                    ;; src_p += 4;
                    local.get $src_p i32.const 4 i32.add local.set $src_p
                    ;; if ((dst_p += 4) < dst_cpy) continue;
                    local.get $dst_p i32.const 4 i32.add local.tee $dst_p local.get $dst_cpy i32.lt_s br_if 0
                    ;; break;
                end
                ;; src_p = src_p - dst_p + dst_cpy;
                local.get $src_p local.get $dst_p i32.sub local.get $dst_cpy i32.add local.set $src_p
                ;; dst_p = dst_cpy;
                local.get $dst_cpy local.set $dst_p

                ;; get offset
                ;; xxx_ref = dst_cpy - *(ushort*)src_p;
                local.get $dst_cpy local.get $src_p i32.load16_u i32.sub local.set $xxx_ref
                ;; src_p += 2;
                local.get $src_p i32.const 2 i32.add local.set $src_p
                
                ;; if (xxx_ref < dst)
                local.get $xxx_ref local.get $src_end i32.lt_s
                if (result)
                    ;; isError = 1;
                    i32.const 1 local.set $isError
                    br $return
                end

                ;; get match length
                ;; if ((length = (int)(xxx_token & 15)) == 15)
                local.get $xxx_token i32.const 15 i32.and local.tee $length i32.const 15 i32.eq
                if (result)
                    ;; if (*src_p == 255)
                    local.get $src_p i32.load8_u i32.const 255 i32.eq
                    if (result)
                        loop (result)
                            ;; length += 255;
                            local.get $length i32.const 255 i32.add local.set $length
                            ;; if (*++src_p == 255) continue;
                            local.get $src_p i32.const 1 i32.add local.tee $src_p i32.load8_u i32.const 255 i32.eq br_if 0
                            ;; break;
                        end
                    end

                    ;; length += *src_p;
                    local.get $length local.get $src_p i32.load8_u i32.add local.set $length
                    ;; src_p++;
                    local.get $src_p i32.const 1 i32.add local.set $src_p
                end

                ;; copy repeated sequence
                ;; if (dst_p < 4 + xxx_ref)
                local.get $dst_p i32.const 4 local.get $xxx_ref i32.add i32.lt_s
                if (result)
                    ;; *dst_p = *xxx_ref;
                    local.get $dst_p local.get $xxx_ref i32.load8_u i32.store8
                    ;; dst_p[1] = xxx_ref[1];
                    local.get $dst_p local.get $xxx_ref i32.load8_u offset=1 i32.store8 offset=1
                    ;; dst_p[2] = xxx_ref[2];
                    local.get $dst_p local.get $xxx_ref i32.load8_u offset=2 i32.store8 offset=2
                    ;; dst_p[3] = xxx_ref[3];
                    local.get $dst_p local.get $xxx_ref i32.load8_u offset=3 i32.store8 offset=3
                    ;; xxx_ref += 4;
                    local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                    ;; dst_p += 4;
                    local.get $dst_p i32.const 4 i32.add local.set $dst_p
                    ;; xxx_ref = xxx_ref - *(int*)(decoder_table + ((dst_p - xxx_ref) << 2));
                    local.get $xxx_ref local.get $dst_p local.get $xxx_ref i32.sub i32.const 2 i32.shl i32.const 0x80 i32.add i32.load i32.sub local.set $xxx_ref
                    ;; *(uint*)dst_p = *(uint*)xxx_ref;
                    local.get $dst_p local.get $xxx_ref i32.load i32.store
                else
                    ;; *(uint*)dst_p = *(uint*)xxx_ref;
                    local.get $dst_p local.get $xxx_ref i32.load i32.store
                    ;; dst_p += 4;
                    local.get $dst_p i32.const 4 i32.add local.set $dst_p
                    ;; xxx_ref += 4;
                    local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                end

                ;; if ((dst_cpy = dst_p + length) + 8 <= dst_end)
                local.get $dst_p local.get $length i32.add local.tee $dst_cpy i32.const 8 i32.add local.get $dst_end i32.lt_s
                if (result)
                    loop (result)
                        ;; *(uint*)dst_p = *(uint*)xxx_ref;
                        local.get $dst_p local.get $xxx_ref i32.load i32.store
                        ;; *(uint*)(dst_p += 4) = *(uint*)(xxx_ref += 4);
                        local.get $dst_p i32.const 4 i32.add local.tee $dst_p local.get $xxx_ref i32.const 4 i32.add local.tee $xxx_ref i32.load i32.store
                        ;; xxx_ref += 4;
                        local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                        ;; if ((dst_p += 4) < dst_cpy) continue;
                        local.get $dst_p i32.const 4 i32.add local.tee $dst_p local.get $dst_cpy i32.lt_s br_if 0
                        ;; break;
                    end
                    
                    ;; dst_p = dst_cpy; // correction
                    local.get $dst_cpy local.set $dst_p
                else
                    ;; if (dst_cpy + 5 <= dst_end)
                    local.get $dst_cpy i32.const 5 i32.add local.get $dst_end i32.le_s
                    if (result)
                        loop (result)
                            ;; *(uint*)dst_p = *(uint*)xxx_ref;
                            local.get $dst_p local.get $xxx_ref i32.load i32.store
                            ;; *(uint*)(dst_p += 4) = *(uint*)(xxx_ref += 4);
                            local.get $dst_p i32.const 4 i32.add local.tee $dst_p local.get $xxx_ref i32.const 4 i32.add local.tee $xxx_ref i32.load i32.store
                            ;; xxx_ref += 4;
                            local.get $xxx_ref i32.const 4 i32.add local.set $xxx_ref
                            ;; if ((dst_p += 4) + 8 < dst_end) continue;
                            local.get $dst_p i32.const 4 i32.add local.tee $dst_p i32.const 8 i32.add local.get $dst_end i32.lt_s br_if 0
                            ;; break;
                        end

                        ;; if (dst_p < dst_cpy)
                        local.get $dst_p local.get $dst_cpy i32.lt_s
                        if (result)
                            loop (result)
                                ;; *dst_p = *xxx_ref;
                                local.get $dst_p local.get $xxx_ref i32.load8_u i32.store8
                                ;; xxx_ref++;
                                local.get $xxx_ref i32.const 1 i32.add local.set $xxx_ref
                                ;; if (++dst_p < dst_cpy) continue;
                                local.get $dst_p i32.const 1 i32.add local.tee $dst_p local.get $dst_cpy i32.lt_s br_if 0
                                ;; break;
                            end
                        end

                        ;; dst_p = dst_cpy;
                        local.get $dst_cpy local.set $dst_p
                    else
                        ;; isError = 1;
                        i32.const 1 local.set $isError
                        br $return ;; goto leave_main_loop;
                    end
                end

                ;; continue;
                br $main
            end $main
        end $return

        local.get $isError i32.eqz
        if (result i32)
            ;; return (int)(src_p - src);
            local.get $src_p global.get $src i32.sub
        else
            ;; return (int)(src - src_p);
            global.get $src local.get $src_p i32.sub
        end
        return
    )

    (func $LastLiterals (param $src_anchor i32) (param $src_end i32) (param $dst_p i32) (param $dst_end i32) (result i32)
        (local $len i32)
        (local $last i32)
        ;; var len = (int)(src_end - src_anchor);
        local.get $src_end local.get $src_anchor i32.sub local.tee $len
        ;; if (dst_p + ((len << 8) + 495) / 255 > dst_end)
        i32.const 8 i32.shl i32.const 495 i32.add i32.const 255 i32.div_s local.get $dst_p local.get $dst_end i32.gt_s
        if (result i32)
            i32.const 0
        else
            local.get $len
            local.tee $last
            i32.const 15
            i32.ge_s
            ;; if ((lastRun = len) >= 15)
            if (result)
                ;; *dst_p = 240;
                local.get $dst_p i32.const 240 i32.store8
                ;; dst_p++;
                local.get $dst_p i32.const 1 i32.add local.set $dst_p
                ;; if ((lastRun -= 15) > 254)
                local.get $last i32.const 15 i32.sub local.tee $last i32.const 254 i32.gt_s
                if (result)
                    loop (result)
                        ;; *dst_p = 255;
                        local.get $dst_p i32.const 255 i32.store8
                        ;; dst_p++;
                        local.get $dst_p i32.const 1 i32.add local.set $dst_p
                        ;; if ((lastRun -= 255) > 254) continue;
                        local.get $last i32.const 255 i32.sub local.tee $last i32.const 254 i32.gt_s
                        br_if 0
                        ;; break;
                    end
                end

                ;; *dst_p = (byte)lastRun;
                local.get $dst_p local.get $last i32.store8
            else
                ;; *dst_p = (byte)(lastRun << 4);
                local.get $dst_p local.get $last i32.const 4 i32.shl i32.store8
            end

            ;; BlockCopy32(++dst_p, src_anchor, srcRestLength);
            local.get $dst_p i32.const 1 i32.add local.tee $dst_p local.get $src_anchor local.get $len memory.copy

            ;; return (int)(dst_p + srcRestLength - dst);
            local.get $dst_p local.get $len i32.add local.get $src_end i32.sub
        end
        return
    )

    (func $CopyLiterals (param $src i32) (param $dst i32) (param $len i32) (result)
        (local $p i32)
        local.get $dst
        local.get $len
        i32.add
        local.set $p
        loop
            ;; *(ulong*)dst = *(ulong*)src;
            local.get $dst local.get $src i64.load i64.store
            ;; dst += 8;
            local.get $dst i32.const 8 i32.add local.set $dst
            ;; src += 8;
            local.get $src i32.const 8 i32.add local.set $src
            ;; if (dst < p) continue;
            local.get $dst local.get $p i32.lt_u
            br_if 0
        end
    )

    (func $CalcDebruijn (param $diff i32) (result i32)
        ;; *(int*)(DEBRUIJN_TABLE_32 + ((((uint)(diff & -diff) * 0x077CB531u) >> 27) << 2))
        local.get $diff
        ;; -diff
        i32.const 0 local.get $diff i32.sub
        i32.and
        i32.const 0x077CB531
        i32.mul
        i32.const 27
        i32.shr_u
        i32.const 2
        i32.shl
        i32.load
    )

    (export "compress" (func $Compress))
    (export "decompress" (func $Decompress))
    (export "calcCompressMaximumOutputLength" (func $CalcCompressMaximumOutputLength))
)