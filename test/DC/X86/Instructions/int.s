# RUN: llvm-mc -filetype=obj -o - %s | llvm-dec - -dc-translate-unknown-to-undef -enable-dc-reg-mock-intrin | FileCheck %s

## INT
# CHECK-LABEL: call void @llvm.dc.startinst
# CHECK-NEXT: call void @llvm.trap()
# CHECK-NEXT: unreachable
int	$2

## INT3
# CHECK-LABEL: call void @llvm.dc.startinst
# CHECK-NEXT: call void @llvm.trap()
# CHECK-NEXT: unreachable
int3

## INTO
# CHECK-LABEL: call void @llvm.dc.startinst
# CHECK-NEXT: call void @llvm.trap()
# CHECK-NEXT: unreachable
into

retq
