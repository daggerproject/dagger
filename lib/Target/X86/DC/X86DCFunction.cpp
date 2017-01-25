//===-- X86DCFunction.cpp - X86 Function Translation ------------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "X86DCFunction.h"

using namespace llvm;

X86DCFunction::X86DCFunction(DCModule &DCM, const MCFunction &MCF)
    : DCFunction(DCM, MCF) {}
