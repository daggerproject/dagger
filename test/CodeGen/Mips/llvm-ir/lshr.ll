; RUN: llc < %s -march=mips -mcpu=mips2 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP32 \
; RUN:    -check-prefix=M2
; RUN: llc < %s -march=mips -mcpu=mips32 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP32 \
; RUN:    -check-prefix=32R1-R5
; RUN: llc < %s -march=mips -mcpu=mips32r2 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP32 \
; RUN:    -check-prefix=32R1-R5
; RUN: llc < %s -march=mips -mcpu=mips32r3 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP32 \
; RUN:    -check-prefix=32R1-R5
; RUN: llc < %s -march=mips -mcpu=mips32r5 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP32 \
; RUN:    -check-prefix=32R1-R5
; RUN: llc < %s -march=mips -mcpu=mips32r6 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP32 \
; RUN:    -check-prefix=32R6
; RUN: llc < %s -march=mips64 -mcpu=mips3 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP64 \
; RUN:    -check-prefix=M3
; RUN: llc < %s -march=mips64 -mcpu=mips4 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP64 \
; RUN:    -check-prefix=GP64-NOT-R6
; RUN: llc < %s -march=mips64 -mcpu=mips64 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP64 \
; RUN:    -check-prefix=GP64-NOT-R6
; RUN: llc < %s -march=mips64 -mcpu=mips64r2 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP64 \
; RUN:    -check-prefix=GP64-NOT-R6
; RUN: llc < %s -march=mips64 -mcpu=mips64r3 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP64 \
; RUN:    -check-prefix=GP64-NOT-R6
; RUN: llc < %s -march=mips64 -mcpu=mips64r5 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP64 \
; RUN:    -check-prefix=GP64-NOT-R6
; RUN: llc < %s -march=mips64 -mcpu=mips64r6 -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=GP64 \
; RUN:    -check-prefix=64R6
; RUN: llc < %s -march=mips -mcpu=mips32r3 -mattr=+micromips -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=MM -check-prefix=MMR3
; RUN: llc < %s -march=mips -mcpu=mips32r6 -mattr=+micromips -relocation-model=pic | FileCheck %s \
; RUN:    -check-prefix=ALL -check-prefix=MM -check-prefix=MMR6

define signext i1 @lshr_i1(i1 signext %a, i1 signext %b) {
entry:
; ALL-LABEL: lshr_i1:

  ; ALL:        move    $2, $4

  %r = lshr i1 %a, %b
  ret i1 %r
}

define zeroext i8 @lshr_i8(i8 zeroext %a, i8 zeroext %b) {
entry:
; ALL-LABEL: lshr_i8:

  ; ALL:        srlv    $[[T0:[0-9]+]], $4, $5
  ; GP32:       andi    $2, $[[T0]], 255
  ; GP64:       andi    $2, $[[T0]], 255
  ; MM:         andi16  $2, $[[T0]], 255

  %r = lshr i8 %a, %b
  ret i8 %r
}

define zeroext i16 @lshr_i16(i16 zeroext %a, i16 zeroext %b) {
entry:
; ALL-LABEL: lshr_i16:

  ; ALL:        srlv    $[[T0:[0-9]+]], $4, $5
  ; GP32:       andi    $2, $[[T0]], 65535
  ; GP64:       andi    $2, $[[T0]], 65535
  ; MM:         andi16  $2, $[[T0]], 65535

  %r = lshr i16 %a, %b
  ret i16 %r
}

define signext i32 @lshr_i32(i32 signext %a, i32 signext %b) {
entry:
; ALL-LABEL: lshr_i32:

  ; ALL:          srlv    $2, $4, $5

  %r = lshr i32 %a, %b
  ret i32 %r
}

