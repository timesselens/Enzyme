; RUN: if [ %llvmver -ge 15 ]; then not %opt < %s %OPnewLoadEnzyme -passes="enzyme" -enzyme-preopt=false -S 2>&1 | FileCheck %s; fi

; Split forward mode isn't implemented for rules with OutputArgs yet: a clear
; error, rather than an assertion on the call that this mode drops.

declare void @sincos(double, ptr, ptr)

define void @tester(double %x, ptr %s, ptr %c) {
entry:
  call void @sincos(double %x, ptr %s, ptr %c)
  ret void
}

define void @test_derivative(double %x, ptr %s, ptr %ds, ptr %c, ptr %dc) {
entry:
  call void (...) @__enzyme_fwdsplit(ptr @tester, double %x, double 1.0, ptr %s, ptr %ds, ptr %c, ptr %dc, ptr null)
  ret void
}

declare void @__enzyme_fwdsplit(...)

; CHECK: split forward mode is not implemented for a call writing results through pointers: {{.*}}call void @sincos(double %x, ptr %s, ptr %c)
