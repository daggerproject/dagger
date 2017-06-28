; RUN: opt < %s -instcombine -debug -S -o %t 2>&1 | FileCheck %s
; RUN: cat %t | FileCheck %s --check-prefix=CHECK-IR
; REQUIRES: asserts

; Debug output from InstCombine should not have any @llvm.dbg.* instructions visited
; CHECK-NOT: call void @llvm.dbg.

; The resulting IR should still have them
; CHECK-IR: call void @llvm.dbg.

define i32 @foo(i32 %j) #0 !dbg !7 {
entry:
  %j.addr = alloca i32, align 4
  store i32 %j, i32* %j.addr, align 4
  call void @llvm.dbg.declare(metadata i32* %j.addr, metadata !11, metadata !12), !dbg !13
  call void @llvm.dbg.value(metadata i32 10, i64 0, metadata !16, metadata !12), !dbg !15
  %0 = load i32, i32* %j.addr, align 4, !dbg !14
  ret i32 %0, !dbg !15
}

declare void @llvm.dbg.declare(metadata, metadata, metadata) #1
declare void @llvm.dbg.value(metadata, i64, metadata, metadata) #1

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4, !5}
!llvm.ident = !{!6}

!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "clang 5.0.0", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug)
!1 = !DIFile(filename: "a.c", directory: "/tmp")
!2 = !{}
!3 = !{i32 2, !"Dwarf Version", i32 4}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = !{i32 1, !"PIC Level", i32 2}
!6 = !{!"clang version 5.0.0 (trunk 302918) (llvm/trunk 302925)"}
!7 = distinct !DISubprogram(name: "foo", scope: !1, file: !1, line: 2, type: !8, isLocal: false, isDefinition: true, scopeLine: 3, flags: DIFlagPrototyped, isOptimized: false, unit: !0, variables: !2)
!8 = !DISubroutineType(types: !9)
!9 = !{!10, !10}
!10 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!11 = !DILocalVariable(name: "j", arg: 1, scope: !7, file: !1, line: 2, type: !10)
!12 = !DIExpression()
!13 = !DILocation(line: 2, column: 13, scope: !7)
!14 = !DILocation(line: 5, column: 10, scope: !7)
!15 = !DILocation(line: 5, column: 3, scope: !7)
!16 = !DILocalVariable(name: "h", scope: !7, file: !1, line: 4, type: !10)