define signext i64 @lshr_i64(i64 signext %a, i64 signext %b) {
entry:
; ALL-LABEL: lshr_i64:

  ; M2:         srlv      $[[T0:[0-9]+]], $4, $7
  ; M2:         andi      $[[T1:[0-9]+]], $7, 32
  ; M2:         bnez      $[[T1]], $[[BB0:BB[0-9_]+]]
  ; M2:         move      $3, $[[T0]]
  ; M2:         srlv      $[[T2:[0-9]+]], $5, $7
  ; M2:         not       $[[T3:[0-9]+]], $7
  ; M2:         sll       $[[T4:[0-9]+]], $4, 1
  ; M2:         sllv      $[[T5:[0-9]+]], $[[T4]], $[[T3]]
  ; M2:         or        $3, $[[T3]], $[[T2]]
  ; M2:         $[[BB0]]:
  ; M2:         bnez      $[[T1]], $[[BB1:BB[0-9_]+]]
  ; M2:         addiu     $2, $zero, 0
  ; M2:         move      $2, $[[T0]]
  ; M2:         $[[BB1]]:
  ; M2:         jr        $ra
  ; M2:         nop

  ; 32R1-R5:    srlv      $[[T0:[0-9]+]], $5, $7
  ; 32R1-R5:    not       $[[T1:[0-9]+]], $7
  ; 32R1-R5:    sll       $[[T2:[0-9]+]], $4, 1
  ; 32R1-R5:    sllv      $[[T3:[0-9]+]], $[[T2]], $[[T1]]
  ; 32R1-R5:    or        $3, $[[T3]], $[[T0]]
  ; 32R1-R5:    srlv      $[[T4:[0-9]+]], $4, $7
  ; 32R1-R5:    andi      $[[T5:[0-9]+]], $7, 32
  ; 32R1-R5:    movn      $3, $[[T4]], $[[T5]]
  ; 32R1-R5:    jr        $ra
  ; 32R1-R5:    movn      $2, $zero, $[[T5]]

  ; 32R6:       srlv      $[[T0:[0-9]+]], $5, $7
  ; 32R6:       not       $[[T1:[0-9]+]], $7
  ; 32R6:       sll       $[[T2:[0-9]+]], $4, 1
  ; 32R6:       sllv      $[[T3:[0-9]+]], $[[T2]], $[[T1]]
  ; 32R6:       or        $[[T4:[0-9]+]], $[[T3]], $[[T0]]
  ; 32R6:       andi      $[[T5:[0-9]+]], $7, 32
  ; 32R6:       seleqz    $[[T6:[0-9]+]], $[[T4]], $[[T3]]
  ; 32R6:       srlv      $[[T7:[0-9]+]], $4, $7
  ; 32R6:       selnez    $[[T8:[0-9]+]], $[[T7]], $[[T5]]
  ; 32R6:       or        $3, $[[T8]], $[[T6]]
  ; 32R6:       jr        $ra
  ; 32R6:       seleqz    $2, $[[T7]], $[[T5]]

  ; GP64:         dsrlv   $2, $4, $5

  ; MMR3:       srlv      $[[T0:[0-9]+]], $5, $7
  ; MMR3:       sll16     $[[T1:[0-9]+]], $4, 1
  ; MMR3:       not16     $[[T2:[0-9]+]], $7
  ; MMR3:       sllv      $[[T3:[0-9]+]], $[[T1]], $[[T2]]
  ; MMR3:       or16      $[[T4:[0-9]+]], $[[T0]]
  ; MMR3:       srlv      $[[T5:[0-9]+]], $4, $7
  ; MMR3:       andi16    $[[T6:[0-9]+]], $7, 32
  ; MMR3:       movn      $[[T7:[0-9]+]], $[[T5]], $[[T6]]
  ; MMR3:       lui       $[[T8:[0-9]+]], 0
  ; MMR3:       movn      $2, $[[T8]], $[[T6]]

  ; MMR6:       srlv      $[[T0:[0-9]+]], $5, $7
  ; MMR6:       not       $[[T1:[0-9]+]], $7
  ; MMR6:       sll16     $[[T2:[0-9]+]], $4, 1
  ; MMR6:       sllv      $[[T3:[0-9]+]], $[[T2]], $[[T1]]
  ; MMR6:       or16      $[[T4:[0-9]+]], $[[T0]]
  ; MMR6:       andi16    $[[T5:[0-9]+]], $7, 32
  ; MMR6:       seleqz    $[[T6:[0-9]+]], $[[T4]], $[[T5]]
  ; MMR6:       srlv      $[[T7:[0-9]+]], $4, $7
  ; MMR6:       selnez    $[[T8:[0-9]+]], $[[T7]], $[[T5]]
  ; MMR6:       or        $3, $[[T8]], $[[T6]]
  ; MMR6:       seleqz    $2, $[[T7]], $[[T5]]

  %r = lshr i64 %a, %b
  ret i64 %r
}

