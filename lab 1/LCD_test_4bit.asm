; LCD_test_4bit.asm: Initializes and uses an LCD in 4-bit mode
; using the most common procedure found on the internet.
$NOLIST
$MODLP51RC2
$LIST

org 0000H
    ljmp myprogram

; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns

;---------------------------------;
; Wait 40 microseconds            ;
;---------------------------------;
Wait40uSec:
    push AR0
    mov R0, #177
L0:
    nop
    nop
    djnz R0, L0 ; 1+1+3 cycles->5*45.21123ns*177=40us
    pop AR0
    ret

;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;
WaitmilliSec:
    push AR0
    push AR1
L3: mov R1, #45
L2: mov R0, #166
L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L2 ; 22.51519us*45=1.013ms
    djnz R2, L3 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret 
    

Shortwait:
    push AR0
    push AR1
L9: mov R1, #45/2
L8: mov R0, #166/2
L7: djnz R0, L7 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L8 ; 22.51519us*45=1.013ms
    djnz R2, L9 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret 




;---------------------------------;
; Long Wait        ;
;---------------------------------;
long_wait:   
    push AR0
    push AR1
	L6: mov R1, #70
	L5: mov R0, #250
	L4: djnz R0, L4 
    djnz R1, L5
    djnz R2, L6 
    pop AR1
    pop AR0
    ret
 
 
;---------------------------------;
; Shift whole display right       ;
;---------------------------------;
 
 MoveRight:
  	mov a,#0b0000011100
	lcall WriteCommand 
	lcall WaitmilliSec
	ret


;---------------------------------;
; Shift whole display left        ;
;---------------------------------;

 MoveLeft:
 	mov a,#0b0000011000
	lcall WriteCommand 
	lcall WaitmilliSec
	ret

LR_loop:
	;move to right;
	
	lcall MoveRight
	lcall MoveRight
	lcall MoveRight
	lcall MoveRight


	;move to left;
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	lcall MoveLeft
	ret
	
	
flash_display:
	mov a, #0b0000001000
	lcall WriteCommand
	lcall WaitmilliSec
	
	mov a, #0b0000001100
	lcall WriteCommand
	lcall WaitmilliSec
	
	ret
	
;---------------------------------;
; Toggles the LCD's 'E' pin       ;
;---------------------------------;
LCD_pulse:
    setb LCD_E
    lcall Wait40uSec
    clr LCD_E
    ret

;---------------------------------;
; Writes data to LCD              ;
;---------------------------------;
WriteData:
    setb LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes command to LCD           ;
;---------------------------------;
WriteCommand:
    clr LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes acc to LCD in 4-bit mode ;
;---------------------------------;
LCD_byte:
    ; Write high 4 bits first
    mov c, ACC.7
    mov LCD_D7, c
    mov c, ACC.6
    mov LCD_D6, c
    mov c, ACC.5
    mov LCD_D5, c
    mov c, ACC.4
    mov LCD_D4, c
    lcall LCD_pulse

    ; Write low 4 bits next
    mov c, ACC.3
    mov LCD_D7, c
    mov c, ACC.2
    mov LCD_D6, c
    mov c, ACC.1
    mov LCD_D5, c
    mov c, ACC.0
    mov LCD_D4, c
    lcall LCD_pulse
    ret

;---------------------------------;
; Configure LCD in 4-bit mode     ;
;---------------------------------;
LCD_4BIT:
    clr LCD_E   ; Resting state of LCD's enable is zero
    ; clr LCD_RW  ; Not used, pin tied to GND

    ; After power on, wait for the LCD start up time before initializing
    ; NOTE: the preprogrammed power-on delay of 16 ms on the AT89LP51RC2
    ; seems to be enough.  That is why these two lines are commented out.
    ; Also, commenting these two lines improves simulation time in Multisim.
    ; mov R2, #40
    ; lcall WaitmilliSec

    ; First make sure the LCD is in 8-bit mode and then change to 4-bit mode
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x32 ; change to 4-bit mode
    lcall WriteCommand

    ; Configure the LCD
    mov a, #0x28
    lcall WriteCommand
    mov a, #0x0c
    lcall WriteCommand
    mov a, #0x01 ;  Clear screen command (takes some time)
    lcall WriteCommand
    

    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    mov R2, #2
    lcall WaitmilliSec
    ret

