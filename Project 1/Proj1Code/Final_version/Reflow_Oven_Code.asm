
$NOLIST
$MODLP51RC2
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz

;Timer 2 for checking the amount of time that has passed
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

SHIFT_PB equ P0.6 ;originally 2.4
;TEMP_SOAK_PB equ P4.5
TIME_SOAK_PB equ P0.3
TEMP_REFL_PB equ P0.2
TIME_REFL_PB equ P0.0
TEMP_SOAK_PB equ P0.5	
PWM_OUTPUT   equ P1.4 ;dupliacted pin for p3.4
START        equ P0.7
DEBUG 	     equ P0.1


TIMER1_RATE    EQU 22050     ; 22050Hz is the sampling rate of the wav file we are playing
TIMER1_RELOAD  EQU 0x10000-(CLK/TIMER1_RATE)
BAUDRATE       EQU 115200
BRG_VAL        EQU (0x100-(CLK/(16*BAUDRATE)))

SPEAKER   EQU P2.6

;pins used fo rSPI
FLASH_CE  EQU  P2.5
MY_MOSI   EQU  P2.4 
MY_MISO   EQU  P1.6
MY_SCLK   EQU  P2.7


; Commands supported by the SPI flash memory according to the datasheet
WRITE_ENABLE     EQU 0x06  ; Address:0 Dummy:0 Num:0
WRITE_DISABLE    EQU 0x04  ; Address:0 Dummy:0 Num:0
READ_STATUS      EQU 0x05  ; Address:0 Dummy:0 Num:1 to infinite
READ_BYTES       EQU 0x03  ; Address:3 Dummy:0 Num:1 to infinite
READ_SILICON_ID  EQU 0xab  ; Address:0 Dummy:3 Num:1 to infinite
FAST_READ        EQU 0x0b  ; Address:3 Dummy:1 Num:1 to infinite
WRITE_STATUS     EQU 0x01  ; Address:0 Dummy:0 Num:1
WRITE_BYTES      EQU 0x02  ; Address:3 Dummy:0 Num:1 to 256
ERASE_ALL        EQU 0xc7  ; Address:0 Dummy:0 Num:0
ERASE_BLOCK      EQU 0xd8  ; Address:3 Dummy:0 Num:0
READ_DEVICE_ID   EQU 0x9f  ; Address:0 Dummy:2 Num:1 to infinite

;SPI pins used for MCP3008 ADC
CE_ADC            EQU  P2.0
MY_MOSI_MCP3008   EQU  P2.1 
MY_MISO_MCP3008   EQU  P1.3
MY_SCLK_MCP3008   EQU  P1.2 


LCD_RS equ P3.2
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7



org 0x0000
	ljmp main
	
; Timer/Counter 0 overflow interrupt vector
org 0x000B
	reti ;ljmp Timer0_ISR
	
org 0x001B ; Timer/Counter 1 overflow interrupt vector. Used in this code to replay the wave file.
	ljmp Timer1_ISR
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR	

;variables
dseg at 30H
w:   ds 3 ; 24-bit play counter.  Decremented in Timer 1 ISR.
time_soak: ds 1
time_refl: ds 1
temp_soak: ds 1
temp_refl: ds 1
time_soak_count: ds 1
time_refl_count: ds 1
;counter: ds 1
temp: ds 4
pwm: ds 2
five_second_counter: ds 1
seconds: ds 1
Count1ms: ds 2	
x:   ds 4
y:   ds 4
bcd: ds 5
result: ds 2



; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
state0flag: dbit 1
state1flag: dbit 1
state2flag: dbit 1
state3flag: dbit 1
state4flag: dbit 1
state5flag: dbit 1
five_second_flag: dbit 1
done_playing_flag: dbit 1
mf: dbit 1 
one_second_flag: dbit 1

$NOLIST
$include(math32.inc)
$include(LCD_4bit.inc)
$LIST

cseg

;-------------------------------------;
; ISR for Timer 1.  Used to playback  ;
; the WAV file stored in the SPI      ;
; flash memory.                       ;
;-------------------------------------;
Timer1_ISR:
	; The registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Check if the play counter is zero.  If so, stop playing sound.
	mov a, w+0
	orl a, w+1
	orl a, w+2
	jz stop_playing
	
	; Decrement play counter 'w'.  In this implementation 'w' is a 24-bit counter.
	mov a, #0xff
	dec w+0
	cjne a, w+0, keep_playing
	dec w+1
	cjne a, w+1, keep_playing
	dec w+2
	
keep_playing:
	setb SPEAKER
	lcall Send_SPI ; Read the next byte from the SPI Flash...
	;mov P0, a ; WARNING: Remove this if not using an external DAC to use the pins of P0 as GPIO
	;add a, #0x80
	mov DADH, a ; Output to DAC. DAC output is pin P2.3
	orl DADC, #0b_0100_0000 ; Start DAC by setting GO/BSY=1
	sjmp Timer1_ISR_Done

