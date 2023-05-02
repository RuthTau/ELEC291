 $MODLP51RC2
org 0000H
   ljmp MainProgram

CLK  EQU 22118400
BAUD equ 115200
BRG_VAL equ (0x100-(CLK/(16*BAUD)))


; These 'equ' must match the hardware wiring
; They are used by 'LCD_4bit.inc'
LCD_RS equ P3.2
; LCD_RW equ Px.x ; Always grounded
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7 
ONOFF     equ P0.0
SOUND_OUT equ P1.1
$NOLIST
$include(LCD_4bit.inc)
$LIST


; These �EQU� must match the wiring between the microcontroller and ADC 
CE_ADC EQU P2.0  ;thermometer sensor 
MY_MOSI EQU P2.1  ;MOSI
MY_MISO EQU P2.2  ;MISO
MY_SCLK EQU P2.3  ;CLK
 

dseg at 0x30
Result: ds 2
x:   ds 4
y:   ds 4
bcd: ds 5
button_1: ds 1


BSEG
mf: dbit 1 ; flag
Alarm_flag: dbit 1

$NOLIST
$include(math32.inc)
$LIST

CSEG
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
    
INIT_SPI:
	setb MY_MISO
	clr MY_SCLK
	ret

DO_SPI_G: 
 	push acc 
 	mov R1, #0 ; Received byte stored in R1
 	mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP: 
 	mov a, R0 ; Byte to write is in R0
 	rlc a ; Carry flag has bit to write
 	mov R0, a 
 	mov MY_MOSI, c 
 	setb MY_SCLK ; Transmit
 	mov c, MY_MISO ; Read received bit
 	mov a, R1 ; Save received bit in R1
 	rlc a 
 	mov R1, a 
 	clr MY_SCLK 
 	djnz R2, DO_SPI_G_LOOP 
 	pop acc 
 	ret

Display_10_digit_BCD01:
	Set_Cursor(1,13)
	Display_BCD(bcd+0)
	ret 

