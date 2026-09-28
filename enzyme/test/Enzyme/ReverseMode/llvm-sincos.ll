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
  %0 = call double (...) @__enzyme_autodiff(ptr @tester, double %x)
  ret double %0
}

declare double @__enzyme_autodiff(...)

; CHECK: define internal { double } @diffetester(double %x, double %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %"r'de" = alloca { double, double }, align 8
; CHECK-NEXT:   store { double, double } zeroinitializer, ptr %"r'de", align 8
; CHECK-NEXT:   %0 = fmul fast double %differeturn, 2.000000e+00
; CHECK-NEXT:   %1 = getelementptr inbounds { double, double }, ptr %"r'de", i32 0, i32 1
; CHECK-NEXT:   %2 = load double, ptr %1, align 8
; CHECK-NEXT:   %3 = fadd fast double %2, %0
; CHECK-NEXT:   store double %3, ptr %1, align 8
; CHECK-NEXT:   %4 = load double, ptr %"r'de", align 8
; CHECK-NEXT:   %5 = fadd fast double %4, %differeturn
; CHECK-NEXT:   store double %5, ptr %"r'de", align 8
; CHECK-NEXT:   %6 = load { double, double }, ptr %"r'de", align 8
; CHECK-NEXT:   store { double, double } zeroinitializer, ptr %"r'de", align 8
; CHECK-NEXT:   %7 = call fast { double, double } @llvm.sincos.f64(double %x)
; CHECK-NEXT:   %8 = extractvalue { double, double } %7, 1
; CHECK-NEXT:   %9 = extractvalue { double, double } %6, 0
; CHECK-NEXT:   %10 = fmul fast double %8, %9
; CHECK-NEXT:   %11 = extractvalue { double, double } %7, 0
; CHECK-NEXT:   %12 = extractvalue { double, double } %6, 1
; CHECK-NEXT:   %13 = fmul fast double %11, %12
; CHECK-NEXT:   %14 = fneg fast double %13
; CHECK-NEXT:   %15 = fadd fast double %10, %14
; CHECK-NEXT:   %16 = insertvalue { double } undef, double %15, 0
; CHECK-NEXT:   ret { double } %16
; CHECK-NEXT: }
