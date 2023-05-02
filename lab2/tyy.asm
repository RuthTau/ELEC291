



; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.1 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'BOOT' pushbutton connected to P4.5 is pressed.
$NOLIST
$MODLP51RC2
$LIST

CLK           EQU 22138400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000    ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))


;BOOT_BUTTON   equ P4.5
SOUND_OUT     equ P1.1
ONOFF    	  equ P0.0
UPDOWN        equ P0.1
HOUR_CLK 	  equ P2.4
MIN_CLK 	  equ P4.5
HOUR_ALARM    equ P0.6
MIN_ALARM 	  equ P0.3

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30

Count1ms:     ds 2 ; Used to determine when half second has passed
s:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
m:  ds 1
h: ds 1

A_m:  ds 1
A_h:  ds 1
Alarm_bit: ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
ampm: dbit 1
ampm2: dbit 1
ampm_flag: dbit 1
ampm_2_flag: dbit 1
P0_flag: dbit 1
Alarm_flag: dbit 1

cseg

; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Time    :  :    ', 0
Second_Message: db 'Alarm   :    ',0
AM_mess: db 'A ', 0
PM_mess: db 'P', 0


On_message: db 'On ', 0
Off_message:db 'Off', 0

Alarm_message: db '  REAL ALARMY   ',0
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

ani18:db '++++++++++++++++',0
ani19:db '+++++++++++++++ ',0
ani20:db '++++++++++++++  ',0
ani21:db '+++++++++++++   ',0
ani22:db '++++++++++++    ',0
ani23:db '+++++++++++     ',0                         
ani24:db '++++++++++      ',0
ani25:db '+++++++++       ',0
ani26:db '++++++++        ',0
ani27:db '+++++++         ',0
ani28:db '++++++          ',0
ani29:db '+++++           ',0
ani30:db '++++            ',0
ani31:db '+++             ',0
ani32:db '++              ',0
ani33:db '+               ',0
ani34:db '                ',0	

	
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; 13130000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD)
	mov RL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P1.1 ;
;---------------------------------;

Timer0_ISR:

	jb Alarm_flag, ring_sound
	jnb Alarm_flag, ring_mute
	
	
	
	ring_mute: 
	clr SOUND_OUT
	reti
	
	
	ring_sound:
	cpl SOUND_OUT
 	reti
 	
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
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
	cpl P1.0 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if every 1 second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done ;this change the seconds 
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	;Increment the BCD counter
	mov a, s
	jnb UPDOWN, Timer2_ISR_decrement
	add a, #0x01
	ljmp Timer2_ISR_da

Timer2_ISR_decrement:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
Timer2_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov s, a


Timer2_ISR_done:
	pop psw ;LIFO
	pop acc
	reti

