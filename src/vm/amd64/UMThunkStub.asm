; Licensed to the .NET Foundation under one or more agreements.
; The .NET Foundation licenses this file to you under the MIT license.
; See the LICENSE file in the project root for more information.

; ==++==
;

;
; ==--==

include <AsmMacros.inc>
include AsmConstants.inc

gfHostConfig                            equ ?g_fHostConfig@@3KA
NDirect__IsHostHookEnabled              equ ?IsHostHookEnabled@NDirect@@SAHXZ

extern CreateThreadBlockThrow:proc
extern TheUMEntryPrestubWorker:proc
extern UMEntryPrestubUnwindFrameChainHandler:proc
extern UMThunkStubUnwindFrameChainHandler:proc
extern g_TrapReturningThreads:dword
extern UM2MDoADCallBack:proc
extern UMThunkStubRareDisableWorker:proc
extern ReversePInvokeBadTransition:proc

;
; METHODDESC_REGISTER: UMEntryThunk*
;
NESTED_ENTRY TheUMEntryPrestub, _TEXT, UMEntryPrestubUnwindFrameChainHandler

TheUMEntryPrestub_STACK_FRAME_SIZE = SIZEOF_MAX_OUTGOING_ARGUMENT_HOMES

; XMM save area
TheUMEntryPrestub_XMM_SAVE_OFFSET = TheUMEntryPrestub_STACK_FRAME_SIZE
TheUMEntryPrestub_STACK_FRAME_SIZE = TheUMEntryPrestub_STACK_FRAME_SIZE + SIZEOF_MAX_FP_ARG_SPILL

; Ensure that the new rsp will be 16-byte aligned.  Note that the caller has
; already pushed the return address.
if ((TheUMEntryPrestub_STACK_FRAME_SIZE + 8) MOD 16) ne 0
TheUMEntryPrestub_STACK_FRAME_SIZE = TheUMEntryPrestub_STACK_FRAME_SIZE + 8
endif

        alloc_stack     TheUMEntryPrestub_STACK_FRAME_SIZE

        save_reg_postrsp    rcx, TheUMEntryPrestub_STACK_FRAME_SIZE + 8h
        save_reg_postrsp    rdx, TheUMEntryPrestub_STACK_FRAME_SIZE + 10h
        save_reg_postrsp    r8,  TheUMEntryPrestub_STACK_FRAME_SIZE + 18h
        save_reg_postrsp    r9,  TheUMEntryPrestub_STACK_FRAME_SIZE + 20h

        save_xmm128_postrsp xmm0, TheUMEntryPrestub_XMM_SAVE_OFFSET
        save_xmm128_postrsp xmm1, TheUMEntryPrestub_XMM_SAVE_OFFSET + 10h
        save_xmm128_postrsp xmm2, TheUMEntryPrestub_XMM_SAVE_OFFSET + 20h
        save_xmm128_postrsp xmm3, TheUMEntryPrestub_XMM_SAVE_OFFSET + 30h

        END_PROLOGUE

        ;
        ; Do prestub-specific stuff
        ;
        mov             rcx, METHODDESC_REGISTER
        call            TheUMEntryPrestubWorker

        ;
        ; we're going to tail call to the exec stub that we just setup
        ;

        mov             rcx, [rsp + TheUMEntryPrestub_STACK_FRAME_SIZE + 8h]
        mov             rdx, [rsp + TheUMEntryPrestub_STACK_FRAME_SIZE + 10h]
        mov             r8,  [rsp + TheUMEntryPrestub_STACK_FRAME_SIZE + 18h]
        mov             r9,  [rsp + TheUMEntryPrestub_STACK_FRAME_SIZE + 20h]

        movdqa          xmm0, xmmword ptr [rsp + TheUMEntryPrestub_XMM_SAVE_OFFSET]
        movdqa          xmm1, xmmword ptr [rsp + TheUMEntryPrestub_XMM_SAVE_OFFSET + 10h]
        movdqa          xmm2, xmmword ptr [rsp + TheUMEntryPrestub_XMM_SAVE_OFFSET + 20h]
        movdqa          xmm3, xmmword ptr [rsp + TheUMEntryPrestub_XMM_SAVE_OFFSET + 30h]

        ;
        ; epilogue
        ;
        add             rsp, TheUMEntryPrestub_STACK_FRAME_SIZE
        TAILJMP_RAX
        
