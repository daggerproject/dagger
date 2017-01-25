//===-- lib/DC/DCRegisterSema.cpp - DC Register Semantics -------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "llvm/DC/DCRegisterSema.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/CodeGen/ValueTypes.h"
#include "llvm/DC/DCRegisterSetDesc.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Type.h"
#include "llvm/MC/MCAnalysis/MCFunction.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>
#include <dlfcn.h>
using namespace llvm;

#define DEBUG_TYPE "dc-regsema"

static cl::opt<bool>
    EnableMockIntrin("enable-dc-reg-mock-intrin",
                     cl::desc("Mock register accesses using intrinsics"),
                     cl::init(false));

DCRegisterSema::DCRegisterSema(LLVMContext &Ctx, const MCRegisterInfo &MRI,
                               const MCInstrInfo &MII, const DataLayout &DL,
                               const DCRegisterSetDesc &RegSetDesc)
    : MRI(MRI), MII(MII), DL(DL), Ctx(Ctx), RegSetDesc(RegSetDesc),
      TheModule(0), Builder(new DCIRBuilder(Ctx)), RegPtrs(getNumRegs()),
      RegAllocas(getNumRegs()), RegInits(getNumRegs()),
      RegAssignments(getNumRegs()), TheFunction(0), RegVals(getNumRegs()),
      CurrentInst(0) {}

DCRegisterSema::~DCRegisterSema() {}

unsigned DCRegisterSema::getNumRegs() const { return getRegSetDesc().NumRegs; }

StructType *DCRegisterSema::getRegSetType() const {
  return getRegSetDesc().RegSetType;
}

void DCRegisterSema::SwitchToModule(Module *Mod) { TheModule = Mod; }

void DCRegisterSema::SwitchToFunction(Function *Fn) { TheFunction = Fn; }

void DCRegisterSema::SwitchToBasicBlock(BasicBlock *TheBB) {
  // Clear all local values.
  for (unsigned RI = 1, RE = getNumRegs(); RI != RE; ++RI) {
    RegVals[RI] = 0;
  }
  Builder->SetInsertPoint(TheBB);
}

void DCRegisterSema::SwitchToInst(const MCDecodedInst &DecodedInst) {
  CurrentInst = &DecodedInst;

  if (EnableMockIntrin) {
    Function *StartInstIntrin =
        Intrinsic::getDeclaration(TheModule, Intrinsic::dc_startinst);
    Builder->CreateCall(StartInstIntrin,
                        Builder->getInt64(CurrentInst->Address));
  }
}

void DCRegisterSema::saveAllLocalRegs(BasicBlock *BB, BasicBlock::iterator IP) {
  DCIRBuilder LocalBuilder(BB, IP);

  for (unsigned RI = 1, RE = getNumRegs(); RI != RE; ++RI) {
    if (!RegAllocas[RI])
      continue;
    int OffsetInSet = getRegSetDesc().RegOffsetsInSet[RI];
    if (OffsetInSet != -1)
      LocalBuilder.CreateStore(LocalBuilder.CreateLoad(RegAllocas[RI]),
                               RegPtrs[RI]);
  }
}

void DCRegisterSema::restoreLocalRegs(BasicBlock *BB, BasicBlock::iterator IP) {
  Builder->SetInsertPoint(BB, IP);

  for (unsigned RI = 1, RE = getNumRegs(); RI != RE; ++RI) {
    if (!RegAllocas[RI])
      continue;
    int OffsetInSet = getRegSetDesc().RegOffsetsInSet[RI];
    if (OffsetInSet != -1)
      setReg(RI, Builder->CreateLoad(RegPtrs[RI]));
  }
  saveAllLiveRegs();
}

void DCRegisterSema::saveAllLiveRegs() {
  for (unsigned RI = 1, RE = getNumRegs(); RI != RE; ++RI) {
    onRegisterGet(RI);
    if (!RegVals[RI])
      continue;
    if (RegAllocas[RI])
      Builder->CreateStore(Builder->CreateBitCast(RegVals[RI], getRegType(RI)),
                           RegAllocas[RI]);
    RegVals[RI] = 0;
  }
}

void DCRegisterSema::FinalizeFunction(BasicBlock *ExitBB) {
  saveAllLocalRegs(ExitBB, ExitBB->getTerminator()->getIterator());

  for (unsigned RI = 1, RE = getNumRegs(); RI != RE; ++RI) {
    RegAllocas[RI] = 0;
    RegPtrs[RI] = 0;
    RegInits[RI] = 0;
    RegAssignments[RI] = 0;
  }
  TheFunction = nullptr;
  Builder->ClearInsertionPoint();
}

