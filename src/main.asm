; #########################################################################
;
;             GENERIC.ASM is a roadmap around a standard 32 bit 
;              windows application skeleton written in MASM32.
;
; #########################################################################

;           Assembler specific instructions for 32 bit ASM code

      .586                   ; minimum processor needed for 32 bit
      .model flat, stdcall   ; FLAT memory model & STDCALL calling
      option casemap :none   ; set code to case sensitive

; #########################################################################

      ; ---------------------------------------------
      ; main include file with equates and structures
      ; ---------------------------------------------
      include \masm32\include\windows.inc

      ; -------------------------------------------------------------
      ; In MASM32, each include file created by the L2INC.EXE utility
      ; has a matching library file. If you need functions from a
      ; specific library, you use BOTH the include file and library
      ; file for that library.
      ; -------------------------------------------------------------

      include \masm32\include\user32.inc
      include \masm32\include\kernel32.inc

      include \MASM32\INCLUDE\gdi32.inc
      
      
      includelib \masm32\lib\user32.lib
      includelib \masm32\lib\kernel32.lib

      includelib \MASM32\LIB\gdi32.lib
      
      
; #########################################################################

; ------------------------------------------------------------------------
; MACROS are a method of expanding text at assembly time. This allows the
; programmer a tidy and convenient way of using COMMON blocks of code with
; the capacity to use DIFFERENT parameters in each block.
; ------------------------------------------------------------------------

      ; 1. szText
      ; A macro to insert TEXT into the code section for convenient and 
      ; more intuitive coding of functions that use byte data as text.

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      ; 2. m2m
      ; There is no mnemonic to copy from one memory location to another,
      ; this macro saves repeated coding of this process and is easier to
      ; read in complex code.

      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM

      ; 3. return
      ; Every procedure MUST have a "ret" to return the instruction
      ; pointer EIP back to the next instruction after the call that
      ; branched to it. This macro puts a return value in eax and
      ; makes the "ret" instruction on one line. It is mainly used
      ; for clear coding in complex conditionals in large branching
      ; code such as the WndProc procedure.

      return MACRO arg
        mov eax, arg
        ret
      ENDM

; #########################################################################

; ----------------------------------------------------------------------
; Prototypes are used in conjunction with the MASM "invoke" syntax for
; checking the number and size of parameters passed to a procedure. This
; improves the reliability of code that is written where errors in
; parameters are caught and displayed at assembly time.
; ----------------------------------------------------------------------

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY PROTO   :DWORD,:DWORD
        GetSpriteFromMousePos PROTO
        RestartGame PROTO
        ShowColors PROTO
        Random PROTO range:DWORD  

; #########################################################################

; ------------------------------------------------------------------------
; This is the INITIALISED data section meaning that data declared here has
; an initial value. You can also use an UNINIALISED section if you need
; data of that type [ .data? ]. Note that they are different and occur in
; different sections.
; ------------------------------------------------------------------------

    .data
        WM_FINISH     equ WM_USER+100h

        ; TODO: Tirar daqui
        buffer        db 256 dup(0)

        ; aleatorização de valores
        prng_x        dd 0
        prng_a        dd 180574328

        szDisplayName db "Genius",0
        CommandLine   dd 0
        hWnd          dd 0
        hInstance     dd 0

        colors dd 256 dup(0) ; cores do jogo
        currentIndex  dd 0 ; indice no vetor de cores
        currentColor  dd 0 ; usado para desenho
        showingColors dd 1

        acceptClick db 0     ; se é para aceitar um click
        
        currentSprite dd 0

        SPRITESHEET_RESOURCE_ID equ 1

        SPRITE_WIDTH equ 500
        SPRITE_HEIGHT equ 500

        WINDOW_WIDTH equ 520
        WINDOW_HEIGHT equ 542

        PC_DELAY_TIME equ 500
        MOUSE_DELAY_TIME equ 75
    
    .data?
        txt         DB  ?
        colors_spriteset dd ?
        mousepos POINT<>
        
        ; Threads
        ThreadID      DWORD   ?
        hEventStart   HANDLE  ?
        dwExitCode    LPDWORD ?   

