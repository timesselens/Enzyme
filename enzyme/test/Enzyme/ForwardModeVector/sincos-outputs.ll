; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; sincos writing both results through pointers, in vector mode: each lane's
; tangents are stored through that lane's shadows.

declare void @sincos(double, ptr, ptr)

define void @tester(double %x, ptr %s, ptr %c) {
entry:
  call void @sincos(double %x, ptr %s, ptr %c)
  ret void
}

define void @test_derivative(double %x, ptr %s, ptr %ds1, ptr %ds2, ptr %c, ptr %dc1, ptr %dc2) {
entry:
  call void (...) @__enzyme_fwddiff(ptr @tester, metadata !"enzyme_width", i64 2, double %x, double 1.0, double 2.0, ptr %s, ptr %ds1, ptr %ds2, ptr %c, ptr %dc1, ptr %dc2)
  ret void
}

declare void @__enzyme_fwddiff(...)

; CHECK: define internal void @fwddiffe2tester(double %x, [2 x double] %"x'", ptr writeonly %s, [2 x ptr] %"s'", ptr writeonly %c, [2 x ptr] %"c'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca double, align 8
; CHECK-NEXT:   %1 = alloca double, align 8
; CHECK-NEXT:   call void @sincos(double %x, ptr %s, ptr %c)
; CHECK-NEXT:   call void @sincos(double %x, ptr %0, ptr %1)
; CHECK-NEXT:   %2 = load double, ptr %0, align 8
; CHECK-NEXT:   %3 = load double, ptr %1, align 8
; CHECK-NEXT:   %4 = extractvalue [2 x double] %"x'", 0
; CHECK-NEXT:   %5 = fmul fast double %3, %4
; CHECK-NEXT:   %6 = extractvalue [2 x double] %"x'", 1
; CHECK-NEXT:   %7 = fmul fast double %3, %6
; CHECK-NEXT:   %8 = extractvalue [2 x double] %"x'", 0
; CHECK-NEXT:   %9 = fmul fast double %2, %8
; CHECK-NEXT:   %10 = extractvalue [2 x double] %"x'", 1
; CHECK-NEXT:   %11 = fmul fast double %2, %10
; CHECK-NEXT:   %12 = fneg fast double %9
; CHECK-NEXT:   %13 = fneg fast double %11
; CHECK-NEXT:   %14 = extractvalue [2 x ptr] %"s'", 0
; CHECK-NEXT:   store double %5, ptr %14, align 8
; CHECK-NEXT:   %15 = extractvalue [2 x ptr] %"s'", 1
; CHECK-NEXT:   store double %7, ptr %15, align 8
; CHECK-NEXT:   %16 = extractvalue [2 x ptr] %"c'", 0
; CHECK-NEXT:   store double %12, ptr %16, align 8
; CHECK-NEXT:   %17 = extractvalue [2 x ptr] %"c'", 1
; CHECK-NEXT:   store double %13, ptr %17, align 8
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