void DCRegisterSema::FinalizeBasicBlock() {
  if (Instruction *TI = Builder->GetInsertBlock()->getTerminator())
    Builder->SetInsertPoint(TI);
  saveAllLiveRegs();
  CurrentInst = nullptr;
}

Value *DCRegisterSema::getReg(unsigned RegNo) {
  if (RegNo == 0 || RegNo > getNumRegs())
    return 0;

  if (EnableMockIntrin) {
    Value *MDRegName =
        MetadataAsValue::get(Ctx, MDString::get(Ctx, MRI.getName(RegNo)));
    Function *GetRegIntrin = Intrinsic::getDeclaration(
        TheModule, Intrinsic::dc_getreg, getRegType(RegNo));
    return Builder->CreateCall(GetRegIntrin, MDRegName);
  }

  if (Constant *C = getRegSetDesc().RegConstantVals[RegNo])
    return C;

  getRegNoCallback(RegNo);
  onRegisterGet(RegNo);
  return RegVals[RegNo];
}

Value *DCRegisterSema::getRegNoCallback(unsigned RegNo) {
  if (getRegSetDesc().RegAliased[RegNo])
    llvm_unreachable("Access to aliased registers not implemented yet");

  if (getRegSetDesc().RegConstantVals[RegNo])
    llvm_unreachable("Can't set constant register!");

  Value *&RV = RegVals[RegNo];

  // First, look for a value in this basic block.
  if (RV)
    return RV;

  // Ensure the reg has an alloca; extract it from a super if it has one.
  createLocalValueForReg(RegNo);

  // Now, we have an alloca; if we don't have the reg in this BB, load it here!
  if (!RV)
    RV = Builder->CreateLoad(RegAllocas[RegNo]);
  setRegValWithName(RegNo, RV);
  onRegisterSet(RegNo, RV);
  return RV;
}

void DCRegisterSema::setRegValWithName(unsigned RegNo, Value *Val) {
  RegVals[RegNo] = Val;
  if (!Val->hasName())
    Val->setName(
        (Twine(MRI.getName(RegNo)) + "_" + utostr(RegAssignments[RegNo]++))
            .str());
}

void DCRegisterSema::createLocalValueForReg(unsigned RegNo) {
  StringRef RegName = MRI.getName(RegNo);
  Value *&RV = RegVals[RegNo];
  AllocaInst *&RA = RegAllocas[RegNo];
  Value *&RP = RegPtrs[RegNo];
  Value *&RI = RegInits[RegNo];

  // If we already have an alloca, nothing to do here.
  if (RA)
    return;
  assert(RP == 0 && "Register has a pointer but no local value!");
  assert(RI == 0 && "Register has a start value but no local value!");
  IRBuilderBase::InsertPoint CurIP = Builder->saveIP();
  BasicBlock *EntryBB = &TheFunction->getEntryBlock();
  unsigned LargestSuper = getRegSetDesc().RegLargestSupers[RegNo];
  if (LargestSuper != RegNo) {
    // If the reg has a super-register, extract from it.
    RV = extractSubRegFromSuper(LargestSuper, RegNo);
    // Also extract from the super reg to initialize the alloca.
    Builder->SetInsertPoint(EntryBB->getTerminator());
    assert(RegInits[LargestSuper] != 0 && "Super-register non initialized!");
    RI = extractSubRegFromSuper(LargestSuper, RegNo, RegInits[LargestSuper]);
    RI = Builder->CreateBitCast(RI, getRegType(RegNo));
  } else {
    // Else, it should be in the regset, load it from there.
    Builder->SetInsertPoint(EntryBB->getTerminator());
    // First, extract the register's value from the incoming regset.
    Value *RegSetArg = &TheFunction->getArgumentList().front();
    int OffsetInRegSet = getRegSetDesc().RegOffsetsInSet[RegNo];
    assert(OffsetInRegSet != -1 && "Getting a register not in the regset!");
    Value *Idx[] = {Builder->getInt32(0), Builder->getInt32(OffsetInRegSet)};
    RP = Builder->CreateInBoundsGEP(RegSetArg, Idx);
    RP->setName((RegName + "_ptr").str());
    RI = Builder->CreateLoad(getRegType(RegNo), RP);
  }
  RI->setName((RegName + "_init").str());
  // Then, create an alloca for the register.
  RA = Builder->CreateAlloca(RI->getType());
  RA->setName(RegName);
  // Finally, initialize the local copy of the register.
  Builder->CreateStore(RI, RA);
  Builder->restoreIP(CurIP);
}