; #########################################################################

; ------------------------------------------------------------------------
; This is the start of the code section where executable code begins. This
; section ending with the ExitProcess() API function call is the only
; GLOBAL section of code and it provides access to the WinMain function
; with the necessary parameters, the instance handle and the command line
; address.
; ------------------------------------------------------------------------

    .code

; -----------------------------------------------------------------------
; The label "start:" is the address of the start of the code section and
; it has a matching "end start" at the end of the file. All procedures in
; this module must be written between these two.
; -----------------------------------------------------------------------

start:
    invoke GetModuleHandle, NULL ; provides the instance handle
    mov hInstance, eax

    invoke GetCommandLine        ; provides the command line address
    mov CommandLine, eax

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
    
    invoke ExitProcess,eax       ; cleanup & return to operating system

; #########################################################################

WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

        ;====================
        ; Put LOCALs on stack
        ;====================

        LOCAL wc   :WNDCLASSEX
        LOCAL msg  :MSG

        LOCAL ww  :DWORD
        LOCAL wh  :DWORD
        LOCAL Wtx  :DWORD
        LOCAL Wty  :DWORD

        szText szClassName,"Generic_Class"

        ;==================================================
        ; Fill WNDCLASSEX structure with required variables
        ;==================================================

        mov wc.cbSize,         sizeof WNDCLASSEX
        mov wc.style,          CS_HREDRAW or CS_VREDRAW \
                               or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
        mov wc.cbClsExtra,     NULL
        mov wc.cbWndExtra,     NULL
        m2m wc.hInstance,      hInst               ; instance handle
        mov wc.hbrBackground,  COLOR_BTNFACE+1     ; system color
        mov wc.lpszMenuName,   NULL
        mov wc.lpszClassName,  offset szClassName  ; window class name
          invoke LoadIcon,hInst,500    ; icon ID   ; resource icon
        mov wc.hIcon,          eax
          invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
        mov wc.hCursor,        eax
        mov wc.hIconSm,        0

        invoke RegisterClassEx, ADDR wc     ; register the window class

        ;================================
        ; Centre window at following size
        ;================================

        mov ww, WINDOW_WIDTH
        mov wh, WINDOW_HEIGHT

        invoke GetSystemMetrics,SM_CXSCREEN ; get screen width in pixels
        invoke TopXY,ww,eax
        mov Wtx, eax

        invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
        invoke TopXY,wh,eax
        mov Wty, eax

        ; ==================================
        ; Create the main application window
        ; ==================================
        invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,
                              ADDR szClassName,
                              ADDR szDisplayName,
                              WS_OVERLAPPEDWINDOW,
                              Wtx,Wty,ww,wh,
                              NULL,NULL,
                              hInst,NULL

        mov   hWnd,eax  ; copy return value into handle DWORD

        invoke LoadMenu,hInst,600                 ; load resource menu
        invoke SetMenu,hWnd,eax                   ; set it to main window

        invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
        invoke UpdateWindow,hWnd                  ; update the display

        ; Inicializa a thread
        invoke CreateEvent, NULL, FALSE, FALSE, NULL
        mov    hEventStart, eax
        mov    eax, OFFSET ThreadProc
        invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR ThreadID

      ;===================================
      ; Aleatorizar o vetor de cores
      ;===================================
        invoke RestartGame

      ;===================================
      ; Loop until PostQuitMessage is sent
      ;===================================

    StartLoop:
        invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
        cmp eax, 0                                  ; exit if GetMessage()
        je ExitLoop                                 ; returns zero
        invoke TranslateMessage, ADDR msg           ; translate it
        invoke DispatchMessage,  ADDR msg           ; send it to message proc
        jmp StartLoop
    ExitLoop:

      return msg.wParam

WinMain endp

