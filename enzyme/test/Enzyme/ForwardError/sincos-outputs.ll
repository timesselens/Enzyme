; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; Error estimation for a call that writes its results through pointers: each
; result gets the one-result formula, max(ulp(r), |dr/dx * err(x) * x| / |r|),
; and the errors go to the outputs' shadows.

declare void @sincos(double, ptr, ptr)

define double @tester_ptrs(double %x) {
entry:
  %s = alloca double
  %c = alloca double
  call void @sincos(double %x, ptr %s, ptr %c)
  %v = load double, ptr %c
  ret double %v
}

define double @test_error_ptrs(double %x, double %err) {
entry:
  %0 = call double (...) @__enzyme_error_estimate(ptr @tester_ptrs, double %x, double %err)
  ret double %0
}

declare double @__enzyme_error_estimate(...)

; CHECK: define internal double @fwddiffetester_ptrs(double %x, double %"x'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca double, align 8
; CHECK-NEXT:   %1 = alloca double, align 8
; CHECK-NEXT:   %s = alloca double, align 8
; CHECK-NEXT:   %c = alloca double, align 8
; CHECK-NEXT:   call void @sincos(double %x, ptr %s, ptr %c)
; CHECK-NEXT:   %2 = load double, ptr %c, align 8
; CHECK-NEXT:   %3 = fmul fast double %"x'", %x
; CHECK-NEXT:   call void @sincos(double %x, ptr %0, ptr %1)
; CHECK-NEXT:   %4 = load double, ptr %0, align 8
; CHECK-NEXT:   %5 = fmul fast double %4, %3
; CHECK-NEXT:   %6 = fneg fast double %5
; CHECK-NEXT:   %7 = call fast double @llvm.fabs.f64(double %6)
; CHECK-NEXT:   %8 = call fast double @llvm.fabs.f64(double %2)
; CHECK-NEXT:   %9 = fdiv fast double %7, %8
; CHECK-NEXT:   %10 = bitcast double %2 to i64
; CHECK-NEXT:   %11 = xor i64 %10, 1
; CHECK-NEXT:   %12 = bitcast i64 %11 to double
; CHECK-NEXT:   %13 = fsub fast double %2, %12
; CHECK-NEXT:   %14 = call fast double @llvm.fabs.f64(double %13)
; CHECK-NEXT:   %15 = call fast double @llvm.maxnum.f64(double %14, double %9)
; CHECK-NEXT:   ret double %15
; CHECK-NEXT: }