;---------------------------------;
; Display effects			      ;
;---------------------------------;
flash_display:
	WriteCommand (#0b0000001100)
	Wait_Milli_Seconds(#50)
	
ret

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    lcall Timer0_Init
    lcall Timer2_Init
    ; In case you decide to use the pins of P0, configure the port in bidirectional mode:
    mov P0M0, #0
    mov P0M1, #0
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	
	; 0 for am, 1 for pm 
    setb half_seconds_flag
	clr ampm
	clr ampm2
	clr P0_flag
 	 
	;set as initial values
	mov s, #0x50
	mov m,#0x29
	mov h,#0x09

	;set for alarm
	mov A_m, #0x30
	mov A_h, #0x09
	mov Alarm_bit, #0x00

	;initial message;

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
	Send_Constant_String(#ani1)
	Wait_Milli_Seconds(#50)
	
	Set_Cursor(1,1)
	Send_Constant_String(#ani2)
	Set_Cursor(2,1)
	Send_Constant_String(#ani2)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani3)
	Set_Cursor(2,1)
	Send_Constant_String(#ani3)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani4)
	Set_Cursor(2,1)
	Send_Constant_String(#ani4)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani5)
	Set_Cursor(2,1)
	Send_Constant_String(#ani5)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani6)
	Set_Cursor(2,1)
	Send_Constant_String(#ani6)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani7)
	Set_Cursor(2,1)
	Send_Constant_String(#ani7)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani8)
	Set_Cursor(2,1)
	Send_Constant_String(#ani8)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani9)
	Set_Cursor(2,1)
	Send_Constant_String(#ani9)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani10)
	Set_Cursor(2,1)
	Send_Constant_String(#ani10)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani11)
	Set_Cursor(2,1)
	Send_Constant_String(#ani11)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani12)
	Set_Cursor(2,1)
	Send_Constant_String(#ani12)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani13)
	Set_Cursor(2,1)
	Send_Constant_String(#ani13)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani14)
	Set_Cursor(2,1)
	Send_Constant_String(#ani14)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani15)
	Set_Cursor(2,1)
	Send_Constant_String(#ani15)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani16)
	Set_Cursor(2,1)
	Send_Constant_String(#ani16)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani17)
	Set_Cursor(2,1)
	Send_Constant_String(#ani17)
	Wait_Milli_Seconds(#50)
	
	
	Set_Cursor(1,1)
	Send_Constant_String(#ani18)
	Set_Cursor(2,1)
	Send_Constant_String(#ani18)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani19)
	Set_Cursor(2,1)
	Send_Constant_String(#ani19)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani20)
	Set_Cursor(2,1)
	Send_Constant_String(#ani20)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani21)
	Set_Cursor(2,1)
	Send_Constant_String(#ani21)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani22)
	Set_Cursor(2,1)
	Send_Constant_String(#ani22)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani23)
	Set_Cursor(2,1)
	Send_Constant_String(#ani23)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani24)
	Set_Cursor(2,1)
	Send_Constant_String(#ani24)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani25)
	Set_Cursor(2,1)
	Send_Constant_String(#ani25)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani26)
	Set_Cursor(2,1)
	Send_Constant_String(#ani26)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani27)
	Set_Cursor(2,1)
	Send_Constant_String(#ani27)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani28)
	Set_Cursor(2,1)
	Send_Constant_String(#ani28)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani29)
	Set_Cursor(2,1)
	Send_Constant_String(#ani29)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani30)
	Set_Cursor(2,1)
	Send_Constant_String(#ani30)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani31)
	Set_Cursor(2,1)
	Send_Constant_String(#ani31)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani32)
	Set_Cursor(2,1)
	Send_Constant_String(#ani32)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani33)
	Set_Cursor(2,1)
	Send_Constant_String(#ani33)
	Wait_Milli_Seconds(#50)
	Set_Cursor(1,1)
	Send_Constant_String(#ani34)
	Set_Cursor(2,1)
	Send_Constant_String(#ani34)
	Wait_Milli_Seconds(#50)
	
	
	;Actual interface;
	
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    
    Set_Cursor(1,15)
   	Send_Constant_String(#AM_mess)
    ;message line 2;
    Set_Cursor(2,1)
    Send_Constant_String(#Second_Message)

	Set_Cursor(2,12)
	Send_Constant_String(#AM_mess)

	
	Set_Cursor(2,14)
	Send_Constant_String(#Off_message)

	
	Set_Cursor(1, 13)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(s) ; This macro is also in 'LCD_4bit.inc'
	
	;display minutes
	Set_Cursor(1,10)
	Display_BCD(m)
	
   	;display hours
	Set_Cursor(1,7)
	Display_BCD(h)
    
    ;set values at line 2 
    Set_Cursor(2,7)
	Display_BCD(A_m)
	
	Set_Cursor(2,10)
	Display_BCD(A_h)
	
	; After initialization the program stays in this 'forever' loop
loop:
	;jb BOOT_BUTTON, loop_a  ; if the 'BOOT' button is not pressed skip
	;Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	;jb BOOT_BUTTON, loop_a  ; if the 'BOOT' button is not pressed skip
	;jnb BOOT_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	; A valid press of the 'BOOT' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	clr TR2                 ; Stop timer 2
	clr a
	
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Now clear the BCD counter
	mov s, a

	
	setb TR2                ; Start timer 2
	sjmp loop_b             ; Display the new value

loop_a:
	jnb half_seconds_flag, loop
loop_b:
	;display seconds
    clr half_seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
	

	Set_Cursor(1, 13)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(s) ; This macro is also in 'LCD_4bit.inc'
	
	;display minutes
	Set_Cursor(1,10)
	Display_BCD(m)
	
   	;display hours
	Set_Cursor(1,7)
	Display_BCD(h)

	;display Alarm
	Set_Cursor(2,7)
	Display_BCD(A_h)

	Set_Cursor(2,10)
	Display_BCD(A_m)
	
	
	ljmp loop_c

loop_c:	
	mov a, s 
	;add a, #1
	;da a
	;mov s, a
	cjne a, #0x59, Hour
	mov s, #0x00 

	mov a , m 
	add a, #1 
	da a 
	mov m, a
	cjne a, #0x60, Hour 
	mov m, #0x00 

	mov a, h 
	add a, #1
	da a 
	mov h, a
	cjne a, #0x13, Hour
	mov h, #0x01
	ljmp next
	


	Hour:
	setb HOUR_CLK
	jnb  HOUR_CLK, hour_button;jump if not bit
	Wait_Milli_Seconds(#100)
	jnb  HOUR_CLK, hour_button
	sjmp min_button

	hour_button:
	mov a, h
	add a, #1
	da a 
	mov h, a
	
	check_ampm:
	xrl a, #0x12 
	jz switchampm
	mov a, h
	;if a is more than 12 count back to 0
	cjne a , #0x13, min_button
	mov h,#0x01
	sjmp min_button

	switchampm:
	 ; check id bit is 0: pm 1:am
	cpl ampm
	jb	ampm, display01
	Set_Cursor(1,15)
   	Send_Constant_String(#AM_mess)
	setb ampm_flag
	ljmp next

	display01:
	Set_Cursor(1,15)
   	Send_Constant_String(#PM_mess)
	clr ampm_flag
	ljmp next



	min_button:
	setb MIN_CLK
	jnb MIN_CLK, Button_controls
	Wait_Milli_Seconds(#100)
	jnb MIN_CLK, Button_controls
	ljmp next


	Button_controls:
	mov a, m
	add a, #0x01
	da a
	mov m, a

	cjne a, #0x60, next
	mov m, #0x00

	mov a, h
	add a,#0x01
	da a 
	mov h,a
	cjne a, #0x13, next
	mov h, #0x01
	ljmp next


	next:
	setb HOUR_ALARM
	jb HOUR_ALARM, do_not_increment_hours
	Wait_Milli_Seconds(#50)
	jb HOUR_ALARM, do_not_increment_hours
	jnb HOUR_ALARM, $
	mov a, A_h
	add a, #1
	da a 
	mov A_h, a
	check_ampm2:
	xrl a, #0x12 
	jz switchampm2
	mov a, A_h
	cjne a, #0x13, min_button_a
	mov A_h, #0x01
	sjmp min_button_a

	do_not_increment_hours:
	ljmp min_button_a

	no_hours_overflow:
	ljmp min_button_a

	
	switchampm2:
	cpl ampm2
	jb	ampm2, display02
	;setb =1 clr =0
	setb ampm_2_flag
	Set_Cursor(2,12)
   	Send_Constant_String(#AM_mess)
	ljmp on_off_alarm  

	display02:
	Set_Cursor(2,12)
   	Send_Constant_String(#PM_mess)
	clr ampm_2_flag
	ljmp on_off_alarm  

	min_button_a:
	setb MIN_ALARM
	jnb MIN_ALARM, clock_control
	Wait_Milli_Seconds(#50)
	jnb MIN_ALARM, clock_control
	ljmp on_off_alarm  

	clock_control:
	mov a, A_m
	add a, #1
	da a 
	mov A_m, a

	cjne a, #0x60, on_off_alarm  
	mov A_m, #0x00

	mov a, A_h
	add a, #1
	da a 
	mov A_h, a

	cjne a, #0x13, on_off_alarm  
	mov A_h, #0x01
	ljmp on_off_alarm  
	

	on_off_alarm:
	setb ONOFF
	jb ONOFF, no_on_off
	Wait_Milli_Seconds(#50)
	jb ONOFF, no_on_off
	jnb ONOFF, $

	
	;mov a, P0_flag
	;anl a, #0b00000001
	;jz display_Off
	
	cpl P0_flag
	jb P0_flag, display_On
	ljmp display_Off
	
	display_On:
	Set_Cursor(2,14)
	Send_Constant_String(#On_message)
	;mov a, P0_flag
	;anl a, #0b00000001
	;cpl a
	;mov P0_flag, a
	ljmp alarmy

	no_on_off:
	ljmp return

	display_Off:
	Set_Cursor(2,14)
	Send_Constant_String(#Off_message)
	;mov a, P0_flag
	;anl a, #0b00000001
	;cpl a
	;mov P0_flag, a
	ljmp alarmy
	
	;ALARM SYSTEM + RING
	alarmy:
	setb SOUND_OUT
	;mov a , P0_flag
	jnb P0_flag, no_match
	mov a, h
	cjne a, A_h, no_match
	mov a, m
	cjne a, A_m, no_match
	mov a, ampm_flag
	cjne a, ampm_2_flag, no_match
	ljmp ring
	
	no_match:
	clr Alarm_flag
	ljmp return
	
	ring:
	;ljmp Timer0_ISR
	setb Alarm_flag
	Wait_Milli_Seconds(#250)
	ljmp return
 

	
return:
	;Wait_Milli_Seconds(#50)
    ljmp loop_b


 	
END