; #########################################################################

WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

    LOCAL hdc       :DWORD
    LOCAL Ps        :PAINTSTRUCT
    LOCAL hTmpImgDC :HDC

; -------------------------------------------------------------------------
; Message are sent by the operating system to an application through the
; WndProc proc. Each message can have additional values associated with it
; in the two parameters, wParam & lParam. The range of additional data that
; can be passed to an application is determined by the message.
; -------------------------------------------------------------------------

     

    .if uMsg == WM_COMMAND
    ;----------------------------------------------------------------------
    ; The WM_COMMAND message is sent by menus, buttons and toolbar buttons.
    ; Processing the wParam parameter of it is the method of obtaining the
    ; control's ID number so that the code for each operation can be
    ; processed. NOTE that the ID number is in the LOWORD of the wParam
    ; passed with the WM_COMMAND message. There may be some instances where
    ; an application needs to seperate the high and low words of wParam.
    ; ---------------------------------------------------------------------
    
    ;======== menu commands ========

        .if wParam == 1000
            invoke SendMessage,hWin,WM_SYSCOMMAND,SC_CLOSE,NULL
        .elseif wParam == 1900
            szText TheMsg,"Assembler, Pure & Simple"
            invoke MessageBox,hWin,ADDR TheMsg,ADDR szDisplayName,MB_OK
        .endif

    ;====== end menu commands ======
    .elseif uMsg == WM_LBUTTONDOWN
        .if acceptClick != 0 ; apenas se estiver aceitando click
            mov	eax, lParam
            and	eax, 0000FFFFh
            mov	mousepos.x, eax
            mov	eax, lParam
            shr	eax, 16
            and	eax, 0000FFFFh
            mov	mousepos.y, eax

            invoke GetSpriteFromMousePos ; obtém a imagem atual
            mov currentSprite, eax ; sprite atual é a correspondente ao click

            invoke InvalidateRect,hWnd,NULL,TRUE
        .endif

    .elseif uMsg == WM_LBUTTONUP
        invoke Sleep, MOUSE_DELAY_TIME
        mov currentSprite, 0
        invoke InvalidateRect,hWnd,NULL,TRUE

    .elseif uMsg == WM_FINISH
        ; Renderiza a tela
        invoke  InvalidateRect, hWnd, NULL, TRUE

    .elseif uMsg == WM_PAINT

        invoke BeginPaint,hWin,ADDR Ps
        mov    hdc, eax

        invoke CreateCompatibleDC, hdc
        
        mov hTmpImgDC, eax ; ponteiro para o handle da imagem em eax
        invoke SelectObject, hTmpImgDC, colors_spriteset ; move uma sprite para o handle
        
        ; escolhe a coordenada x da sprite
        mov ebx, currentSprite
        imul ebx, 500

        invoke BitBlt, hdc, 0, 0, SPRITE_WIDTH, SPRITE_HEIGHT, hTmpImgDC, ebx, 0, MERGECOPY
        invoke DeleteDC, hTmpImgDC

        invoke EndPaint,hWin,ADDR Ps
        return  0


    .elseif uMsg == WM_CREATE
    ; --------------------------------------------------------------------
    ; This message is sent to WndProc during the CreateWindowEx function
    ; call and is processed before it returns. This is used as a mousepos
    ; to start other items such as controls. IMPORTANT, the handle for the
    ; CreateWindowEx call in the WinMain does not yet exist so the HANDLE
    ; passed to the WndProc [ hWin ] must be used here for any controls
    ; or child windows.
    ; --------------------------------------------------------------------

    ; carrega as sprites
    invoke LoadBitmap, hInstance, SPRITESHEET_RESOURCE_ID
    mov colors_spriteset, eax

    .elseif uMsg == WM_CLOSE
    ; -------------------------------------------------------------------
    ; This is the place where various requirements are performed before
    ; the application exits to the operating system such as deleting
    ; resources and testing if files have been saved. You have the option
    ; of returning ZERO if you don't wish the application to close which
    ; exits the WndProc procedure without passing this message to the
    ; default window processing done by the operating system.
    ; -------------------------------------------------------------------
        invoke PostQuitMessage, NULL
        return 0

    .elseif uMsg == WM_DESTROY
    ; ----------------------------------------------------------------
    ; This message MUST be processed to cleanly exit the application.
    ; Calling the PostQuitMessage() function makes the GetMessage()
    ; function in the WinMain() main loop return ZERO which exits the
    ; application correctly. If this message is not processed properly
    ; the window disappears but the code is left in memory.
    ; ----------------------------------------------------------------
        invoke PostQuitMessage,NULL
        return 0 
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam
    ; --------------------------------------------------------------------
    ; Default window processing is done by the operating system for any
    ; message that is not processed by the application in the WndProc
    ; procedure. If the application requires other than default processing
    ; it executes the code when the message is trapped and returns ZERO
    ; to exit the WndProc procedure before the default window processing
    ; occurs with the call to DefWindowProc().
    ; --------------------------------------------------------------------

    ret