NESTED_END TheUMEntryPrestub, _TEXT


;
; METHODDESC_REGISTER: UMEntryThunk*
;
NESTED_ENTRY UMThunkStub, _TEXT, UMThunkStubUnwindFrameChainHandler

UMThunkStubAMD64_STACK_FRAME_SIZE = 0

; number of integer registers saved in prologue
UMThunkStubAMD64_NUM_REG_PUSHES = 2
UMThunkStubAMD64_STACK_FRAME_SIZE = UMThunkStubAMD64_STACK_FRAME_SIZE + (UMThunkStubAMD64_NUM_REG_PUSHES * 8)

; rare path spill area
UMThunkStubAMD64_RARE_PATH_SPILL_SIZE = 10h
UMThunkStubAMD64_STACK_FRAME_SIZE = UMThunkStubAMD64_STACK_FRAME_SIZE + UMThunkStubAMD64_RARE_PATH_SPILL_SIZE 
UMThunkStubAMD64_RARE_PATH_SPILL_NEGOFFSET = UMThunkStubAMD64_STACK_FRAME_SIZE



; HOST_NOTIFY_FLAG
UMThunkStubAMD64_STACK_FRAME_SIZE = UMThunkStubAMD64_STACK_FRAME_SIZE + 8
UMThunkStubAMD64_HOST_NOTIFY_FLAG_NEGOFFSET = UMThunkStubAMD64_STACK_FRAME_SIZE

; XMM save area 
UMThunkStubAMD64_STACK_FRAME_SIZE = UMThunkStubAMD64_STACK_FRAME_SIZE + SIZEOF_MAX_FP_ARG_SPILL

; Ensure that the offset of the XMM save area will be 16-byte aligned.
if ((UMThunkStubAMD64_STACK_FRAME_SIZE + 8) MOD 16) ne 0        ; +8 for caller-pushed return address
UMThunkStubAMD64_STACK_FRAME_SIZE = UMThunkStubAMD64_STACK_FRAME_SIZE + 8
endif

UMThunkStubAMD64_XMM_SAVE_NEGOFFSET = UMThunkStubAMD64_STACK_FRAME_SIZE

; Add in the callee scratch area size.
UMThunkStubAMD64_CALLEE_SCRATCH_SIZE = SIZEOF_MAX_OUTGOING_ARGUMENT_HOMES
UMThunkStubAMD64_STACK_FRAME_SIZE = UMThunkStubAMD64_STACK_FRAME_SIZE + UMThunkStubAMD64_CALLEE_SCRATCH_SIZE

; Now we have the full size of the stack frame.  The offsets have been computed relative to the
; top, so negate them to make them relative to the post-prologue rsp.
UMThunkStubAMD64_FRAME_OFFSET = UMThunkStubAMD64_CALLEE_SCRATCH_SIZE
UMThunkStubAMD64_RARE_PATH_SPILL_OFFSET = UMThunkStubAMD64_STACK_FRAME_SIZE - UMThunkStubAMD64_FRAME_OFFSET - UMThunkStubAMD64_RARE_PATH_SPILL_NEGOFFSET
UMThunkStubAMD64_HOST_NOTIFY_FLAG_OFFSET = UMThunkStubAMD64_STACK_FRAME_SIZE - UMThunkStubAMD64_FRAME_OFFSET - UMThunkStubAMD64_HOST_NOTIFY_FLAG_NEGOFFSET 
UMThunkStubAMD64_XMM_SAVE_OFFSET = UMThunkStubAMD64_STACK_FRAME_SIZE - UMThunkStubAMD64_FRAME_OFFSET - UMThunkStubAMD64_XMM_SAVE_NEGOFFSET 
UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET = UMThunkStubAMD64_STACK_FRAME_SIZE + 8 - UMThunkStubAMD64_FRAME_OFFSET    ; +8 for return address
UMThunkStubAMD64_FIXED_STACK_ALLOC_SIZE = UMThunkStubAMD64_STACK_FRAME_SIZE - (UMThunkStubAMD64_NUM_REG_PUSHES * 8)

.errnz UMTHUNKSTUB_HOST_NOTIFY_FLAG_RBPOFFSET - UMThunkStubAMD64_HOST_NOTIFY_FLAG_OFFSET, update UMTHUNKSTUB_HOST_NOTIFY_FLAG_RBPOFFSET


