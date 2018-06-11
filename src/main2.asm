; #########################################################################
;
;                   "Abandon all hope, all ye who enter"
;
; #########################################################################

;           Assembler specific instructions for 32 bit ASM code

      .586                   ; minimum processor needed for 32 bit
      .model flat, stdcall   ; FLAT memory model & STDCALL calling
      option casemap :none   ; set code to case sensitive

; #########################################################################

      include \masm32\include\windows.inc

      include \masm32\include\user32.inc
      include \masm32\include\kernel32.inc

      include \MASM32\INCLUDE\gdi32.inc
      
      
      includelib \masm32\lib\user32.lib
      includelib \masm32\lib\kernel32.lib

      includelib \MASM32\LIB\gdi32.lib
      
      
; #########################################################################

      szText MACRO Name, Text:VARARG
        LOCAL lbl
          jmp lbl
            Name db Text,0
          lbl:
        ENDM

      m2m MACRO M1, M2
        push M2
        pop  M1
      ENDM

      return MACRO arg
        mov eax, arg
        ret
      ENDM

; #########################################################################

        WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
        WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
        TopXY PROTO   :DWORD,:DWORD
        GetSpriteFromMousePos PROTO
        RestartGame PROTO
        ShowColors PROTO
        Random PROTO range:DWORD  

; #########################################################################

    .const    
        WM_FINISH     equ WM_USER+100h

    .data
        ; TODO: Tirar daqui
        buffer        db 256 dup(0)

        ; aleatorização de valores
        prng_x        dd 0
        prng_a        dd 180574328

        szDisplayName db "Genius",0
        szLoseMsg     db "Vc perdeu, tente novamente",0
        CommandLine   dd 0
        hWnd          dd 0
        hInstance     dd 0

        colors dd 256 dup(0) ; cores do jogo
        currentIndex dd 0 ; indice no vetor de cores
        drawingIndex dd 0

        acceptClick db 1     ; se é para aceitar um click
        clickHandled db 1
        
        currentSprite dd 0
        clickedSprite dd 0

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

    .code

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

    .if uMsg == WM_LBUTTONDOWN
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
            mov clickedSprite, eax
            mov clickHandled, 0

            invoke InvalidateRect,hWnd,NULL,TRUE
        .endif

    .elseif uMsg == WM_LBUTTONUP
        invoke Sleep, MOUSE_DELAY_TIME
        mov currentSprite, 0
        invoke InvalidateRect,hWnd,NULL,TRUE

    .elseif uMsg == WM_FINISH
        invoke InvalidateRect, hWnd, NULL, TRUE

    .elseif uMsg == WM_PAINT

        invoke BeginPaint,hWin,ADDR Ps
        mov    hdc, eax

        invoke CreateCompatibleDC, hdc
        
        mov hTmpImgDC, eax ; ponteiro para o handle da imagem em eax
        invoke SelectObject, hTmpImgDC, colors_spriteset ; move uma sprite para o handle
        
        ; escolhe a coordenada x da sprite
        mov ebx, currentSprite
        ;add ebx, 48
        ;mov szDisplayName[0], bl
        ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
        ;mov ebx, currentSprite
        imul ebx, 500
        

        invoke BitBlt, hdc, 0, 0, SPRITE_WIDTH, SPRITE_HEIGHT, hTmpImgDC, ebx, 0, MERGECOPY
        invoke DeleteDC, hTmpImgDC

        invoke EndPaint,hWin,ADDR Ps
        return  0


    .elseif uMsg == WM_CREATE

        ; carrega as sprites
        invoke LoadBitmap, hInstance, SPRITESHEET_RESOURCE_ID
        mov colors_spriteset, eax
    
        
        ;===================================
        ; Aleatorizar o vetor de cores
        ;===================================
        invoke RestartGame
     
        ; Inicializa a thread
        invoke CreateEvent, NULL, FALSE, FALSE, NULL
        mov    hEventStart, eax
        mov    eax, OFFSET ThreadProc
        invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR ThreadID

    .elseif uMsg == WM_CLOSE

    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage,NULL
        return 0 
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam
    ret

WndProc endp

; ########################################################################

TopXY proc wDim:DWORD, sDim:DWORD

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
    mov currentIndex, 1 ; reinicia a posição no vetor de cores
    mov drawingIndex, 0
    mov acceptClick, 0

    mov ebx, 0 ; ebx contém a posição atual de randomização

    .while ebx < 256 ; randomiza cada um dos números
        invoke Random, 4 ; coloca em eax um valor aleatório de 0 a 3
        inc eax ; eax contém agora um valor aleatório de 1 a 4
        
        mov colors[ebx], eax

        inc ebx
    .endw
    ret
RestartGame endp

; ########################################################################

ShowColors proc
    inc currentIndex
    mov ecx, 0 ; indice atual

    .while ecx < currentIndex
        mov ebx, colors[ecx]
        mov currentSprite, ebx

        invoke InvalidateRect,hWnd,NULL,TRUE
        invoke Sleep, PC_DELAY_TIME

        inc ecx
    .endw

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

ThreadProc proc USES edx param:DWORD
    .if acceptClick == 0
        invoke WaitForSingleObject, hEventStart, 200
        .if eax == WAIT_TIMEOUT
            ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
            mov ecx, drawingIndex
            .if ecx < currentIndex
                mov edx, colors[ecx]
                mov currentSprite, edx
                ;add edx, 48
                ;mov szDisplayName[0], dl
                ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
                ;invoke InvalidateRect, hWnd, NULL, TRUE
                invoke SendMessage, hWnd, WM_FINISH, NULL, NULL
                inc drawingIndex
            .ELSE
            ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
                mov drawingIndex, 0
                inc currentIndex
                mov currentSprite, 0
                mov acceptClick, 1
                ;invoke InvalidateRect, hWnd, NULL, TRUE
                invoke SendMessage, hWnd, WM_FINISH, NULL, NULL
            ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
            .endif
        .endif
    .ELSE
        invoke WaitForSingleObject, hEventStart, 100
        .if eax == WAIT_TIMEOUT
            .if clickHandled == 0
                mov edx, currentIndex
                dec edx
                .if drawingIndex < edx
                    mov ecx, colors[edx]
                    .if clickedSprite != ecx
                        add ecx, 48
                        mov szDisplayName[0], 48
                        ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
                        invoke MessageBox, hWnd, ADDR szLoseMsg, ADDR szDisplayName, MB_OK
                        invoke ExitProcess, 0
                    .ELSE
                        inc drawingIndex
                        mov clickHandled, 1
                    .endif
                .endif
            .endif
            ;invoke MessageBox,hWnd,NULL,ADDR szDisplayName,MB_OK
        .endif
    .endif
    
    ;invoke SendMessage, hWnd, WM_FINISH, NULL, NULL

    jmp ThreadProc
    ret
ThreadProc endp

; ########################################################################

end start
