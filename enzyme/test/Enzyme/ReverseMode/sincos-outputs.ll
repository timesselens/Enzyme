; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; sincos and sincospi that write their results through pointers use the rules
; of the forms returning both values (OutputArg in InstructionDerivatives.td).
; The adjoints of the written results are read from the outputs' shadows,
; which are then zeroed, since the call overwrote that memory.

declare void @sincos(double, ptr, ptr)
declare void @__nv_sincosf(float, ptr, ptr)
declare float @air.sincos.f32(float, ptr)
declare void @__nv_sincospif(float, ptr, ptr)

define double @tester(double %x) {
entry:
  %s = alloca double
  %c = alloca double
  call void @sincos(double %x, ptr %s, ptr %c)
  %sv = load double, ptr %s
  %cv = load double, ptr %c
  %r = fadd double %sv, %cv
  ret double %r
}

define void @tester_nv(float %x, ptr %s, ptr %c) {
entry:
  call void @__nv_sincosf(float %x, ptr %s, ptr %c)
  ret void
}

define float @tester_air(float %x) {
entry:
  %c = alloca float
  %s = call float @air.sincos.f32(float %x, ptr %c)
  %cv = load float, ptr %c
  %r = fadd float %s, %cv
  ret float %r
}

define void @tester_pi(float %x, ptr %s, ptr %c) {
entry:
  call void @__nv_sincospif(float %x, ptr %s, ptr %c)
  ret void
}

define double @test_derivative(double %x) {
entry:
  %0 = call double (...) @__enzyme_autodiff(ptr @tester, double %x)
  ret double %0
}

define float @test_derivative_nv(float %x, ptr %s, ptr %ds, ptr %c, ptr %dc) {
entry:
  %0 = call float (...) @__enzyme_autodiff_f(ptr @tester_nv, float %x, ptr %s, ptr %ds, ptr %c, ptr %dc)
  ret float %0
}

define float @test_derivative_air(float %x) {
entry:
  %0 = call float (...) @__enzyme_autodiff_f(ptr @tester_air, float %x)
  ret float %0
}

define float @test_derivative_pi(float %x, ptr %s, ptr %ds, ptr %c, ptr %dc) {
entry:
  %0 = call float (...) @__enzyme_autodiff_f(ptr @tester_pi, float %x, ptr %s, ptr %ds, ptr %c, ptr %dc)
  ret float %0
}

declare double @__enzyme_autodiff(...)
declare float @__enzyme_autodiff_f(...)

; CHECK: define internal { double } @diffetester(double %x, double %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca double, align 8
; CHECK-NEXT:   %1 = alloca double, align 8
; CHECK-NEXT:   %s = alloca double, align 8
; CHECK-NEXT:   %c = alloca double, align 8
; CHECK-NEXT:   call void @sincos(double %x, ptr %s, ptr %c)
; CHECK-NEXT:   call void @sincos(double %x, ptr %0, ptr %1)
; CHECK-NEXT:   %2 = load double, ptr %0, align 8
; CHECK-NEXT:   %3 = load double, ptr %1, align 8
; CHECK-NEXT:   %4 = fmul fast double %3, %differeturn
; CHECK-NEXT:   %5 = fmul fast double %2, %differeturn
; CHECK-NEXT:   %6 = fneg fast double %5
; CHECK-NEXT:   %7 = fadd fast double %4, %6
; CHECK-NEXT:   %8 = insertvalue { double } undef, double %7, 0
; CHECK-NEXT:   ret { double } %8
; CHECK-NEXT: }

; CHECK: define internal { float } @diffetester_nv(float %x, ptr writeonly %s, ptr %"s'", ptr writeonly %c, ptr %"c'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %1 = alloca float, align 4
; CHECK-NEXT:   call void @__nv_sincosf(float %x, ptr %s, ptr %c)
; CHECK-NEXT:   %2 = load float, ptr %"s'", align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"s'", align 4
; CHECK-NEXT:   %3 = load float, ptr %"c'", align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"c'", align 4
; CHECK-NEXT:   call void @__nv_sincosf(float %x, ptr %0, ptr %1)
; CHECK-NEXT:   %4 = load float, ptr %0, align 4
; CHECK-NEXT:   %5 = load float, ptr %1, align 4
; CHECK-NEXT:   %6 = fmul fast float %5, %2
; CHECK-NEXT:   %7 = fmul fast float %4, %3
; CHECK-NEXT:   %8 = fneg fast float %7
; CHECK-NEXT:   %9 = fadd fast float %6, %8
; CHECK-NEXT:   %10 = insertvalue { float } undef, float %9, 0
; CHECK-NEXT:   ret { float } %10
; CHECK-NEXT: }

; CHECK: define internal { float } @diffetester_air(float %x, float %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %c = alloca float, align 4
; CHECK-NEXT:   %s = call float @air.sincos.f32(float %x, ptr %c)
; CHECK-NEXT:   %1 = call fast float @air.sincos.f32(float %x, ptr %0)
; CHECK-NEXT:   %2 = load float, ptr %0, align 4
; CHECK-NEXT:   %3 = fmul fast float %2, %differeturn
; CHECK-NEXT:   %4 = fmul fast float %1, %differeturn
; CHECK-NEXT:   %5 = fneg fast float %4
; CHECK-NEXT:   %6 = fadd fast float %3, %5
; CHECK-NEXT:   %7 = insertvalue { float } undef, float %6, 0
; CHECK-NEXT:   ret { float } %7
; CHECK-NEXT: }

; CHECK: define internal { float } @diffetester_pi(float %x, ptr writeonly %s, ptr %"s'", ptr writeonly %c, ptr %"c'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %1 = alloca float, align 4
; CHECK-NEXT:   call void @__nv_sincospif(float %x, ptr %s, ptr %c)
; CHECK-NEXT:   %2 = load float, ptr %"s'", align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"s'", align 4
; CHECK-NEXT:   %3 = load float, ptr %"c'", align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"c'", align 4
; CHECK-NEXT:   call void @__nv_sincospif(float %x, ptr %0, ptr %1)
; CHECK-NEXT:   %4 = load float, ptr %0, align 4
; CHECK-NEXT:   %5 = load float, ptr %1, align 4
; CHECK-NEXT:   %6 = fmul fast float %5, %2
; CHECK-NEXT:   %7 = fmul fast float 0x400921FB60000000, %6
; CHECK-NEXT:   %8 = fmul fast float %4, %3
; CHECK-NEXT:   %9 = fneg fast float %8
; CHECK-NEXT:   %10 = fmul fast float 0x400921FB60000000, %9
; CHECK-NEXT:   %11 = fadd fast float %7, %10
; CHECK-NEXT:   %12 = insertvalue { float } undef, float %11, 0
; CHECK-NEXT:   ret { float } %12
; CHECK-NEXT: }
