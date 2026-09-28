; RUN: if [ %llvmver -ge 20 ]; then %opt < %s %OPnewLoadEnzyme -passes="enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; LLVM's sincos intrinsic returns both results and uses the rule of __fd_sincos_1.

declare { double, double } @llvm.sincos.f64(double)

define double @tester(double %x) {
entry:
  %r = call { double, double } @llvm.sincos.f64(double %x)
  %s = extractvalue { double, double } %r, 0
  %c = extractvalue { double, double } %r, 1
  %c2 = fmul double %c, 2.0
  %y = fadd double %s, %c2
  ret double %y
}

define double @test_derivative(double %x) {
entry:
  %0 = call double (...) @__enzyme_fwddiff(ptr @tester, double %x, double 1.0)
  ret double %0
}

declare double @__enzyme_fwddiff(...)

; CHECK: define internal double @fwddiffetester(double %x, double %"x'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = call fast { double, double } @llvm.sincos.f64(double %x)
; CHECK-NEXT:   %1 = extractvalue { double, double } %0, 1
; CHECK-NEXT:   %2 = fmul fast double %1, %"x'"
; CHECK-NEXT:   %3 = extractvalue { double, double } %0, 0
; CHECK-NEXT:   %4 = fmul fast double %3, %"x'"
; CHECK-NEXT:   %5 = fneg fast double %4
; CHECK-NEXT:   %6 = fmul fast double %5, 2.000000e+00
; CHECK-NEXT:   %7 = fadd fast double %2, %6
; CHECK-NEXT:   ret double %7
; CHECK-NEXT: }