;---------------------------------;
; Main loop.  Initialize stack,   ;
; ports, LCD, and displays        ;
; letters on the LCD              ;
;---------------------------------;
myprogram:
    mov SP, #7FH
    lcall LCD_4BIT

 	mov a, #0x80 ; Move cursor to line 1 column 1
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData
    
 	mov a, #0x81 ; Move cursor to line 1 column 1
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData
    
	mov a, #0x82 ; Move cursor to line 1 column 1
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData
    
	mov a, #0x83 ; Move cursor to line 1 column 1
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData
    
    mov a, #0x84 ; Move cursor to line 1 column 1
    mov a,#0b0000001110
	lcall WriteCommand
	lcall long_wait
    mov a, #'R'
    lcall WriteData
 
    mov a, #0x85 ; Move cursor to line 1 column 2
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'U'
    lcall WriteData
   	
    mov a, #0x86 ; Move cursor to line 1 column 3
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'T'
    lcall WriteData
    
    mov a, #0x87 ; Move cursor to line 1 column 4
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'H'
    lcall WriteData    
    
       
    mov a, #0x88 ; Move cursor to line 1 column 6
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #' '
    lcall WriteData
    
    
    mov a, #0x89 ; Move cursor to line 1 column 6
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
	mov a, #'T'
    lcall WriteData
    
    mov a, #0x8A ; Move cursor to line 1 column 7
    mov a,#0b0000001110
	lcall WriteCommand
	lcall long_wait
    mov a, #'A'
    lcall WriteData
    
    
    mov a, #0x8B ; Move cursor to line 1 column 8
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'U'
    lcall WriteData
    
 	 mov a, #0xC0 ; Move cursor to line 2 column 1
    lcall WriteCommand
    mov a,#0b0000001110
    lcall WriteCommand
	lcall WaitmilliSec
    mov a, #' '
    lcall WriteData  
    
 	mov a, #0xC1 ; Move cursor to line 2 
    lcall WriteCommand
    mov a,#0b0000001110
    lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData

    mov a, #0xC2 ; Move cursor to line 2 column 1
    lcall WriteCommand
    mov a,#0b0000001110
    lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData
    
    mov a, #0xC3 ; Move cursor to line 2 column 2
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData
    
    mov a, #0xC4 ; Move cursor to line 2 column 3
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'3'
    lcall WriteData
    
    mov a, #0xC5 ; Move cursor to line 2 column 4
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'7'
    lcall WriteData
    
    mov a, #0xC6 ; Move cursor to line 2 column 5
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'1'
    lcall WriteData
    
    mov a, #0xC5 ; Move cursor to line 2 column 6
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec 
    mov a, #'0'
    lcall WriteData
    
    mov a, #0xC7 ; Move cursor to line 2 column 7
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'0'
    lcall WriteData
    
    mov a, #0xC8 ; Move cursor to line 2 column 8
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'5'
    lcall WriteData
	
    mov a, #0xC9 ; Move cursor to line 2 column 8
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'1'
    lcall WriteData
	
    mov a, #0xCA ; Move cursor to line 2 column 8
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #'8'
    lcall WriteData
	
	mov a, #0xCB
	mov a,#0b0000001111
	lcall WriteCommand


 	;blink 7 times then unblink;
	lcall long_wait
	lcall long_wait
	lcall long_wait

	mov a,#0b0000001100
	lcall WriteCommand
	
	;use left-right scrolling
	lcall LR_loop
	
	;reset;
	lcall LCD_4BIT
	
	;new symbol;
	
	mov a, #0x80 ; Move cursor to line 1 column 1
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a, #0b01111110 ;symbol 1;
    lcall WriteData
 
    mov a, #0x81 ; Move cursor to line 1 column 2
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
    mov a,#0b01111110 ;symbol 2;
    lcall WriteData
    
    mov a, #0x82 ; Move cursor to line 1 column 2
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a,#' ' ;symbol 2;
    lcall WriteData
    
    mov a, #0x83 ; Move cursor to line 1 column 2
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a,#' ' ;symbol 2;
    lcall WriteData
    
    mov a, #0x84 ; Move cursor to line 1 column 2
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
    mov a,#' ';symbol 2;
    lcall WriteData
 
   	
    mov a, #0x85 ; Move cursor to line 1 column 3
	lcall WriteCommand
	lcall long_wait
    mov a,#'R'
    lcall WriteData
    lcall Wait40uSec
       
    mov a, #0x87 ; Move cursor to line 1 column 6
	lcall WriteCommand
	lcall long_wait
    mov a, #'$'
    lcall WriteData
    lcall Wait40uSec

	mov a, #0x86 ; Move cursor to line 1 column 4
	lcall WriteCommand
	lcall long_wait
    mov a, #'E'
    lcall WriteData  
    lcall Wait40uSec  

  	mov a, #0x89 ; Move cursor to line 1 column 7
	lcall WriteCommand
	lcall long_wait
    mov a, #'T'
    lcall WriteData
    lcall Wait40uSec

    mov a, #0x88 ; Move cursor to line 1 column 7
	lcall WriteCommand
	lcall long_wait
    mov a, #'E'
    lcall WriteData
    lcall Wait40uSec
    
    mov a, #0x8A ; Move cursor to line 1 column 7
	lcall WriteCommand
	lcall Shortwait
    mov a, #' '
    lcall WriteData

    mov a, #0x8B ; Move cursor to line 1 column 7
	lcall WriteCommand
	lcall Shortwait
 	mov a, #' '
    lcall WriteData
 
 	mov a, #0x8C ; Move cursor to line 1 column 7
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
 	mov a, #' '
    lcall WriteData
    
    mov a, #0x8D ; Move cursor to line 1 column 7
    mov a,#0b0000001110
	lcall WriteCommand
	lcall Shortwait
 	mov a, #' '
    lcall WriteData

 	mov a, #0x8E ; Move cursor to line 1 column 7
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
 	mov a, #0b01111111
    lcall WriteData
    
 	mov a, #0x8F ; Move cursor to line 1 column 7
    mov a,#0b0000001110
	lcall WriteCommand
	lcall WaitmilliSec
 	mov a, #0b01111111
    lcall WriteData
    
    ;Japanese;
    lcall WaitmilliSec	
    
    mov a,#0xC5
	lcall WriteCommand
	lcall WaitmilliSec
 	mov a,#'*'
    lcall WriteData
    
    mov a,#0xC6
	lcall WriteCommand
	lcall WaitmilliSec
 	mov a,#0b11011000
    lcall WriteData
	
	
    mov a,#0xC7
	lcall WriteCommand
	lcall WaitmilliSec
 	mov a,#0b10111110
    lcall WriteData
	lcall WaitmilliSec

    mov a,#0xC8
   
	lcall WriteCommand
	lcall WaitmilliSec
 	mov a,#0b11000010
    lcall WriteData
	lcall WaitmilliSec

    mov a,#0xC9
  
	lcall WriteCommand
	lcall WaitmilliSec
 	mov a,#0b11000100
    lcall WriteData
	lcall WaitmilliSec

  
	
	
	;blank screen cicle;

	
	mov a, #0xCF
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	
	mov a, #0xCE
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait	
		
	mov a, #0xCD
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xCC
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xCB
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xCA
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xC9
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0xC8
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xC7
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xC6
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xC5
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xC4
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
    
   	mov a, #0xC3
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xC2
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0xC1
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0xC0
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x80
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x81
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0x82
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0x83
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0x84
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x85
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0x86
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0x87
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x88
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	mov a, #0x89
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x8A
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x8B
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x8C
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x8D
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x8E
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait
	
	mov a, #0x8F
	lcall WriteCommand
	mov a,#0b11111111
	lcall WriteData
	lcall Shortwait

	
    ;flashing;
	lcall flash_display
	lcall flash_display
	
	mov a, #0b0000001000
	lcall WriteCommand


	
forever:
    sjmp forever
END