define signext i128 @lshr_i128(i128 signext %a, i128 signext %b) {
entry:
; ALL-LABEL: lshr_i128:

  ; GP32:         lw      $25, %call16(__lshrti3)($gp)

  ; M3:             sll       $[[T0:[0-9]+]], $7, 0
  ; M3:             dsrlv     $[[T1:[0-9]+]], $4, $7
  ; M3:             andi      $[[T2:[0-9]+]], $[[T0]], 64
  ; M3:             bnez      $[[T3:[0-9]+]], $[[BB0:BB[0-9_]+]]
  ; M3:             move      $3, $[[T1]]
  ; M3:             dsrlv     $[[T4:[0-9]+]], $5, $7
  ; M3:             dsll      $[[T5:[0-9]+]], $4, 1
  ; M3:             not       $[[T6:[0-9]+]], $[[T0]]
  ; M3:             dsllv     $[[T7:[0-9]+]], $[[T5]], $[[T6]]
  ; M3:             or        $3, $[[T7]], $[[T4]]
  ; M3:             $[[BB0]]:
  ; M3:             bnez      $[[T3]], $[[BB1:BB[0-9_]+]]
  ; M3:             daddiu    $2, $zero, 0
  ; M3:             move      $2, $[[T1]]
  ; M3:             $[[BB1]]:
  ; M3:             jr        $ra
  ; M3:             nop

  ; GP64-NOT-R6:    dsrlv     $[[T0:[0-9]+]], $5, $7
  ; GP64-NOT-R6:    dsll      $[[T1:[0-9]+]], $4, 1
  ; GP64-NOT-R6:    sll       $[[T2:[0-9]+]], $7, 0
  ; GP64-NOT-R6:    not       $[[T3:[0-9]+]], $[[T2]]
  ; GP64-NOT-R6:    dsllv     $[[T4:[0-9]+]], $[[T1]], $[[T3]]
  ; GP64-NOT-R6:    or        $3, $[[T4]], $[[T0]]
  ; GP64-NOT-R6:    dsrlv     $2, $4, $7
  ; GP64-NOT-R6:    andi      $[[T5:[0-9]+]], $[[T2]], 64
  ; GP64-NOT-R6:    movn      $3, $2, $[[T5]]
  ; GP64-NOT-R6:    jr        $ra
  ; GP64-NOT-R6:    movn      $2, $zero, $1

  ; 64R6:           dsrlv     $[[T0:[0-9]+]], $5, $7
  ; 64R6:           dsll      $[[T1:[0-9]+]], $4, 1
  ; 64R6:           sll       $[[T2:[0-9]+]], $7, 0
  ; 64R6:           not       $[[T3:[0-9]+]], $[[T2]]
  ; 64R6:           dsllv     $[[T4:[0-9]+]], $[[T1]], $[[T3]]
  ; 64R6:           or        $[[T5:[0-9]+]], $[[T4]], $[[T0]]
  ; 64R6:           andi      $[[T6:[0-9]+]], $[[T2]], 64
  ; 64R6:           sll       $[[T7:[0-9]+]], $[[T6]], 0
  ; 64R6:           seleqz    $[[T8:[0-9]+]], $[[T5]], $[[T7]]
  ; 64R6:           dsrlv     $[[T9:[0-9]+]], $4, $7
  ; 64R6:           selnez    $[[T10:[0-9]+]], $[[T9]], $[[T7]]
  ; 64R6:           or        $3, $[[T10]], $[[T8]]
  ; 64R6:           jr        $ra
  ; 64R6:           seleqz    $2, $[[T9]], $[[T7]]

  ; MM:             lw        $25, %call16(__lshrti3)($2)

  %r = lshr i128 %a, %b
  ret i128 %r
}
