; RUN: if [ %llvmver -ge 15 ]; then %opt < %s %OPnewLoadEnzyme -passes="enzyme,function(mem2reg,instsimplify,%simplifycfg)" -enzyme-preopt=false -S | FileCheck %s; fi

; Output pointers passed as integers, as Julia passes a Ptr when LLVM uses
; typed pointers (CUDA.jl's __nv_sincosf on Julia 1.10 and 1.11); results
; copied out with memcpy, which type analysis types from what the call writes;
; and runtime activity in a callee differentiated in split mode, whose reverse
; pass compares an output pointer that it can't load again with its shadow.

declare void @__nv_sincosf(float, i64, i64)
declare void @sincos(double, ptr, ptr)
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)

define float @tester_int(float %x) {
entry:
  %s = alloca float
  %c = alloca float
  %si = ptrtoint ptr %s to i64
  %ci = ptrtoint ptr %c to i64
  call void @__nv_sincosf(float %x, i64 %si, i64 %ci)
  %sv = load float, ptr %s
  %cv = load float, ptr %c
  %r = fadd float %sv, %cv
  ret float %r
}

define void @tester_copy(double %x, ptr %out) {
entry:
  %pair = alloca [2 x double]
  %p1 = getelementptr double, ptr %pair, i64 1
  call void @sincos(double %x, ptr %pair, ptr %p1)
  call void @llvm.memcpy.p0.p0.i64(ptr %out, ptr %pair, i64 16, i1 false)
  ret void
}

define void @h(double %x, ptr %s, ptr %pp) noinline {
entry:
  %c = load ptr, ptr %pp
  call void @sincos(double %x, ptr %s, ptr %c)
  store ptr null, ptr %pp
  ret void
}

define double @tester_rt(double %x) {
entry:
  %s = alloca double
  %c = alloca double
  %pp = alloca ptr
  store ptr %c, ptr %pp
  call void @h(double %x, ptr %s, ptr %pp)
  %sv = load double, ptr %s
  %cv = load double, ptr %c
  %m = fmul double %sv, %cv
  ret double %m
}

define float @test_derivative_int(float %x) {
entry:
  %0 = call float (...) @__enzyme_autodiff_f(ptr @tester_int, float %x)
  ret float %0
}

define double @test_derivative_copy(double %x, ptr %out, ptr %dout) {
entry:
  %0 = call double (...) @__enzyme_autodiff(ptr @tester_copy, double %x, ptr %out, ptr %dout)
  ret double %0
}

define double @test_derivative_rt(double %x) {
entry:
  %0 = call double (...) @__enzyme_autodiff(ptr @tester_rt, metadata !"enzyme_runtime_activity", double %x)
  ret double %0
}

declare double @__enzyme_autodiff(...)
declare float @__enzyme_autodiff_f(...)