;
; [ callee scratch ]            <-- new RSP
; [ callee scratch ]
; [ callee scratch ]
; [ callee scratch ]
; {optional stack args passed to callee}
; xmm0                          <-- RBP
; xmm1
; xmm2
; xmm3
; {optional padding to align xmm regs}
; HOST_NOTIFY_FLAG (needs to make ReverseLeaveRuntime call flag)
; [rare path spill area]
; [rare path spill area]
; rbp save
; r12 save
; return address                <-- entry RSP
; [rcx home]
; [rdx home]
; [r8 home]
; [r9 home]
; stack arg 0
; stack arg 1
; ...

        push_nonvol_reg r12
        push_nonvol_reg rbp                                                                     ; stack_args
        alloc_stack     UMThunkStubAMD64_FIXED_STACK_ALLOC_SIZE
        set_frame       rbp, UMThunkStubAMD64_FRAME_OFFSET                                      ; stack_args
        mov             byte ptr [rbp + UMThunkStubAMD64_HOST_NOTIFY_FLAG_OFFSET], 0            ; hosted
        END_PROLOGUE

        ;
        ; Call GetThread()
        ;
        CALL_GETTHREAD                          ; will not trash r10
        test            rax, rax
        jz              DoThreadSetup

HaveThread:

        mov             r12, rax                ; r12 <- Thread*

        ;FailFast if a native callable method invoked via ldftn and calli.
        cmp             dword ptr [r12 + OFFSETOF__Thread__m_fPreemptiveGCDisabled], 1
        jz              InvalidTransition

        ;
        ; disable preemptive GC
        ;
        mov             dword ptr [r12 + OFFSETOF__Thread__m_fPreemptiveGCDisabled], 1

        ;
        ; catch returning thread here if a GC is in progress
        ;
        cmp             [g_TrapReturningThreads], 0
        jnz             DoTrapReturningThreadsTHROW

InCooperativeMode:

        mov             rax, [r12 + OFFSETOF__Thread__m_pDomain]
        mov             eax, [rax + OFFSETOF__AppDomain__m_dwId]

        mov             r11d, [METHODDESC_REGISTER + OFFSETOF__UMEntryThunk__m_dwDomainId]

        cmp             rax, r11
        jne             WrongAppDomain

        mov             r11, [METHODDESC_REGISTER + OFFSETOF__UMEntryThunk__m_pUMThunkMarshInfo]
        mov             eax, [r11 + OFFSETOF__UMThunkMarshInfo__m_cbActualArgSize]                      ; stack_args
        test            rax, rax                                                                        ; stack_args
        jnz             CopyStackArgs                                                                   ; stack_args
        
ArgumentsSetup:

        mov             rax, [r11 + OFFSETOF__UMThunkMarshInfo__m_pILStub]                              ; rax <- Stub*
        call            rax

PostCall:
        ;
        ; enable preemptive GC
        ;
        mov             dword ptr [r12 + OFFSETOF__Thread__m_fPreemptiveGCDisabled], 0

        ; epilog
        lea             rsp, [rbp - UMThunkStubAMD64_FRAME_OFFSET + UMThunkStubAMD64_FIXED_STACK_ALLOC_SIZE]
        pop             rbp                                                                             ; stack_args
        pop             r12
        ret


DoThreadSetup:
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h], rcx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  8h], rdx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h], r8
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 18h], r9

        ; @CONSIDER: mark UMEntryThunks that have FP params and only save/restore xmm regs on those calls
        ;            initial measurements indidcate that this could be worth about a 5% savings in reverse
        ;            pinvoke overhead.
        movdqa          xmmword ptr[rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET +  0h], xmm0
        movdqa          xmmword ptr[rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 10h], xmm1
        movdqa          xmmword ptr[rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 20h], xmm2
        movdqa          xmmword ptr[rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 30h], xmm3

        mov             [rbp + UMThunkStubAMD64_RARE_PATH_SPILL_OFFSET], METHODDESC_REGISTER
        call            CreateThreadBlockThrow
        mov             METHODDESC_REGISTER, [rbp + UMThunkStubAMD64_RARE_PATH_SPILL_OFFSET]

        mov             rcx,  [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h] 
        mov             rdx,  [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  8h] 
        mov             r8,   [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h] 
        mov             r9,   [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 18h]

        ; @CONSIDER: mark UMEntryThunks that have FP params and only save/restore xmm regs on those calls
        movdqa          xmm0, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET +  0h]
        movdqa          xmm1, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 10h]
        movdqa          xmm2, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 20h]
        movdqa          xmm3, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 30h]
        
        jmp             HaveThread
        