Display_10_digit_BCD02:
	Set_Cursor(2,11)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	
	Set_Cursor(2,11)
	Send_Constant_String(#space)
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
	
	mov a, #'\r'
	lcall putchar
	
	mov a, #'\n'
	lcall putchar
	
	pop acc
	ret

Delay:
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	ret
	
Calculation1:
	mov x+0, Result + 0
	mov x+1, Result + 1
	mov x+2, #0
	mov x+3, #0
	;multi by 410
	load_Y(410)
	lcall mul32
	;Divide result by 1023
	load_Y(1023)
	lcall div32
	;subtract 273 from result
	load_Y(273)
	lcall sub32
 	ret
	
Calculation2:
	mov x+0, Result + 0
	mov x+1, Result + 1
	mov x+2, #0
	mov x+3, #0
	;multi by 410
	load_Y(410)
	lcall mul32
	;Divide result by 1023
	load_Y(1023)
	lcall div32
	;subtract 273 from result
	load_Y(273)
	lcall sub32
	;9/5+32
	load_Y(9)
	lcall mul32
	load_y(5)
	lcall div32
	load_Y(32)
	lcall add32
	ret

Ring_or_not:

	jb Alarm_flag, ring_sound
	jnb Alarm_flag, ring_mute
	
	ring_mute: 
	clr SOUND_OUT
	ret
	
	;1-0-1-0
	ring_sound:
	setb SOUND_OUT
	Set_Cursor(1,1)
	Send_Constant_String(#th_mess)
	Set_Cursor(2,1)
	Send_Constant_String(#ani18)
	cpl SOUND_OUT
	ret	
	
loop_display:
	lcall Delay
 	ljmp loop_a
 	ret
 	
; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    mov A, bcd+0
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
    
SendStringDone:
    ret
    

space: DB ' ',0
Celsius_mess:
    DB 'Celsius:       C', 0
    ret
F_mess:
	DB 'Fahrenh:       F',0
th_mess: db '   THRESHOLD        ',0
Animation_mess:
Alarm_message: db '   REAL THERMO   ',0
Alarm_message02: db '****************',0
ani1: db '                ',0
ani2: db '+               ',0
ani3: db '++              ',0
ani4: db '+++             ',0
ani5: db '++++            ',0
ani6: db '+++++           ',0
ani7: db '++++++          ',0
ani8: db '+++++++         ',0
ani9: db '++++++++        ',0
ani10:db '+++++++++       ',0
ani11:db '++++++++++      ',0
ani12:db '+++++++++++     ',0
ani13:db '++++++++++++    ',0
ani14:db '+++++++++++++   ',0
ani15:db '++++++++++++++  ',0
ani16:db '+++++++++++++++ ',0
ani17:db '++++++++++++++++',0
ani18:db '                ',0
ani19:db '               +',0
ani20:db '              ++',0
ani21:db '             +++',0
ani22:db '            ++++',0
ani23:db '           +++++',0
ani24:db '          ++++++',0                         
ani25:db '         +++++++',0
ani26:db '        ++++++++',0
ani27:db '       +++++++++',0
ani28:db '      ++++++++++',0
ani29:db '     +++++++++++',0
ani30:db '    ++++++++++++',0
ani31:db '   +++++++++++++',0
ani32:db '  ++++++++++++++',0
ani33:db ' +++++++++++++++',0
ani34:db '++++++++++++++++',0


MainProgram:
	lcall INIT_SPI
	mov P0M0, #0
    mov P0M1, #0
    lcall LCD_4BIT
 
Animation:
	Set_Cursor(1,1)
	Send_Constant_String(#Alarm_message)
	
	Set_Cursor(2,1)
	Send_Constant_String(#Alarm_message02)
	
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	
	Set_Cursor(1,1)
	Send_Constant_String(#ani1)
	Set_Cursor(2,1)
	Send_Constant_String(#ani18)
	Wait_Milli_Seconds(#50)
	
	Set_Cursor(1,1)
	Send_Constant_String(#ani2)
	Set_Cursor(2,1)
	Send_Constant_String(#ani19)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani3)
	Set_Cursor(2,1)
	Send_Constant_String(#ani20)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani4)
	Set_Cursor(2,1)
	Send_Constant_String(#ani21)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani5)
	Set_Cursor(2,1)
	Send_Constant_String(#ani22)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani6)
	Set_Cursor(2,1)
	Send_Constant_String(#ani23)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani7)
	Set_Cursor(2,1)
	Send_Constant_String(#ani24)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani8)
	Set_Cursor(2,1)
	Send_Constant_String(#ani25)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani9)
	Set_Cursor(2,1)
	Send_Constant_String(#ani26)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani10)
	Set_Cursor(2,1)
	Send_Constant_String(#ani27)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani11)
	Set_Cursor(2,1)
	Send_Constant_String(#ani28)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani12)
	Set_Cursor(2,1)
	Send_Constant_String(#ani29)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani13)
	Set_Cursor(2,1)
	Send_Constant_String(#ani30)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani14)
	Set_Cursor(2,1)
	Send_Constant_String(#ani31)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani15)
	Set_Cursor(2,1)
	Send_Constant_String(#ani32)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani16)
	Set_Cursor(2,1)
	Send_Constant_String(#ani33)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani17)
	Set_Cursor(2,1)
	Send_Constant_String(#ani34)
	Wait_Milli_Seconds(#50)
	
	Wait_Milli_Seconds(#100)
	
	Set_Cursor(1,1)
	Send_Constant_String(#ani17)
	Set_Cursor(2,1)
	Send_Constant_String(#ani34)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani16)
	Set_Cursor(2,1)
	Send_Constant_String(#ani33)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani15)
	Set_Cursor(2,1)
	Send_Constant_String(#ani32)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani14)
	Set_Cursor(2,1)
	Send_Constant_String(#ani31)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani13)
	Set_Cursor(2,1)
	Send_Constant_String(#ani30)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani12)
	Set_Cursor(2,1)
	Send_Constant_String(#ani29)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani11)
	Set_Cursor(2,1)
	Send_Constant_String(#ani28)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani10)
	Set_Cursor(2,1)
	Send_Constant_String(#ani27)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani9)
	Set_Cursor(2,1)
	Send_Constant_String(#ani26)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani8)
	Set_Cursor(2,1)
	Send_Constant_String(#ani25)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani7)
	Set_Cursor(2,1)
	Send_Constant_String(#ani24)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani6)
	Set_Cursor(2,1)
	Send_Constant_String(#ani23)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani5)
	Set_Cursor(2,1)
	Send_Constant_String(#ani22)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani4)
	Set_Cursor(2,1)
	Send_Constant_String(#ani21)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani3)
	Set_Cursor(2,1)
	Send_Constant_String(#ani20)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani2)
	Set_Cursor(2,1)
	Send_Constant_String(#ani19)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani1)
	Set_Cursor(2,1)
	Send_Constant_String(#ani18)
	Wait_Milli_Seconds(#50)   

Forever:
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    lcall InitSerialPort
     
    ;GUI 1
    set_Cursor(1,1)
    Send_Constant_String(#Celsius_mess)
    
    set_Cursor(2,1)
    Send_Constant_String(#F_mess)
    
loop_a:   
	clr CE_ADC ;sensor = low
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B ; Single ended, read channel 0
	lcall DO_SPI_G
	mov a, R1          ; R1 contains bits 8 and 9
	anl a, #00000011B  ; We need only the two least significant bits
	mov Result+1, a    ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1     ; R1 contains bits 0 to 7.  Save result low.
	setb CE_ADC		;switch on the temp sensor
	
	
	;Read_ADC_Channel(6)
	sjmp calculation_cel
	
	
	
	calculation_cel:
	lcall Calculation1
	sjmp convert
	
	
	; conversion
	convert:
	lcall hex2bcd
	sjmp button_click
	
	
	button_click:
	mov a, bcd+0
	cjne a, #0x99, Button
	mov bcd+0, #0x00 ; reset to 0
	sjmp checking
	
	Button:
	setb ONOFF
	jb ONOFF, increase
	Wait_Milli_Seconds(#50)
	jb ONOFF, increase
	jnb ONOFF, $
	sjmp checking
	
	increase:
	mov a, bcd+0
	add a, #1
	da a
	mov bcd+0, a
	sjmp checking
	
	checking:
	setb SOUND_OUT
	mov a, bcd+0
	mov b, #0x32 ;lower bound
	cjne a, b, no_ring ;check if greater/ equal to 
	;mov b, #0x29 ;upper bound
	;cjne a, b, no_ring
	sjmp ring
	
	no_ring:
	clr Alarm_flag
	sjmp check3
	
	ring:
	setb Alarm_flag
	sjmp check3
	
	check3:
	lcall Ring_or_not
	sjmp Display_num
 
	
	Display_num:
	lcall Display_10_digit_BCD01
	
	;display in putty
	Send_BCD(bcd+0)

	;calculation for F
	lcall Calculation2
	lcall hex2bcd
	lcall Display_10_digit_BCD02
	
	Delay_before_loop_again:
	lcall Delay

	
	ljmp Forever
    
  
END