; CHECK: define internal { float } @diffetester_int(float %x, float %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca float, align 4
; CHECK-NEXT:   %1 = alloca float, align 4
; CHECK-NEXT:   %"s'ipa" = alloca float, align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"s'ipa", align 4
; CHECK-NEXT:   %s = alloca float, align 4
; CHECK-NEXT:   %"c'ipa" = alloca float, align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"c'ipa", align 4
; CHECK-NEXT:   %c = alloca float, align 4
; CHECK-NEXT:   %si = ptrtoint ptr %s to i64
; CHECK-NEXT:   %ci = ptrtoint ptr %c to i64
; CHECK-NEXT:   call void @__nv_sincosf(float %x, i64 %si, i64 %ci)
; CHECK-NEXT:   %2 = load float, ptr %"c'ipa", align 4
; CHECK-NEXT:   %3 = fadd fast float %2, %differeturn
; CHECK-NEXT:   store float %3, ptr %"c'ipa", align 4
; CHECK-NEXT:   %4 = load float, ptr %"s'ipa", align 4
; CHECK-NEXT:   %5 = fadd fast float %4, %differeturn
; CHECK-NEXT:   store float %5, ptr %"s'ipa", align 4
; CHECK-NEXT:   %6 = load float, ptr %"s'ipa", align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"s'ipa", align 4
; CHECK-NEXT:   %7 = load float, ptr %"c'ipa", align 4
; CHECK-NEXT:   store float 0.000000e+00, ptr %"c'ipa", align 4
; CHECK-NEXT:   %8 = ptrtoint ptr %0 to i64
; CHECK-NEXT:   %9 = ptrtoint ptr %1 to i64
; CHECK-NEXT:   call void @__nv_sincosf(float %x, i64 %8, i64 %9)
; CHECK-NEXT:   %10 = load float, ptr %0, align 4
; CHECK-NEXT:   %11 = load float, ptr %1, align 4
; CHECK-NEXT:   %12 = fmul fast float %11, %6
; CHECK-NEXT:   %13 = fmul fast float %10, %7
; CHECK-NEXT:   %14 = fneg fast float %13
; CHECK-NEXT:   %15 = fadd fast float %12, %14
; CHECK-NEXT:   %16 = insertvalue { float } undef, float %15, 0
; CHECK-NEXT:   ret { float } %16
; CHECK-NEXT: }

; CHECK: define internal { double } @diffetester_copy(double %x, ptr nocapture writeonly %out, ptr {{(nocapture )?}}%"out'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca double, align 8
; CHECK-NEXT:   %1 = alloca double, align 8
; CHECK-NEXT:   %"pair'ipa" = alloca [2 x double], align 8
; CHECK-NEXT:   store [2 x double] zeroinitializer, ptr %"pair'ipa", align 8
; CHECK-NEXT:   %pair = alloca [2 x double], align 8
; CHECK-NEXT:   %"p1'ipg" = getelementptr double, ptr %"pair'ipa", i64 1
; CHECK-NEXT:   %p1 = getelementptr double, ptr %pair, i64 1
; CHECK-NEXT:   call void @sincos(double %x, ptr %pair, ptr %p1)
; CHECK-NEXT:   call void @llvm.memcpy.p0.p0.i64(ptr %out, ptr %pair, i64 16, i1 false)
; CHECK-NEXT:   br label %for.body.i

; CHECK: for.body.i:
; CHECK-NEXT:   %idx.i = phi i64 [ 0, %entry ], [ %idx.next.i, %for.body.i ]
; CHECK-NEXT:   %dst.i.i = getelementptr inbounds double, ptr %"out'", i64 %idx.i
; CHECK-NEXT:   %dst.i.l.i = load double, ptr %dst.i.i, align 1
; CHECK-NEXT:   store double 0.000000e+00, ptr %dst.i.i, align 1
; CHECK-NEXT:   %src.i.i = getelementptr inbounds double, ptr %"pair'ipa", i64 %idx.i
; CHECK-NEXT:   %src.i.l.i = load double, ptr %src.i.i, align 1
; CHECK-NEXT:   %2 = fadd fast double %src.i.l.i, %dst.i.l.i
; CHECK-NEXT:   store double %2, ptr %src.i.i, align 1
; CHECK-NEXT:   %idx.next.i = add nuw i64 %idx.i, 1
; CHECK-NEXT:   %3 = icmp eq i64 2, %idx.next.i
; CHECK-NEXT:   br i1 %3, label %__enzyme_memcpyadd_doubleda1sa1.exit, label %for.body.i

; CHECK: __enzyme_memcpyadd_doubleda1sa1.exit:
; CHECK-NEXT:   %4 = load double, ptr %"pair'ipa", align 8
; CHECK-NEXT:   store double 0.000000e+00, ptr %"pair'ipa", align 8
; CHECK-NEXT:   %5 = load double, ptr %"p1'ipg", align 8
; CHECK-NEXT:   store double 0.000000e+00, ptr %"p1'ipg", align 8
; CHECK-NEXT:   call void @sincos(double %x, ptr %0, ptr %1)
; CHECK-NEXT:   %6 = load double, ptr %0, align 8
; CHECK-NEXT:   %7 = load double, ptr %1, align 8
; CHECK-NEXT:   %8 = fmul fast double %7, %4
; CHECK-NEXT:   %9 = fmul fast double %6, %5
; CHECK-NEXT:   %10 = fneg fast double %9
; CHECK-NEXT:   %11 = fadd fast double %8, %10
; CHECK-NEXT:   %12 = insertvalue { double } undef, double %11, 0
; CHECK-NEXT:   ret { double } %12
; CHECK-NEXT: }