InvalidTransition:
        ; ReversePInvokeBadTransition will failfast
        call            ReversePInvokeBadTransition

DoTrapReturningThreadsTHROW:

        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h], rcx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  8h], rdx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h], r8
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 18h], r9

        ; @CONSIDER: mark UMEntryThunks that have FP params and only save/restore xmm regs on those calls
        ;            initial measurements indidcate that this could be worth about a 5% savings in reverse
        ;            pinvoke overhead.
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET +  0h], xmm0
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 10h], xmm1
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 20h], xmm2
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 30h], xmm3

        mov             [rbp + UMThunkStubAMD64_RARE_PATH_SPILL_OFFSET], METHODDESC_REGISTER
        mov             rcx, r12                                                                  ; Thread* pThread
        mov             rdx, METHODDESC_REGISTER                                                  ; UMEntryThunk* pUMEntry
        call            UMThunkStubRareDisableWorker
        mov             METHODDESC_REGISTER, [rbp + UMThunkStubAMD64_RARE_PATH_SPILL_OFFSET]

        mov             rcx,  [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h] 
        mov             rdx,  [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  8h] 
        mov             r8,   [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h] 
        mov             r9,   [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 18h]

        ; @CONSIDER: mark UMEntryThunks that have FP params and only save/restore xmm regs on those calls
        movdqa          xmm0, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET +  0h]
        movdqa          xmm1, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 10h]
        movdqa          xmm2, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 20h]
        movdqa          xmm3, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 30h]

        jmp             InCooperativeMode

CopyStackArgs:
        ; rax = cbStackArgs (with 20h for register args subtracted out already)

        sub             rsp, rax
        and             rsp, -16

        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h], rcx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  8h], rdx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h], r8

        ; rax = number of bytes

        lea             rcx, [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + SIZEOF_MAX_OUTGOING_ARGUMENT_HOMES] 
        lea             rdx, [rsp + UMThunkStubAMD64_CALLEE_SCRATCH_SIZE]

CopyLoop:
        ; rax = number of bytes
        ; rcx = src
        ; rdx = dest
        ; r8 = sratch

        add             rax, -8
        mov             r8, [rcx + rax]
        mov             [rdx + rax], r8
        jnz             CopyLoop

        mov             rcx, [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h]
        mov             rdx, [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  8h]
        mov             r8, [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h]
        
        jmp             ArgumentsSetup


WrongAppDomain:
        ;
        ; home register args to the stack
        ;
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h], rcx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  8h], rdx
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h], r8
        mov             [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 18h], r9

        ;
        ; save off xmm registers
        ;
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET +  0h], xmm0
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 10h], xmm1
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 20h], xmm2
        movdqa          xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET + 30h], xmm3

        ;
        ; call our helper to perform the AD transtion 
        ;
        mov             rcx, METHODDESC_REGISTER
        lea             r8,  [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET]
        mov             rax, [METHODDESC_REGISTER + OFFSETOF__UMEntryThunk__m_pUMThunkMarshInfo]
        mov             r9d, [rax + OFFSETOF__UMThunkMarshInfo__m_cbActualArgSize]
        call            UM2MDoADCallBack

        ; restore return value
        mov             rax,  [rbp + UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h]
        movdqa          xmm0, xmmword ptr [rbp + UMThunkStubAMD64_XMM_SAVE_OFFSET +  0h]

        jmp             PostCall

NESTED_END UMThunkStub, _TEXT

;
; EXTERN_C void __stdcall UM2MThunk_WrapperHelper(
;       void *pThunkArgs,               ; rcx
;       int argLen,                     ; rdx
;       void *pAddr,                    ; r8            // not used
;       UMEntryThunk *pEntryThunk,      ; r9
;       Thread *pThread);               ; [entry_sp + 28h]
;
NESTED_ENTRY UM2MThunk_WrapperHelper, _TEXT


UM2MThunk_WrapperHelper_STACK_FRAME_SIZE = 0

; number of integer registers saved in prologue
UM2MThunk_WrapperHelper_NUM_REG_PUSHES = 3
UM2MThunk_WrapperHelper_STACK_FRAME_SIZE = UM2MThunk_WrapperHelper_STACK_FRAME_SIZE + (UM2MThunk_WrapperHelper_NUM_REG_PUSHES * 8)