WndProc endp

; ########################################################################

TopXY proc wDim:DWORD, sDim:DWORD

    ; ----------------------------------------------------
    ; This procedure calculates the top X & Y co-ordinates
    ; for the CreateWindowEx call in the WinMain procedure
    ; ----------------------------------------------------

    shr sDim, 1      ; divide screen dimension by 2
    shr wDim, 1      ; divide window dimension by 2
    mov eax, wDim    ; copy window dimension into eax
    sub sDim, eax    ; sub half win dimension from half screen dimension

    return sDim

TopXY endp

; ########################################################################

GetSpriteFromMousePos proc
    mov eax, 1

    ; x check
    mov ebx, mousepos.x
    .if ebx >= 250
        inc eax
    .endif

    ; y check
    mov ebx, mousepos.y
    .if ebx > 250
        add eax, 2
    .endif
    ret

GetSpriteFromMousePos endp

; ########################################################################

RestartGame proc
    mov currentIndex, 0 ; reinicia a posição no vetor de cores

    mov ebx, 0 ; ebx contém a posição atual de randomização

    .while ebx < 256 ; randomiza cada um dos números
        invoke Random, 3 ; coloca em eax um valor aleatório de 0 a 3
        inc eax ; eax contém agora um valor aleatório de 1 a 4
        
        mov colors[ebx], eax

        inc ebx
    .endw

    invoke ShowColors

    ret
RestartGame endp

; ########################################################################

ShowColors proc
    inc currentIndex
    mov ecx, 0 ; indice atual

    mov showingColors, 1
    mov acceptClick, 0

    ;.while ecx < currentIndex
    ;    mov ebx, colors[ecx]
    ;    mov currentSprite, ebx

    ;    invoke InvalidateRect,hWnd,NULL,TRUE
    ;    invoke Sleep, PC_DELAY_TIME

    ;    inc ecx
    ;.endw


    ret
ShowColors endp

; ########################################################################

Random proc range:DWORD   
    rdtsc
    adc eax, edx
    adc eax, prng_x
    mul prng_a
    adc eax, edx
    mov prng_x, eax
    mul range
    mov eax, edx
    ret
Random endp

; ########################################################################

ThreadProc proc USES ecx PARAM:dword

    .if showingColors != 0 ; se estiver mostrando o desafio
        invoke WaitForSingleObject, hEventStart, 500
        .if eax == WAIT_TIMEOUT
            ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
            .if ecx < currentIndex
                mov ebx, colors[ecx]
                mov currentSprite, ebx

                inc ecx
            .ELSE
                mov showingColors, 0
                mov acceptClick, 1
                mov currentSprite, 0
            .endif
        .endif
    ;.ELSE

    .endif

    invoke  SendMessage, hWnd, WM_FINISH, NULL, NULL

    jmp ThreadProc
    ret
ThreadProc endp

; ########################################################################

end start
