; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="preserve-nvvm,always-inline,enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; A libdevice sincos linked in before differentiation: preserve-nvvm keeps it out
; of line, so the rule applies and its body (inline assembly here, as in
; libdevice's argument reduction) isn't differentiated. The call in the
; reverse pass writes stack slots, since the program no longer needs *s and *c.

define internal void @__nv_sincosf(float %x, ptr %s, ptr %c) #0 {
entry:
  %a = call float asm "sin.approx.f32 $0, $1;", "=f,f"(float %x)
  %b = call float asm "cos.approx.f32 $0, $1;", "=f,f"(float %x)
  store float %a, ptr %s
  store float %b, ptr %c
  ret void
}
define internal float @julia_sincos(float %x) {
entry:
  %s = alloca float
  %c = alloca float
  call void @__nv_sincosf(float %x, ptr %s, ptr %c)
  %sv = load float, ptr %s
  %cv = load float, ptr %c
  %r = fadd float %sv, %cv
  ret float %r
}
define float @tester(float %x) {
entry:
  %r = call float @julia_sincos(float %x)
  ret float %r
}
define float @test_derivative(float %x) {
entry:
  %0 = call float (...) @__enzyme_autodiff(ptr @tester, float %x)
  ret float %0
}
declare float @__enzyme_autodiff(...)
attributes #0 = { alwaysinline nounwind }

; CHECK: define internal { float } @diffejulia_sincos(float %x, float %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %1 = alloca float, align 4
; CHECK-NEXT:   %2 = alloca float, align 4
; CHECK-NEXT:   %3 = alloca float, align 4
; CHECK-NEXT:   call void @__nv_sincosf(float %x, ptr %0, ptr %1)
; CHECK-NEXT:   call void @__nv_sincosf(float %x, ptr %2, ptr %3)
; CHECK-NEXT:   %4 = load float, ptr %2, align 4
; CHECK-NEXT:   %5 = load float, ptr %3, align 4
; CHECK-NEXT:   %6 = fmul fast float %5, %differeturn
; CHECK-NEXT:   %7 = fmul fast float %4, %differeturn
; CHECK-NEXT:   %8 = fneg fast float %7
; CHECK-NEXT:   %9 = fadd fast float %6, %8
; CHECK-NEXT:   %10 = insertvalue { float } undef, float %9, 0
; CHECK-NEXT:   ret { float } %10
; CHECK-NEXT: }
