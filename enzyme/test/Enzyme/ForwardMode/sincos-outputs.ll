; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; sincos and sincospi that write their results through pointers use the rules
; of the forms returning both values (OutputArg in InstructionDerivatives.td).
; The tangents of the written results are stored through the outputs' shadows.

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
  %0 = call double (...) @__enzyme_fwddiff(ptr @tester, double %x, double 1.0)
  ret double %0
}

define void @test_derivative_nv(float %x, float %dx, ptr %s, ptr %ds, ptr %c, ptr %dc) {
entry:
  call void (...) @__enzyme_fwddiff_v(ptr @tester_nv, float %x, float %dx, ptr %s, ptr %ds, ptr %c, ptr %dc)
  ret void
}

define float @test_derivative_air(float %x) {
entry:
  %0 = call float (...) @__enzyme_fwddiff_f(ptr @tester_air, float %x, float 1.0)
  ret float %0
}

define void @test_derivative_pi(float %x, float %dx, ptr %s, ptr %ds, ptr %c, ptr %dc) {
entry:
  call void (...) @__enzyme_fwddiff_v(ptr @tester_pi, float %x, float %dx, ptr %s, ptr %ds, ptr %c, ptr %dc)
  ret void
}

declare double @__enzyme_fwddiff(...)
declare float @__enzyme_fwddiff_f(...)
declare void @__enzyme_fwddiff_v(...)

; CHECK: define internal double @fwddiffetester(double %x, double %"x'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca double, align 8
; CHECK-NEXT:   %1 = alloca double, align 8
; CHECK-NEXT:   %s = alloca double, align 8
; CHECK-NEXT:   %c = alloca double, align 8
; CHECK-NEXT:   call void @sincos(double %x, ptr %s, ptr %c)
; CHECK-NEXT:   call void @sincos(double %x, ptr %0, ptr %1)
; CHECK-NEXT:   %2 = load double, ptr %0, align 8
; CHECK-NEXT:   %3 = load double, ptr %1, align 8
; CHECK-NEXT:   %4 = fmul fast double %3, %"x'"
; CHECK-NEXT:   %5 = fmul fast double %2, %"x'"
; CHECK-NEXT:   %6 = fneg fast double %5
; CHECK-NEXT:   %7 = fadd fast double %4, %6
; CHECK-NEXT:   ret double %7
; CHECK-NEXT: }

; CHECK: define internal void @fwddiffetester_nv(float %x, float %"x'", ptr writeonly %s, ptr %"s'", ptr writeonly %c, ptr %"c'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %1 = alloca float, align 4
; CHECK-NEXT:   call void @__nv_sincosf(float %x, ptr %s, ptr %c)
; CHECK-NEXT:   call void @__nv_sincosf(float %x, ptr %0, ptr %1)
; CHECK-NEXT:   %2 = load float, ptr %0, align 4
; CHECK-NEXT:   %3 = load float, ptr %1, align 4
; CHECK-NEXT:   %4 = fmul fast float %3, %"x'"
; CHECK-NEXT:   %5 = fmul fast float %2, %"x'"
; CHECK-NEXT:   %6 = fneg fast float %5
; CHECK-NEXT:   store float %4, ptr %"s'", align 4
; CHECK-NEXT:   store float %6, ptr %"c'", align 4
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: define internal float @fwddiffetester_air(float %x, float %"x'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %c = alloca float, align 4
; CHECK-NEXT:   %s = call float @air.sincos.f32(float %x, ptr %c)
; CHECK-NEXT:   %1 = call fast float @air.sincos.f32(float %x, ptr %0)
; CHECK-NEXT:   %2 = load float, ptr %0, align 4
; CHECK-NEXT:   %3 = fmul fast float %2, %"x'"
; CHECK-NEXT:   %4 = fmul fast float %1, %"x'"
; CHECK-NEXT:   %5 = fneg fast float %4
; CHECK-NEXT:   %6 = fadd fast float %3, %5
; CHECK-NEXT:   ret float %6
; CHECK-NEXT: }

; CHECK: define internal void @fwddiffetester_pi(float %x, float %"x'", ptr writeonly %s, ptr %"s'", ptr writeonly %c, ptr %"c'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %1 = alloca float, align 4
; CHECK-NEXT:   call void @__nv_sincospif(float %x, ptr %s, ptr %c)
; CHECK-NEXT:   call void @__nv_sincospif(float %x, ptr %0, ptr %1)
; CHECK-NEXT:   %2 = load float, ptr %0, align 4
; CHECK-NEXT:   %3 = load float, ptr %1, align 4
; CHECK-NEXT:   %4 = fmul fast float %3, %"x'"
; CHECK-NEXT:   %5 = fmul fast float 0x400921FB60000000, %4
; CHECK-NEXT:   %6 = fmul fast float %2, %"x'"
; CHECK-NEXT:   %7 = fneg fast float %6
; CHECK-NEXT:   %8 = fmul fast float 0x400921FB60000000, %7
; CHECK-NEXT:   store float %5, ptr %"s'", align 4
; CHECK-NEXT:   store float %8, ptr %"c'", align 4
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
