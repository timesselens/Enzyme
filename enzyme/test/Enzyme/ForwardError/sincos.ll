; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; Error estimation for a rule with several results: each result gets the
; one-result formula, max(ulp(r), |dr/dx * err(x) * x| / |r|). For
; __fd_sincos_1 this used to fail with "Invalid bitcast".

declare [2 x double] @__fd_sincos_1(double)

define double @tester(double %x) {
entry:
  %r = call [2 x double] @__fd_sincos_1(double %x)
  %c = extractvalue [2 x double] %r, 1
  ret double %c
}

define double @test_error(double %x, double %err) {
entry:
  %0 = call double (...) @__enzyme_error_estimate(ptr @tester, double %x, double %err)
  ret double %0
}

declare double @__enzyme_error_estimate(...)

; CHECK: define internal double @fwddiffetester(double %x, double %"x'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %r = call [2 x double] @__fd_sincos_1(double %x)
; CHECK-NEXT:   %0 = extractvalue [2 x double] %r, 1
; CHECK-NEXT:   %1 = fmul fast double %"x'", %x
; CHECK-NEXT:   %2 = call fast [2 x double] @__fd_sincos_1(double %x)
; CHECK-NEXT:   %3 = extractvalue [2 x double] %2, 0
; CHECK-NEXT:   %4 = fmul fast double %3, %1
; CHECK-NEXT:   %5 = fneg fast double %4
; CHECK-NEXT:   %6 = call fast double @llvm.fabs.f64(double %5)
; CHECK-NEXT:   %7 = call fast double @llvm.fabs.f64(double %0)
; CHECK-NEXT:   %8 = fdiv fast double %6, %7
; CHECK-NEXT:   %9 = bitcast double %0 to i64
; CHECK-NEXT:   %10 = xor i64 %9, 1
; CHECK-NEXT:   %11 = bitcast i64 %10 to double
; CHECK-NEXT:   %12 = fsub fast double %0, %11
; CHECK-NEXT:   %13 = call fast double @llvm.fabs.f64(double %12)
; CHECK-NEXT:   %14 = call fast double @llvm.maxnum.f64(double %13, double %8)
; CHECK-NEXT:   ret double %14
; CHECK-NEXT: }