stop_playing:
	clr TR1 ; Stop timer 1
	setb FLASH_CE  ; Disable SPI Flash
	clr SPEAKER ; Turn off speaker.  Removes hissing noise when not playing sound.
	mov DADH, #0x80 ; middle of range
	orl DADC, #0b_0100_0000 ; Start DAC by setting GO/BSY=1

Timer1_ISR_Done:	
	pop psw
	pop acc
	reti

;---------------------------------;
; Sends AND receives a byte via   ;
; SPI.                            ;
;---------------------------------;
Send_SPI:
    SPIBIT MAC
        ; Send/Receive bit %0
        rlc a
        mov MY_MOSI, c
        setb MY_SCLK
        mov c, MY_MISO
        clr MY_SCLK
        mov acc.0, c
    ENDMAC

    SPIBIT(7)
    SPIBIT(6)
    SPIBIT(5)
    SPIBIT(4)
    SPIBIT(3)
    SPIBIT(2)
    SPIBIT(1)
    SPIBIT(0)

 ret


;---------------------------------;
; SPI flash 'write enable'        ;
; instruction.                    ;
;---------------------------------;
Enable_Write:
	clr FLASH_CE
	mov a, #WRITE_ENABLE
	lcall Send_SPI
	setb FLASH_CE
	ret


;---------------------------------;
; This function checks the 'write ;
; in progress' bit of the SPI     ;
; flash memory.                   ;
;---------------------------------;
Check_WIP:
	clr FLASH_CE
	mov a, #READ_STATUS
	lcall Send_SPI
	mov a, #0x55
	lcall Send_SPI
	setb FLASH_CE
	jb acc.0, Check_WIP ;  Check the Write in Progress bit
	ret



; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret
    

;---------------------------------;
; Receive a byte from serial port ;
;---------------------------------;
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret


INIT_SPI_FLASH:
	setb MY_MISO
	clr MY_SCLK
	
INIT_SPI: 
    setb MY_MISO_MCP3008    ; Make MISO an input pin 
    clr MY_SCLK_MCP3008     ; For mode (0,0) SCLK is zero 
    ret 
DO_SPI_G: 
    push acc 
    mov R1, #0      ; Received byte stored in R1 
    mov R2, #8      ; Loop counter (8-bits) 
DO_SPI_G_LOOP: 
    mov a, R0       ; Byte to write is in R0 
    rlc a           ; Carry flag has bit to write 
    mov R0, a 
    mov MY_MOSI_MCP3008, c 
    setb MY_SCLK_MCP3008    ; Transmit 
    mov c, MY_MISO_MCP3008  ; Read received bit 
    mov a, R1       ; Save received bit in R1 
    rlc a 
    mov R1, a 
    clr MY_SCLK_MCP3008 
    djnz R2, DO_SPI_G_LOOP 
    pop acc 
    ret 



; Configure the serial port and baud rate
InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can proceed with the configuration
	orl	PCON,#0x80
	mov	SCON,#0x52
	mov	BDRCON,#0x00
	mov	BRL,#BRG_VAL
	mov	BDRCON,#0x1E ; BDRCON=BRR|TBCK|RBCK|SPD;
ret

Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret


;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	;cpl P1.0 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter (16 bits can store up to 35 535, we only need up to 1000 so we're good)
	inc Count1ms+0    ; Increment the low 8-bits first (b/c low 8 bits can only store up to 255)
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	clr c 
	mov a, pwm+0
	subb a, Count1ms+0
	mov a, pwm+1
	subb a, Count1ms+1
	; if count1ms > pwm_ratio, carry is set
	;cpl c
	mov PWM_OUTPUT, c


	; Check if one second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done
	
	; 1000 milliseconds have passed.  Set a flag so the main program knows
	setb one_second_flag ; Let the main program know one second had passed

	clr a
	mov Count1ms+0, a ; clearing these bc we have determined that we've reached 1000
	mov Count1ms+1, a ;clearing

	;lcall TEMP_JUNCTION
	inc seconds
	mov a, five_second_counter
	cjne a, #5, State_Logic ;i dont think we need to compare to flag? just gotta compare to counter
	; otherwise if we ARE at 5 seconds continue on
	setb five_second_flag ;NEED TO CLR THIS IN THE CODE WHERE YOU GUYS ACTUALLY DO LOGIC W IT
	mov five_second_counter, #0x00
	sjmp State_Logic_Skip_Inc
	;carry on


	; state 2 is for preheat/soak
	State_Logic: inc five_second_counter
	State_Logic_Skip_Inc: jnb state2flag, state4Count ;jump to this line if we don't want to increment 5 sec counter
	state2Count:
	mov a, seconds
	cjne a, time_soak, Timer2_ISR_done ;CHANGE THIS NUMBER
	clr state2flag
	setb state3flag ;triggering flag so we know to change states
	sjmp Timer2_ISR_done


	; state 4 is for reflow
	state4Count: jnb state4flag, Timer2_ISR_done ;we don't want to increment this if we're not in state 4 either
	mov a, seconds 
	cjne a, time_refl, Timer2_ISR_done ;CHANGE THIS NUMBER
	clr state4flag
	setb state5flag

Timer2_ISR_done:
	pop psw
	pop acc
	reti
	

SendToLCD:
mov b, #100
div ab
orl a, #0x30 ; Convert hundreds to ASCII
lcall ?WriteData ; Send to LCD
mov a, b    ; Remainder is in register b
mov b, #10
div ab
orl a, #0x30 ; Convert tens to ASCII
lcall ?WriteData; Send to LCD
mov a, b
orl a, #0x30 ; Convert units to ASCII
lcall ?WriteData; Send to LCD
ret

Change_8bit_Variable MAC
jb %0, %2
Wait_Milli_Seconds(#50) ; de-bounce
jb %0, %2
jnb %0, $
jb SHIFT_PB, skip%Mb
dec %1
sjmp skip%Ma
skip%Mb:
inc %1
skip%Ma:
ENDMAC

loadbyte mac
mov a, %0
movx @dptr, a
inc dptr
endmac

Save_Configuration:
	push IE ; Save the current state of bit EA in the stack
	clr EA ; Disable interrupts
	mov FCON, #0x08 ; Page Buffer Mapping Enabled (FPS = 1)
	mov dptr, #0x7f80 ; Last page of flash memory
	; Save variables
	loadbyte(temp_soak) ; @0x7f80
	loadbyte(time_soak) ; @0x7f81
	loadbyte(temp_refl) ; @0x7f82
	loadbyte(time_refl) ; @0x7f83
	loadbyte(#0x55) ; First key value @0x7f84
	loadbyte(#0xAA) ; Second key value @0x7f85
	mov FCON, #0x00 ; Page Buffer Mapping Disabled (FPS = 0)
	orl EECON, #0b01000000 ; Enable auto-erase on next write sequence
	mov FCON, #0x50 ; Write trigger first byte
	mov FCON, #0xA0 ; Write trigger second byte
	; CPU idles until writing of flash completes.
	mov FCON, #0x00 ; Page Buffer Mapping Disabled (FPS = 0)
	anl EECON, #0b10111111 ; Disable auto-erase
	pop IE ; Restore the state of bit EA from the stack
	ret


Initial_Message:  db 'TS:   TR:    T   ', 0
Line:             db 'ts:   tR:        ', 0

getbyte mac
clr a
movc a, @a+dptr
mov %0, a
inc dptr
Endmac
Load_Configuration:
	mov dptr, #0x7f84 ; First key value location.
	getbyte(R0) ; 0x7f84 should contain 0x55
	cjne R0, #0x55, Load_Defaults
	getbyte(R0) ; 0x7f85 should contain 0xAA
	cjne R0, #0xAA, Load_Defaults
	; Keys are good.  Get stored values.
	mov dptr, #0x7f80
	getbyte(temp_soak) ; 0x7f80
	getbyte(time_soak) ; 0x7f81
	getbyte(temp_refl) ; 0x7f82
	getbyte(time_refl) ; 0x7f83
	ret

Load_Defaults:
mov temp_soak, #150
mov time_soak, #45
mov temp_refl, #225
mov time_refl, #30
ret



Send_BCD mac
	 push ar0
	 mov r0,%0
	 lcall ?Send_BCD
	 pop ar0
	endmac

?Send_BCD:
	push acc
	;send most significant digit
	mov a, r0
	swap a 
	anl a, #0fh
	orl a, #30h
	lcall putchar
	;send least sigfig
	mov a, r0
	anl a ,#0fh
	orl a, #30h
	lcall putchar
	
	pop acc
	ret

  Read_ADC_Channel MAC
    mov b, #%0
    lcall _Read_ADC_Channel
    ENDMAC

 _READ_ADC_Channel:
  clr CE_ADC
  mov R0, #00000001B ; Start bit:1
  lcall DO_SPI_G
  mov a, b
  swap a
  anl a, #0F0H
  setb acc.7 ; Single mode (bit 7).
  mov R0, a
  lcall DO_SPI_G
  mov a, R1 ; R1 contains bits 8 and 9
  anl a, #00000011B  ; We need only the two least significant bits
  mov R7, a ; Save result high.
  mov R0, #55H ; It doesn't matter what we transmit...
  lcall DO_SPI_G
  mov a,R1
  mov R6,a
  setb CE_ADC
  ret
	
PLAY_SOUND MAC
	; PLAY_SOUND(%0, %1, %2, %3, %4, %5) inputs will be hex numbers (diff segments of address)
	; input has to automatically be in hex format with the #
	clr TR1 ; Stop Timer 1 ISR from playing previous request
	; I think we'll want to remove the above instruction and include it right AFTER this has been called
	setb FLASH_CE
	clr SPEAKER

	clr FLASH_CE
	mov a, #READ_BYTES
	lcall Send_SPI

	mov a, %0
	
	lcall Send_SPI 
	
	mov a, %1
	lcall Send_SPI

	mov a, %2
	lcall Send_SPI
	mov a, #0x00
	lcall Send_SPI

	mov w+2, %3
	mov w+1, %4
	mov w+0, %5
	
	setb SPEAKER
	setb TR1
	
ENDMAC
	
	
TEMP_JUNCTION:

	Read_ADC_Channel(0)
    mov x+0, R6
    mov x+1, R7
    mov x+2, #0
    mov x+3, #0

    load_y(964)
    lcall mul32
    load_y(1000)
    lcall div32
    load_y(22)
    lcall add32
    ;lcall hex2bcd

	;mov temp+4, bcd+4
	;mov temp+3, bcd+3
    ;mov temp+2, bcd+2
    ;mov temp+1, bcd+1
    ;mov temp+0, bcd+
    
    mov temp+0, x+0
    mov temp+1, x+1
    mov temp+2, x+2
    mov temp+3, x+3
    
    lcall hex2bcd
    jb one_second_flag, TEMP_JUNCTION2
    ret
    
    
TEMP_JUNCTION2:
   	;Send_BCD(bcd+4)
	;Send_BCD(bcd+3)
    Send_BCD(bcd+2)
    Send_BCD(bcd+1)
    Send_BCD(bcd+0)
    
    mov a, #'\r'
    lcall putchar

    mov a, #'\n'
    lcall putchar
	clr one_second_flag
 ret
 
	Delay:
		Wait_Milli_Seconds(#250)
		Wait_Milli_Seconds(#250)
		Wait_Milli_Seconds(#250)
		Wait_Milli_Seconds(#250)
		ret

	sound_zero:
	PLAY_SOUND(#0x02, #0x8C, #0xBD,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_one:
	PLAY_SOUND(#0x02, #0xDC, #0xBB,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_two:
	PLAY_SOUND(#0x03, #0x1D, #0xBC, #0x00, #0x3A, #0x98)
	lcall Delay
	ret 

	sound_three:
	PLAY_SOUND(#0x03, #0x4E, #0xB3,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_four:
	PLAY_SOUND(#0x03, #0x99, #0x4B,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_five:
	PLAY_SOUND(#0x03, #0xE3, #0xE3,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 


	sound_six:
	PLAY_SOUND(#0x04, #0x2E, #0x7B,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 


	sound_seven:
	PLAY_SOUND(#0x04, #0x79, #0x13,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_eight:
	PLAY_SOUND(#0x04, #0xC3, #0xAB,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_nine:
	PLAY_SOUND(#0x05, #0x0E, #0x43,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 


	sound_ten:
	PLAY_SOUND(#0x05, #0x58, #0xDB,#0x00, #0x30,#0xFC)
	lcall Delay
	ret 

	sound_eleven:
	PLAY_SOUND(#0x05, #0x8F, #0xD7, #0x00, #0x3A,#0x98)
	lcall Delay
	ret 


	sound_twelve:
	PLAY_SOUND(#0x05, #0xDA, #0x6F,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_thirteen:
	PLAY_SOUND(#0x06, #0x25, #0x07,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 


	sound_fourteen:
	PLAY_SOUND(#0x06, #0x6F, #0x9F,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_fifteen:
	PLAY_SOUND(#0x06, #0xB8, #0x37,#0x00, #0x42,#0x68)
	lcall Delay
	ret 


	sound_sixteen:
	PLAY_SOUND(#0x07, #0x0C, #0x9F,#0x00, #0x4E,#0x20)
	lcall Delay
	ret 

	sound_seventeen:
	PLAY_SOUND(#0x07, #0x6A, #0xBF, #0x00, #0x4E,#0x20)
	lcall Delay
	ret 


	sound_eighteen:
	PLAY_SOUND(#0x07, #0xC8, #0xDF,#0x00, #0x4E,#0x20)
	lcall Delay
	ret 

	sound_nineteen:
	PLAY_SOUND(#0x08, #0x26, #0xFF,#0x00, #0x4E,#0x20)
	lcall Delay
	ret 

	sound_twenty:
	PLAY_SOUND(#0x08, #0x85, #0x1F,#0x00, #0x4E,#0x20)
	lcall Delay
	ret 

	sound_thirty:
	PLAY_SOUND(#0x08, #0xE3, #0x3F,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 
	

	sound_forty:
	PLAY_SOUND(#0x09, #0x1D, #0xD7,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_fifty:
	PLAY_SOUND(#0x09, #0x68, #0x6F,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_sixty:
	PLAY_SOUND(#0x09, #0xB3, #0x07,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_seventy:
	PLAY_SOUND(#0x09, #0xFD, #0x9F,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_eighty:
	PLAY_SOUND(#0x0A, #0x48, #0x37,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_ninety:
	PLAY_SOUND(#0x0A, #0x92, #0xCF,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_100:
	PLAY_SOUND(#0x0A, #0xF0, #0x3F, #0x00,#0x4E, #0x20)
	ret

	sound_200:
	PLAY_SOUND(#0x0B, #0x2E, #0x54,#0x00, #0x4E,#0x20)
	lcall Delay
	ret 
	


	sound_state_zero:
	PLAY_SOUND(#0x00, #0x00, #0x2D,#0x00, #0xD6,#0xD8)
	lcall Delay
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	ret 



	sound_state_one:
	PLAY_SOUND(#0x01, #0x00, #0xFF,#0x00, #0x30,#0xFC)
	lcall Delay
	ret 


	sound_state_two:
	PLAY_SOUND(#0x01, #0x33, #0xDF,#0x00, #0x36,#0xB0)
	lcall Delay
	ret 


	sound_state_three:
	PLAY_SOUND(#0x01, #0x95, #0xD7,#0x00, #0x4E,#0x20)
	lcall Delay
	ret 


	sound_state_four:
	PLAY_SOUND(#0x01, #0xF7, #0xCF,#0x00, #0x3A,#0x98)
	lcall Delay
	ret 

	sound_state_five:
	PLAY_SOUND(#0x02, #0x33, #0x00,#0x00, #0x4E,#0x20)
	lcall Delay
	ret 

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
 
    mov P0M0, #0
    mov P0M1, #0

	; Enable the timer and interrupts
    ;setb ET1  ; Enable timer 1 interrupt
	; setb TR1 ; Timer 1 is only enabled to play stored sound


	;mov counter, #0
	mov seconds, #0
	clr five_second_flag
	clr one_second_flag
	lcall Timer2_Init
	
	;setb EA ; Enable interrupts

	
   	lcall Load_Configuration
   	
   	; enabling SPI communication
   	lcall INIT_SPI_FLASH
   	lcall INIT_SPI
   	lcall InitSerialPort
   	
   	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   	; Configure P2.4, P2.5, P2.7 as open drain outputs (they need 1k pull-ups to 3.3V)
	orl P2M0, #0b_1011_0000
	orl P2M1, #0b_1011_0000
	setb MY_MISO  ; Configured as input
	setb FLASH_CE ; CS=1 for SPI flash memory
	clr MY_SCLK   ; Rest state of SCLK=0
	clr SPEAKER   ; Turn off speaker.
 
; Configure timer 1
	anl TMOD, #0x0F ; Clear the bits of timer 1 in TMOD
	orl TMOD, #0x10 ; Set timer 1 in 16-bit timer mode.  Don't change the bits of timer 0
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	; Set autoreload value
	mov RH1, #high(TIMER1_RELOAD)
	mov RL1, #low(TIMER1_RELOAD)
	
	; Enable the timer and interrupts
	
	setb ET1  ; Enable timer 1 interrupt
	; setb TR1 ; Timer 1 is only enabled to play stored sound
	
	
	; Configure the DAC.  The DAC output we are using is P2.3, but P2.2 is also reserved.
	mov DADI, #0b_1010_0000 ; ACON=1
	mov DADC, #0b_0011_1010 ; Enabled, DAC mode, Left adjusted, CLK/4
	mov DADH, #0x80 ; Middle of scale
	mov DADL, #0
	orl DADC, #0b_0100_0000 ; Start DAC by GO/BSY=1
	check_DAC_init:
	mov a, DADC
	jb acc.6, check_DAC_init ; Wait for DAC to finish
	 
	setb EA ; Enable interrupts
;;;;;;;;;;;;;;;;;;;;;;;;
   	
    lcall LCD_4BIT
	setb state0flag
	clr state1flag
	clr state2flag
	clr state3flag
	clr state4flag
	clr state5flag
	
	setb SHIFT_PB
	

	; set default pwm output to 20 instead of 0
	mov pwm+0, #low(0)
	mov pwm+1, #high(0)

    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    Set_Cursor(2, 1)
    Send_Constant_String(#Line)
    
    ;Display Variables
    Set_Cursor(2, 4)
    mov a, time_soak
    lcall SendToLCD
 	Set_Cursor(1, 4)
 	mov a, temp_soak
    lcall SendToLCD
    Set_Cursor(2, 9)
 	mov a, time_refl
    lcall SendToLCD
    Set_Cursor(1, 9)
 	mov a, temp_refl
    lcall SendToLCD
    mov seconds, #0
    sjmp loop

loop:
	
	Change_8bit_Variable(TEMP_SOAK_PB, temp_soak, loop_a)
	Set_Cursor(1, 4)
	mov a, temp_soak 
	lcall SendToLCD
	lcall Save_Configuration
	sjmp loop_a
		
loop_a:
	Change_8bit_Variable(TIME_SOAK_PB, time_soak, loop_b)
	Set_Cursor(2, 4)
	mov a, time_soak 
	lcall SendToLCD
	lcall Save_Configuration
	sjmp loop_b
	
loop_b:
	Change_8bit_Variable(TEMP_REFL_PB, temp_refl, loop_c)
	Set_Cursor(1, 11)
	mov a, temp_refl
	lcall SendToLCD
	lcall Save_Configuration
	sjmp loop_c
		
loop_c:
	Change_8bit_Variable(TIME_REFL_PB, time_refl, loop_d)
	Set_Cursor(2, 11)
	mov a, time_refl
	lcall SendToLCD
	lcall Save_Configuration
	sjmp loop_d
	
loop_d:
	Change_8bit_Variable(TIME_REFL_PB, time_refl, state0)
	Set_Cursor(2, 14)
	mov a, temp
	lcall SendToLCD
	lcall Save_Configuration
	sjmp state0

state0:
	;**set power to 0%**
	clr state5flag ; just in case,
	setb state0flag
	mov pwm+0, #low(0)
	mov pwm+1, #high(0)
	;Wait_Milli_Seconds(#255)
	
	ljmp state_one
	state0_2: 
    mov seconds, #0
	;mov counter, #0

	lcall TEMP_JUNCTION
	clr DEBUG
	jb START, loop_leap ;START is pushbutton to start reflow
	Wait_Milli_Seconds(#50)	; Debounce delay
	jb START, loop_leap 
	jnb START, state1	
	
loop_leap:
    ljmp loop
state1:
	clr state0flag
	setb state1flag
	ljmp state_one
	;ljmp state_zero ;jumps to second finite state machine
	state1_2: 
    mov pwm+0, #low(1000) ;CHANGE BACK TO 1000
	mov pwm+1, #high(1000)
	Wait_Milli_Seconds(#255)
	setb DEBUG
	clr a
	;mov counter, #0 ;setting seconds to zero
	;setb DEBUG
	lcall TEMP_JUNCTION
	clr c
	mov a, temp
	subb a, temp_soak
	jc state1_x
	mov seconds, #0
	sjmp state2
state1_x:
	mov a, seconds
	xrl a, #60
	jz ABORT_CHECK 
	jnz state1
	
ABORT_CHECK:
	mov a, temp
	subb a, #50
	jc ABORT
	sjmp state1
	
ABORT:
    clr state1flag
	ljmp state0
	
state2:
	clr state1flag
	setb state2flag ;use this to increment counter in Timer ISR
	ljmp state_one
	;mov seconds, #0
	state2_2: 
    mov pwm+0, #low(200)
	mov pwm+1, #high(200)
	Wait_Milli_Seconds(#255)
	lcall TEMP_JUNCTION
	;clr DEBUG
	;jb state3flag, state3
	mov a, seconds
	xrl a, time_soak
	jz state3
	;cjne a, time_soak, state2
	;mov counter, #0
	sjmp state2

state3:
	;setb DEBUG
	clr state2flag
	setb state3flag
	ljmp state_one
	;mov seconds, #0
	state3_2: 
    mov pwm+0, #low(1000)
	mov pwm+1, #high(1000)
	Wait_Milli_Seconds(#255)
	lcall TEMP_JUNCTION
	mov a, temp
	clr c
	subb a, temp_refl
	jc state3
	mov seconds, #0; setting seconds to zero so that when we get to state 4 it starts counting
	sjmp state4

state4:
	;clr DEBUG
	clr state3flag
	setb state4flag
	ljmp state_one
	;mov seconds, #0
	state4_2: 
    mov pwm+0, #low(200)
	mov pwm+1, #high(200)
	Wait_Milli_Seconds(#255)
	lcall TEMP_JUNCTION
	mov a, seconds
	cjne a, time_refl, state4
	sjmp state5

state5:
	;setb DEBUG
	clr state4flag
	setb state5flag
	ljmp state_one
	;mov seconds, #0
	state5_2: 
    mov pwm+0, #low(0)
	mov pwm+1, #high(0)
	Wait_Milli_Seconds(#255)
	lcall TEMP_JUNCTION
	mov seconds, #0; setting seconds to zero
	mov a, temp
	cjne a, #59, state5	
	ljmp loop



FSM2:
	; function
	;Finit staet machine for sound, set a flag for states then produce sound
	;state_zero:
	;jb START, state_zero ;START is pushbutton to start reflow
	;Wait_Milli_Seconds(#50)	; Debounce delay
	;jb START, state_zero 
	;jnb START, state_one	; if buttons is pressed go to state one 
	
state_one: 
	setb done_playing_flag
	; compare temperature, if temp <100 -> state 5 else -> state 2
	jb five_second_flag, state_one_x
	ljmp state_seven
	
state_one_x:
    clr done_playing_flag
	jb state0flag, zero_state_s
	jb state1flag, one_state_s
	jb state2flag, two_state_s
	jb state3flag, three_state_s
	jb state4flag, four_state_s
	jb state5flag, five_state_s
	
	zero_state_s: 
    lcall sound_state_zero
	sjmp after_saying_state
	one_state_s: 
    lcall sound_state_one
	sjmp after_saying_state
	two_state_s: 
    lcall sound_state_two
	sjmp after_saying_state
	three_state_s: 
    lcall sound_state_three
	sjmp after_saying_state
	four_state_s: 
    lcall sound_state_four 
	sjmp after_saying_state
	five_state_s: 
    lcall sound_state_five
	sjmp after_saying_state
	
	
	after_saying_state: 
    setb done_playing_flag
	mov a, temp
	clr c
	subb a, #100
	jc state_five ;smaller than 100 to state 5
	ljmp state_two
	
state_two:
	;temp larger than 100, play 100 or 200
    	clr done_playing_flag
	mov a, temp
	mov b, #100
	div ab 
	cjne a, #2, call_sound_100
	sjmp call_sound_200


	call_sound_200:
	lcall sound_200
	setb done_playing_flag
	;jnb TR1, done_playing
	ljmp state_three
	

	call_sound_100:
	lcall sound_100
	setb done_playing_flag
	ljmp state_three

	
state_three:
	; check if done playing sound
	jnb done_playing_flag, state_three
	ljmp state_five

; no state 4 lolsies

state_five:
	mov a, temp
	mov b, #100
	div ab
	;remainder is b
	mov a, b
	clr c
	subb a, #20
	jc state_six ; <20 -> state 6 
	ljmp state_eight ; >= 20 -> state 8

state_six:
	;check all 0 to 20 and call sound
	;jnb  five_second_flag, no_sound
	;cjne a, #0, sound_zero_fun
	mov a, temp
	mov b, #100
	div ab
	;remainder is b
	mov a, b
	
	xrl a, #0
	ljmp state_seven ;all we have left to say is "zero"
	clr done_playing_flag

	xrl a, #1 
	jz sound_one_fun
	ljmp sound_two_fun_2
	sound_one_fun:
	lcall sound_one
	ljmp state_five_b
	
	sound_two_fun_2:
	xrl a, #2 
	jz sound_two_fun 
	ljmp sound_three_fun_3
	sound_two_fun:
	lcall sound_two
	ljmp state_five_b
	
	sound_three_fun_3:
	xrl a, #3
	jz sound_three_fun
	ljmp sound_four_fun_4
	sound_three_fun:
	lcall sound_three
	ljmp state_five_b
	
	sound_four_fun_4:
	xrl a ,#4
	jz sound_four_fun
	ljmp sound_five_fun_5
	sound_four_fun:
	lcall sound_four
	ljmp state_five_b
	
	sound_five_fun_5:
	xrl a ,#5 
	jz sound_five_fun
	ljmp sound_six_fun_6
	sound_five_fun:
	lcall sound_five
	ljmp state_five_b

	sound_six_fun_6:
	xrl a, #6
	jz sound_six_fun
	ljmp  sound_seven_fun_7
	sound_six_fun:
	lcall sound_six
	ljmp state_five_b
	
	sound_seven_fun_7:
	xrl a, #7
	jz sound_seven_fun
	ljmp sound_eight_fun_8
	sound_seven_fun:
	lcall sound_seven
	ljmp state_five_b
	
	sound_eight_fun_8:
	xrl a, #8
	jz sound_eight_fun
	ljmp sound_nine_fun_9
	sound_eight_fun:
	lcall sound_eight
	ljmp state_five_b
	
	sound_nine_fun_9:
	xrl a, #9
	jz sound_nine_fun
	ljmp sound_ten_fun_10
	sound_nine_fun:
	lcall sound_nine
	ljmp state_five_b
	
	sound_ten_fun_10:
	xrl a, #10
	jz sound_ten_fun
	ljmp sound_ele_fun_11
	sound_ten_fun:
	lcall sound_ten
	ljmp state_five_b
	
	sound_ele_fun_11:
	xrl a ,#11
	jz sound_eleven_fun
	ljmp sound_tw_fun_12
	sound_eleven_fun:
	lcall sound_eleven
	ljmp state_five_b
	
	sound_tw_fun_12:
	xrl a ,#12
	jz sound_twelve_fun
	ljmp sound_thirteen_fun_13
	sound_twelve_fun:
	lcall sound_twelve
	ljmp state_five_b
	
	sound_thirteen_fun_13:
	xrl a, #13
	jz sound_thirteen_fun
	ljmp sound_fourteen_fun_14
	sound_thirteen_fun:
	lcall sound_thirteen
	ljmp state_five_b
	
	sound_fourteen_fun_14:
	xrl a, #14
	jz sound_fourteen_fun
	ljmp sound_fifteen_fun_15
	sound_fourteen_fun:
	lcall sound_fourteen
	ljmp state_five_b
	
	sound_fifteen_fun_15:
	xrl a, #15
	jz sound_fifteen_fun
	ljmp sound_sixteen_fun_16
	sound_fifteen_fun:
	lcall sound_fifteen
	ljmp state_five_b
	
	sound_sixteen_fun_16:
	xrl a, #16
	jz sound_sixteen_fun
	ljmp sound_seventeen_fun_17
	sound_sixteen_fun:
	lcall sound_sixteen
	ljmp state_five_b
	
	sound_seventeen_fun_17:
	xrl a, #17
	jz sound_seventeen_fun
	ljmp  sound_eteen_fun_18
	sound_seventeen_fun:
	lcall sound_seven
	ljmp state_five_b
	
	sound_eteen_fun_18:
	xrl a ,#18
	jz sound_eighteen_fun
	ljmp sound_nteen_fun_19
	sound_eighteen_fun:
	lcall sound_eighteen
	ljmp state_five_b
	
	sound_nteen_fun_19:
	xrl a ,#19
	jz sound_nineteen_fun
	sound_nineteen_fun:
	lcall sound_nineteen
	ljmp state_five_b

 

	state_five_b:
	;jnb TR1, done_playing02
	setb done_playing_flag
	ljmp state_seven

state_seven:
	jnb done_playing_flag, state_seven
	sjmp continue
	
	continue:
	; this is where we incorporate jumping with flags ;check this
	clr five_second_flag
	jb state0flag, zero_state
Wait_Milli_Seconds(#50)
	jb state1flag, one_state
Wait_Milli_Seconds(#50)
	jb state2flag, two_state
Wait_Milli_Seconds(#50)
	jb state3flag, three_state
Wait_Milli_Seconds(#50)
	jb state4flag, four_state
Wait_Milli_Seconds(#50)
	jb state5flag, five_state

	
	zero_state: 
    ljmp state0_2
	one_state: 
    ljmp state1_2
	two_state: 
    ljmp state2_2
	three_state: 
    ljmp state3_2
	four_state: 
    ljmp state4_2
	five_state: 
    ljmp state5_2

state_eight:
	mov a, temp
	mov b, #100
	div ab
	;remainder is b
	mov a, b
	; sound 20-90 increment of 10
	mov b, #10
	div ab ; want quotient from here

	;check 5 sec
	;jnb  five_second_flag, no_sound03
	clr done_playing_flag

	; remainder + 20
	xrl a , #2
	jz sound_twenty_fun
	ljmp sound_30_fun

	sound_twenty_fun:
	lcall sound_twenty
	ljmp state_eight_b
	
	sound_30_fun:
	xrl a, #3
	jz sound_thirty_fun
	ljmp  sound_40_fun
	sound_thirty_fun:
	lcall sound_thirty
	ljmp state_eight_b
	
	
	sound_40_fun:
	xrl a, #4
	jz sound_forty_fun
	ljmp  sound_50_fun
	sound_forty_fun:
	lcall sound_forty
	ljmp state_eight_b
	
	
	sound_50_fun:
	xrl a, #5
	jz sound_fifty_fun
	ljmp sound_60_fun
	sound_fifty_fun:
	lcall sound_fifty
	ljmp state_eight_b
	
	
	sound_60_fun:
	xrl a, #6
	jz sound_sixty_fun
	ljmp sound_70_fun
	sound_sixty_fun:
	lcall sound_sixty
	ljmp state_eight_b
	
	
	sound_70_fun:
	xrl a, #7
	jz sound_seventy_fun
	ljmp sound_80_fun
	sound_seventy_fun:
	lcall sound_seventy
	ljmp state_eight_b
	
	sound_80_fun:
	xrl a, #8
	jz sound_eighty_fun
	ljmp sound_90_fun
	sound_eighty_fun:
	lcall sound_eighty
	ljmp state_eight_b
	
	
	sound_90_fun:
	xrl a, #9
	jz sound_ninety_fun
	ljmp state_eight_b
	sound_ninety_fun:
	lcall sound_ninety
	ljmp state_eight_b
	
	
state_eight_b:
	mov a,b ;mov remainder to a 
	;jnb TR1, do_not_play
	;do_not_play: ljmp done_playing02
	setb done_playing_flag
	ljmp state_nine

state_nine:
	jnb done_playing_flag, state_nine
	ljmp state_ten

state_ten:
	clr done_playing_flag

	sound_one_fun_:
	xrl a, #1
	jz sound_one_fun01
	ljmp sound_2_fun_
	sound_one_fun01:
	lcall sound_one
	ljmp state_ten_b
	
	sound_2_fun_:
	xrl a, #2
	jz sound_two_fun01
	ljmp sound_3_fun_
	sound_two_fun01:
	lcall sound_two
	ljmp state_ten_b
	
	sound_3_fun_:
	xrl a, #3
	jz sound_three_fun01
	ljmp sound_4_fun_
	sound_three_fun01:
	lcall sound_three
	ljmp state_ten_b
	
	sound_4_fun_:
	xrl a, #4
	jz sound_four_fun01
	ljmp sound_5_fun_
	sound_four_fun01:
	lcall sound_four
	ljmp state_ten_b
	
	sound_5_fun_:
	xrl a, #5
	jz sound_five_fun01
	ljmp sound_6_fun_
	sound_five_fun01:
	lcall sound_five
	ljmp state_ten_b
	
	
	sound_6_fun_:
	xrl a, #6
	jz sound_six_fun01
	ljmp sound_7_fun_
	sound_six_fun01:
	lcall sound_six
	ljmp state_ten_b
	
	
	sound_7_fun_:
	xrl a, #7
	jz sound_seven_fun01
	ljmp sound_8_fun_
	sound_seven_fun01:
	lcall sound_seven
	ljmp state_ten_b
	
	
	sound_8_fun_:
	xrl a, #8
	jz sound_eight_fun01
	ljmp sound_9_fun_
	sound_eight_fun01:
	lcall sound_eight
	ljmp state_ten_b
	
	
	sound_9_fun_:
	xrl a, #9
	jz sound_nine_fun01
	ljmp state_ten_b
	sound_nine_fun01:
	lcall sound_nine
	ljmp state_ten_b
	
state_ten_b:
	setb done_playing_flag
	ljmp state_seven

END

   
   