Value *DCRegisterSema::extractBitsFromValue(unsigned LoBit, unsigned NumBits,
                                            Value *Val) {
  Value *LShr =
      (LoBit == 0
           ? Val
           : Builder->CreateLShr(Val, ConstantInt::get(Val->getType(), LoBit)));
  return Builder->CreateTruncOrBitCast(LShr, IntegerType::get(Ctx, NumBits));
}

Value *DCRegisterSema::insertBitsInValue(Value *FullVal, Value *ToInsert,
                                         unsigned Offset, bool ClearOldValue) {
  IntegerType *ValType = cast<IntegerType>(FullVal->getType());
  IntegerType *ToInsertType = cast<IntegerType>(ToInsert->getType());

  Value *Cast = Builder->CreateZExtOrBitCast(ToInsert, ValType);
  if (Offset)
    Cast = Builder->CreateShl(Cast, ConstantInt::get(Cast->getType(), Offset));

  // If we clear FullVal, then this is enough, we don't need to use it.
  if (ClearOldValue)
    return Cast;

  APInt Mask = ~APInt::getBitsSet(ValType->getBitWidth(), Offset,
                                  Offset + ToInsertType->getBitWidth());
  return Builder->CreateOr(
      Cast, Builder->CreateAnd(FullVal, ConstantInt::get(ValType, Mask)));
}

Value *DCRegisterSema::extractSubRegFromSuper(unsigned Super, unsigned Sub,
                                              Value *SRV) {
  unsigned Idx = MRI.getSubRegIndex(Super, Sub);
  assert(Idx && "Superreg's subreg doesn't have an index?");
  unsigned Offset = MRI.getSubRegIdxOffset(Idx),
           Size = MRI.getSubRegIdxSize(Idx);
  if (Offset == (unsigned)-1 || Size == (unsigned)-1)
    llvm_unreachable("Used subreg index doesn't cover a bit range?");

  // If no SuperValue was provided, get the current one.
  if (SRV == 0)
    SRV = getRegAsInt(Super);
  else
    SRV = Builder->CreateBitCast(SRV, getRegIntType(Super));

  return extractBitsFromValue(Offset, Size, SRV);
}

Value *DCRegisterSema::recreateSuperRegFromSub(unsigned Super, unsigned Sub) {
  unsigned Idx = MRI.getSubRegIndex(Super, Sub);
  assert(Idx && "Superreg's subreg doesn't have an index?");
  unsigned Offset = MRI.getSubRegIdxOffset(Idx),
           Size = MRI.getSubRegIdxSize(Idx);
  if (Offset == (unsigned)-1 || Size == (unsigned)-1)
    llvm_unreachable("Used subreg index doesn't cover a bit range?");

  Value *RV = getRegAsInt(Sub);
  Value *SRV = getRegAsInt(Super);

  return insertBitsInValue(SRV, RV, Offset, doesSubRegIndexClearSuper(Idx));
}

void DCRegisterSema::defineAllSubSuperRegs(unsigned RegNo) {
  for (MCSuperRegIterator SRI(RegNo, &MRI); SRI.isValid(); ++SRI) {
    if (getRegSetDesc().RegAliased[*SRI])
      continue;
    setRegNoSubSuper(*SRI, recreateSuperRegFromSub(*SRI, RegNo));
  }

  for (MCSubRegIterator SRI(RegNo, &MRI); SRI.isValid(); ++SRI) {
    if (getRegSetDesc().RegAliased[*SRI])
      continue;
    setRegNoSubSuper(*SRI, extractSubRegFromSuper(RegNo, *SRI));
  }
}

void DCRegisterSema::setRegNoSubSuper(unsigned RegNo, Value *Val) {
  // FIXME: This will needlessly extract the subreg from the largest super.
  createLocalValueForReg(RegNo);
  setRegValWithName(RegNo, Val);
  onRegisterSet(RegNo, Val);
}

void DCRegisterSema::setReg(unsigned RegNo, Value *Val) {
  if (EnableMockIntrin) {
    Value *MDRegName =
        MetadataAsValue::get(Ctx, MDString::get(Ctx, MRI.getName(RegNo)));
    Function *SetRegIntrin = Intrinsic::getDeclaration(
        TheModule, Intrinsic::dc_setreg, Val->getType());
    // FIXME: val type or regtype?
    Builder->CreateCall(SetRegIntrin, {Val, MDRegName});
    return;
  }

  if (getRegSetDesc().RegAliased[RegNo])
    llvm_unreachable("Access to aliased registers not implemented yet");

  setRegNoSubSuper(RegNo, Val);
  defineAllSubSuperRegs(RegNo);
}

