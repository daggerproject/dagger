; RUN: llvm-mc -triple aarch64-apple-ios -filetype=obj -o - %s | llvm-dec - -dc-translate-unknown-to-undef -enable-dc-reg-mock-intrin | FileCheck %s

;; CBZW
; CHECK-LABEL: call void @llvm.dc.startinst
; CHECK-NEXT: [[PC_0:%.+]] = call i64 @llvm.dc.getreg.i64(metadata !"PC")
; CHECK-NEXT: [[V0:%.+]] = add i64 [[PC_0]], 4
; CHECK-NEXT: call void @llvm.dc.setreg{{.*}} !"PC")
; CHECK-NEXT: [[W16_0:%.+]] = call i32 @llvm.dc.getreg.i32(metadata !"W16")
; CHECK-NEXT: call void @llvm.trap()
; CHECK-NEXT: unreachable
; CHECK-NEXT: 
; CHECK-NEXT: bb_4:                                             ; No predecessors!
; CHECK-NEXT: call void @llvm.dc.setreg{{.*}} !"PC")
cbz	w16, #0

;; CBZX
; CHECK-LABEL: call void @llvm.dc.startinst
; CHECK-NEXT: [[PC_0:%.+]] = call i64 @llvm.dc.getreg.i64(metadata !"PC")
; CHECK-NEXT: [[V0:%.+]] = add i64 [[PC_0]], 4
; CHECK-NEXT: call void @llvm.dc.setreg{{.*}} !"PC")
; CHECK-NEXT: [[X16_0:%.+]] = call i64 @llvm.dc.getreg.i64(metadata !"X16")
; CHECK-NEXT: call void @llvm.trap()
; CHECK-NEXT: unreachable
; CHECK-NEXT: 
; CHECK-NEXT: bb_8:                                             ; No predecessors!
; CHECK-NEXT: call void @llvm.dc.setreg{{.*}} !"PC")
cbz	x16, #0

ret