UM2MThunk_WrapperHelper_CALLEE_SCRATCH_SIZE = SIZEOF_MAX_OUTGOING_ARGUMENT_HOMES
UM2MThunk_WrapperHelper_STACK_FRAME_SIZE = UM2MThunk_WrapperHelper_STACK_FRAME_SIZE + UM2MThunk_WrapperHelper_CALLEE_SCRATCH_SIZE

; Ensure that rsp remains 16-byte aligned
if ((UM2MThunk_WrapperHelper_STACK_FRAME_SIZE + 8) MOD 16) ne 0        ; +8 for caller-pushed return address
UM2MThunk_WrapperHelper_STACK_FRAME_SIZE = UM2MThunk_WrapperHelper_STACK_FRAME_SIZE + 8
endif

UM2MThunk_WrapperHelper_FRAME_OFFSET = UM2MThunk_WrapperHelper_CALLEE_SCRATCH_SIZE
UM2MThunk_WrapperHelper_FIXED_STACK_ALLOC_SIZE = UM2MThunk_WrapperHelper_STACK_FRAME_SIZE - (UM2MThunk_WrapperHelper_NUM_REG_PUSHES * 8)

        push_nonvol_reg rsi
        push_nonvol_reg rdi
        push_nonvol_reg rbp
        alloc_stack     UM2MThunk_WrapperHelper_FIXED_STACK_ALLOC_SIZE
        set_frame       rbp, UM2MThunk_WrapperHelper_FRAME_OFFSET
        END_PROLOGUE

        ;
        ; We are in cooperative mode and in the correct domain. 
        ; The host has also been notified that we've entered the 
        ; runtime.  All we have left to do is to copy the stack, 
        ; setup the register args and then call the managed target
        ;

        test            rdx, rdx
        jg              CopyStackArgs

ArgumentsSetup:
        mov             METHODDESC_REGISTER, r9

        mov             rsi, rcx                ; rsi <- pThunkArgs
        mov             rcx, [rsi +  0h]
        mov             rdx, [rsi +  8h]
        mov             r8,  [rsi + 10h]
        mov             r9,  [rsi + 18h]

        movdqa          xmm0, xmmword ptr [rsi + UMThunkStubAMD64_XMM_SAVE_OFFSET - UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h]
        movdqa          xmm1, xmmword ptr [rsi + UMThunkStubAMD64_XMM_SAVE_OFFSET - UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 10h]
        movdqa          xmm2, xmmword ptr [rsi + UMThunkStubAMD64_XMM_SAVE_OFFSET - UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 20h]
        movdqa          xmm3, xmmword ptr [rsi + UMThunkStubAMD64_XMM_SAVE_OFFSET - UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET + 30h]

        mov             rax, [METHODDESC_REGISTER + OFFSETOF__UMEntryThunk__m_pUMThunkMarshInfo]      ; rax <- UMThunkMarshInfo*
        mov             rax, [rax + OFFSETOF__UMThunkMarshInfo__m_pILStub]                              ; rax <- Stub*
        call            rax

        ; make sure we don't trash the return value
        mov             [rsi + 0h], rax
        movdqa          xmmword ptr [rsi + UMThunkStubAMD64_XMM_SAVE_OFFSET - UMThunkStubAMD64_ARGUMENTS_STACK_HOME_OFFSET +  0h], xmm0

        lea             rsp, [rbp - UM2MThunk_WrapperHelper_FRAME_OFFSET + UM2MThunk_WrapperHelper_FIXED_STACK_ALLOC_SIZE]
        pop             rbp
        pop             rdi
        pop             rsi
        ret
        

CopyStackArgs:
        ; rdx = cbStackArgs (with 20h for register args subtracted out already)
        ; rcx = pSrcArgStack

        sub             rsp, rdx
        and             rsp, -16

        mov             r8, rcx
        
        lea             rsi, [rcx + SIZEOF_MAX_OUTGOING_ARGUMENT_HOMES]
        lea             rdi, [rsp + UM2MThunk_WrapperHelper_CALLEE_SCRATCH_SIZE]

        mov             rcx, rdx
        shr             rcx, 3
        
        rep movsq
        
        mov             rcx, r8
        
        jmp             ArgumentsSetup
        
NESTED_END UM2MThunk_WrapperHelper, _TEXT

        end