Type *DCRegisterSema::getRegType(unsigned RegNo) {
  if (Type *Ty = getRegSetDesc().RegTypes[RegNo])
    return Ty;
  return getRegIntType(RegNo);
}

IntegerType *DCRegisterSema::getRegIntType(unsigned RegNo) {
  return IntegerType::get(Ctx, getRegSetDesc().RegSizes[RegNo]);
}

extern "C" void __llvm_dc_print_reg_diff_fn(void *FPtr) {
  printf("Different Registers for '");
  Dl_info DLI;
  if (dladdr(FPtr, &DLI))
    printf("%s", DLI.dli_sname);
  else
    printf("fn_%p", FPtr);
  printf("':\n");
}

extern "C" void __llvm_dc_print_reg_diff(char *Name, uint8_t *v1, uint8_t *v2,
                                         uint32_t Size) {
  bool Diff = false;

  for (uint32_t i = 0; i < Size; ++i)
    Diff |= (v1[i] != v2[i]);

  if (!Diff)
    return;

  printf("%s = ", Name);
  for (uint32_t i = 0; i < Size; ++i)
    printf("%.2x", v2[Size - i - 1]);
  printf("\n");
}

Function *DCRegisterSema::getOrCreateRegSetDiffFunction() {
  Type *I8PtrTy = Builder->getInt8PtrTy();
  Type *RegSetPtrTy = getRegSetDesc().RegSetType->getPointerTo();

  Type *RSDiffArgTys[] = {I8PtrTy, RegSetPtrTy, RegSetPtrTy};
  Function *RSDiffFn = cast<Function>(TheModule->getOrInsertFunction(
      "__llvm_dc_print_regset_diff",
      FunctionType::get(Builder->getVoidTy(), RSDiffArgTys,
                        /*isVarArg=*/false)));

  // If we already defined the function, return it.
  if (!RSDiffFn->isDeclaration())
    return RSDiffFn;

  IRBuilderBase::InsertPointGuard IPG(*Builder);
  Builder->SetInsertPoint(BasicBlock::Create(Ctx, "", RSDiffFn));

  // Get the argument regset pointers.
  Function::arg_iterator ArgI = RSDiffFn->getArgumentList().begin();
  Value *FnAddr = &*ArgI++;
  Value *RS1 = &*ArgI++;
  Value *RS2 = &*ArgI++;

  // We use a C++ helper function to print the header with the function info:
  //   __llvm_dc_print_reg_diff_fn (defined above).
  Type *PrintFnArgTys[] = {I8PtrTy};
  FunctionType *PrintFnType = FunctionType::get(
      Builder->getVoidTy(), PrintFnArgTys, /*isVarArg=*/false);

  Builder->CreateCall(
      getCallTargetForExtFn(PrintFnType, &__llvm_dc_print_reg_diff_fn), FnAddr);

  // We use a C++ helper function to diff and print each individual register:
  //   __llvm_dc_print_reg_diff (defined above).
  Type *RegDiffArgTys[] = {I8PtrTy, I8PtrTy, I8PtrTy, Builder->getInt32Ty()};
  FunctionType *RegDiffFnType = FunctionType::get(
      Builder->getVoidTy(), RegDiffArgTys, /*isVarArg=*/false);

  Value *RegDiffFnPtr =
      getCallTargetForExtFn(RegDiffFnType, &__llvm_dc_print_reg_diff);

  for (auto Reg : getRegSetDesc().LargestRegs) {
    if (Reg == 0)
      continue;
    int OffsetInRegSet = getRegSetDesc().RegOffsetsInSet[Reg];
    assert(OffsetInRegSet != -1 && "Getting a register not in the regset!");
    Value *Idx[] = {Builder->getInt32(0), Builder->getInt32(OffsetInRegSet)};
    Value *Reg1Ptr =
        Builder->CreateBitCast(Builder->CreateInBoundsGEP(RS1, Idx), I8PtrTy);
    Value *Reg2Ptr =
        Builder->CreateBitCast(Builder->CreateInBoundsGEP(RS2, Idx), I8PtrTy);

    Value *RegName = Builder->CreateBitCast(
        Builder->CreateGlobalString(MRI.getName(Reg)), I8PtrTy);

    Builder->CreateCall(RegDiffFnPtr,
                        {RegName, Reg1Ptr, Reg2Ptr,
                         Builder->getInt32(getRegSetDesc().RegSizes[Reg] / 8)});
  }

  Builder->CreateRetVoid();

  return RSDiffFn;
}