; CHECK: define internal { ptr, ptr } @augmented_h(double %x, ptr writeonly %s, ptr %"s'", ptr nocapture %pp, ptr {{(nocapture )?}}%"pp'")
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca { ptr, ptr }, align 8
; CHECK-NEXT:   %"c'ipl" = load ptr, ptr %"pp'", align 8
; CHECK-NEXT:   store ptr %"c'ipl", ptr %0, align 8
; CHECK-NEXT:   %c = load ptr, ptr %pp, align 8
; CHECK-NEXT:   %1 = getelementptr inbounds { ptr, ptr }, ptr %0, i32 0, i32 1
; CHECK-NEXT:   store ptr %c, ptr %1, align 8
; CHECK-NEXT:   call void @sincos(double %x, ptr %s, ptr %c)
; CHECK-NEXT:   store ptr null, ptr %"pp'", align 8
; CHECK-NEXT:   store ptr null, ptr %pp, align 8
; CHECK-NEXT:   %2 = load { ptr, ptr }, ptr %0, align 8
; CHECK-NEXT:   ret { ptr, ptr } %2
; CHECK-NEXT: }

; CHECK: define internal { double } @diffeh(double %x, ptr writeonly %s, ptr %"s'", ptr nocapture %pp, ptr {{(nocapture )?}}%"pp'", { ptr, ptr } %tapeArg)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = alloca double, align 8
; CHECK-NEXT:   %1 = alloca double, align 8
; CHECK-NEXT:   %"c'il_phi" = extractvalue { ptr, ptr } %tapeArg, 0
; CHECK-NEXT:   %c = extractvalue { ptr, ptr } %tapeArg, 1
; CHECK-NEXT:   %2 = icmp ne ptr %s, %"s'"
; CHECK-NEXT:   %3 = load double, ptr %"s'", align 8
; CHECK-NEXT:   %4 = select fast i1 %2, double 0.000000e+00, double %3
; CHECK-NEXT:   store double %4, ptr %"s'", align 8
; CHECK-NEXT:   %5 = select fast i1 %2, double %3, double 0.000000e+00
; CHECK-NEXT:   %6 = icmp ne ptr %c, %"c'il_phi"
; CHECK-NEXT:   %7 = load double, ptr %"c'il_phi", align 8
; CHECK-NEXT:   %8 = select fast i1 %6, double 0.000000e+00, double %7
; CHECK-NEXT:   store double %8, ptr %"c'il_phi", align 8
; CHECK-NEXT:   %9 = select fast i1 %6, double %7, double 0.000000e+00
; CHECK-NEXT:   call void @sincos(double %x, ptr %0, ptr %1)
; CHECK-NEXT:   %10 = load double, ptr %0, align 8
; CHECK-NEXT:   %11 = load double, ptr %1, align 8
; CHECK-NEXT:   %12 = fmul fast double %11, %5
; CHECK-NEXT:   %13 = fmul fast double %10, %9
; CHECK-NEXT:   %14 = fneg fast double %13
; CHECK-NEXT:   %15 = fadd fast double %12, %14
; CHECK-NEXT:   %16 = insertvalue { double } undef, double %15, 0
; CHECK-NEXT:   ret { double } %16
; CHECK-NEXT: }
