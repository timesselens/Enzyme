; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="preserve-nvvm,enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; AMD's ocml sincos and sincospi return the sine and write the cosine through
; a private (address space 5) pointer. Recomputing them needs a slot in that
; address space.

target datalayout = "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8"
target triple = "amdgcn-amd-amdhsa"

declare float @__ocml_sincos_f32(float, ptr addrspace(5))
declare double @__ocml_sincospi_f64(double, ptr addrspace(5))

define float @tester(float %x) {
entry:
  %c = alloca float, addrspace(5)
  %s = call float @__ocml_sincos_f32(float %x, ptr addrspace(5) %c)
  %cv = load float, ptr addrspace(5) %c
  %r = fadd float %s, %cv
  ret float %r
}

define double @tester_pi(double %x) {
entry:
  %c = alloca double, addrspace(5)
  %s = call double @__ocml_sincospi_f64(double %x, ptr addrspace(5) %c)
  %cv = load double, ptr addrspace(5) %c
  %r = fadd double %s, %cv
  ret double %r
}

define float @test_derivative(float %x) {
entry:
  %0 = call float (...) @__enzyme_autodiff_f(ptr @tester, float %x)
  ret float %0
}

define double @test_derivative_pi(double %x) {
entry:
  %0 = call double (...) @__enzyme_autodiff(ptr @tester_pi, double %x)
  ret double %0
}

declare float @__enzyme_autodiff_f(...)
declare double @__enzyme_autodiff(...)

; CHECK: define internal { float } @diffetester(float %x, float %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4, addrspace(5)
; CHECK-NEXT:   %c = alloca float, align 4, addrspace(5)
; CHECK-NEXT:   %s = call float @__ocml_sincos_f32(float %x, ptr addrspace(5) %c)
; CHECK-NEXT:   %1 = call fast float @__ocml_sincos_f32(float %x, ptr addrspace(5) %0)
; CHECK-NEXT:   %2 = load float, ptr addrspace(5) %0, align 4
; CHECK-NEXT:   %3 = fmul fast float %2, %differeturn
; CHECK-NEXT:   %4 = fmul fast float %1, %differeturn
; CHECK-NEXT:   %5 = fneg fast float %4
; CHECK-NEXT:   %6 = fadd fast float %3, %5
; CHECK-NEXT:   %7 = insertvalue { float } undef, float %6, 0
; CHECK-NEXT:   ret { float } %7
; CHECK-NEXT: }

; CHECK: define internal { double } @diffetester_pi(double %x, double %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca double, align 8, addrspace(5)
; CHECK-NEXT:   %c = alloca double, align 8, addrspace(5)
; CHECK-NEXT:   %s = call double @__ocml_sincospi_f64(double %x, ptr addrspace(5) %c)
; CHECK-NEXT:   %1 = call fast double @__ocml_sincospi_f64(double %x, ptr addrspace(5) %0)
; CHECK-NEXT:   %2 = load double, ptr addrspace(5) %0, align 8
; CHECK-NEXT:   %3 = fmul fast double %2, %differeturn
; CHECK-NEXT:   %4 = fmul fast double 0x400921FB54442D18, %3
; CHECK-NEXT:   %5 = fmul fast double %1, %differeturn
; CHECK-NEXT:   %6 = fneg fast double %5
; CHECK-NEXT:   %7 = fmul fast double 0x400921FB54442D18, %6
; CHECK-NEXT:   %8 = fadd fast double %4, %7
; CHECK-NEXT:   %9 = insertvalue { double } undef, double %8, 0
; CHECK-NEXT:   ret { double } %9
; CHECK-NEXT: }
