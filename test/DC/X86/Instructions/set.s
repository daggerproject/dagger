# RUN: llvm-mc -triple x86_64--darwin -filetype=obj -o - %s | llvm-dec - -dc-translate-unknown-to-undef -enable-dc-reg-mock-intrin | FileCheck %s

# XFAIL: *

## SETAEm
setae	2(%r11,%rbx,2)
## SETAEr
setae	%bpl
## SETAm
seta	2(%r11,%rbx,2)
## SETAr
seta	%bpl
## SETBEm
setbe	2(%r11,%rbx,2)
## SETBEr
setbe	%bpl
## SETBm
setb	2(%r11,%rbx,2)
## SETBr
setb	%bpl
## SETEm
sete	2(%r11,%rbx,2)
## SETEr
sete	%bpl
## SETGEm
setge	2(%r11,%rbx,2)
## SETGEr
setge	%bpl
## SETGm
setg	2(%r11,%rbx,2)
## SETGr
setg	%bpl
## SETLEm
setle	2(%r11,%rbx,2)
## SETLEr
setle	%bpl
## SETLm
setl	2(%r11,%rbx,2)
## SETLr
setl	%bpl
## SETNEm
setne	2(%r11,%rbx,2)
## SETNEr
setne	%bpl
## SETNOm
setno	2(%r11,%rbx,2)
## SETNOr
setno	%bpl
## SETNPm
setnp	2(%r11,%rbx,2)
## SETNPr
setnp	%bpl
## SETNSm
setns	2(%r11,%rbx,2)
## SETNSr
setns	%bpl
## SETOm
seto	2(%r11,%rbx,2)
## SETOr
seto	%bpl
## SETPm
setp	2(%r11,%rbx,2)
## SETPr
setp	%bpl
## SETSm
sets	2(%r11,%rbx,2)
## SETSr
sets	%bpl
retq
