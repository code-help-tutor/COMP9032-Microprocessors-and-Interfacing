WeChat: cstutorcs
QQ: 749389476
Email: tutorcs@163.com
; lab4_task3.asm
;
; Created: 2018/10/8 16:39:35
; Author : Ran Bai
; Version number : 1.0
; Function :  measures the speed of the motor (based on the number of holes that
;             are detected by the shaft encoder) and displays the speed on LCD.  
; Replace with your application code
; Connect way: Opo --> INT0
;              Ope --> any +5v
;              Mot --> POT (As turn the POT, the speed of the motor changes accordingly.)
;              D0-7 --> PF0-7
;              BE-RS --> PA4-7
.include "m2560def.inc"
.def temp = r17
.def count = r18
.def zero = r19
.def four_times = r26

.def hundred = r20      ; stored 3 different position of count
.def ten = r21
.def one = r22

.def count_H = r25      ; count 2 bytes 
.def count_L = r24


.cseg
      jmp RESET
.org  INT0addr
      jmp EXT_INT0
.org OVF0addr
	  jmp Timer0OVF


.macro do_lcd_command           ; transfer command to LCD
	ldi r16, @0                 ; load data @0 to r16
	rcall lcd_command           ; rcall lcd_command
	rcall lcd_wait              ; rcall lcd_wait
.endmacro

.macro do_lcd_data              ; transfer data to LCD
	mov r16, @0                 ; move data @0 to r16
	rcall lcd_data              ; rcall lcd_data
	rcall lcd_wait              ; rcall lcd_wait
.endmacro


RESET:
     clr four_times              ; clear four_times
     clr count                   ; clear count

	 ldi r16, low(RAMEND)         ; RAMEND : 0x21FF       
	 out SPL, r16                 ; initial stack pointer Low 8 bits
	 ldi r16, high(RAMEND)        ; RAMEND: 0x21FF
	 out SPH, r16                 ; initial High 8 bits of stack pointer

	                              ; LCD initalization
	 ser r16                      ; set r16 to 0xFF
	 out DDRF, r16                ; set PORT F to input mode
	 out DDRA, r16                ; set PORT A to input mode
	 clr r16                      ; clear r16
	 out PORTF, r16               ; out 0x00 to PORT F
	 out PORTA, r16               ; out 0x00 to PORT A

	 do_lcd_command 0b00111000 ; 2x5x7
	 rcall sleep_5ms
	 do_lcd_command 0b00111000 ; 2x5x7
	 rcall sleep_1ms
	 do_lcd_command 0b00111000 ; 2x5x7
	 do_lcd_command 0b00111000 ; 2x5x7
	 do_lcd_command 0b00001001 ; display off
	 do_lcd_command 0b00000001 ; clear display
	 do_lcd_command 0b00000110 ; increment, no display shift
	 do_lcd_command 0b00001111 ; Cursor on, bar, no blink

	 ldi temp, (2 << ISC00)	     ; set INT0 as falling edge triggered interrupt
	 sts EICRA, temp
	 in temp, EIMSK		         ; enable INT0
	 ori temp, (1<<INT0)
	 out EIMSK, temp

	 ldi temp, 0b00000000
	 out TCCR0A, temp
	 ldi temp, 0b00000011
	 out TCCR0B, temp				; Prescaling value=64
	 ldi temp, 1<<TOIE0				; =1024 microseconds
	 sts TIMSK0, temp				; T/C0 interrupt enable 

	 sei							; enable the global interrupt                          
	 jmp main

EXT_INT0:
     inc four_times
	 cpi four_times, 4
	 brne not_increase
     inc count						; increase the count
	 clr four_times
not_increase:
	 reti                           ; return from interrupt

Timer0OVF:							; interrupt subroutine for Timer0
	adiw r25:r24, 1					; Increase the temporary counter by one.
	cpi r24, low(1000)				; Check if (r25:r24)=1000
    brne NotSecond
	cpi r25, high(1000)				; 1000 = 106/1024
	brne NotSecond
	; operation is here
	do_lcd_command 0b00000001       ; clear and return to first place in the first line
	ldi zero, '0'

	clr hundred
	clr ten
	clr one
cal_hundred:
	cpi count, 100
	brlo cal_ten
	inc hundred
	subi count, 100
	rjmp cal_hundred
cal_ten:
    cpi count, 10
	brlo cal_one
	subi count, 10
	inc ten
	rjmp cal_ten
cal_one:
    mov one, count

	add hundred, zero
	add ten, zero
	add one, zero
	do_lcd_data hundred             ; display hundred in LCD
	do_lcd_data ten                 ; display ten in LCD
	do_lcd_data one                 ; display one in LCD

	clr count                       ; clear count
	clr count_H
	clr count_L
	; end operation
NotSecond:
	reti							; Return from the interrupt.


main:
   rjmp main

.equ LCD_RS = 7                     ; LCD_RS equal to 7        
.equ LCD_E = 6                      ; LCD_E equal to 6
.equ LCD_RW = 5                     ; LCD_RW equal to 5
.equ LCD_BE = 4                     ; LCD_BE equal to 4

.macro lcd_set
	sbi PORTA, @0                   ; set pin @0 of port A to 1
.endmacro
.macro lcd_clr
	cbi PORTA, @0                   ; clear pin @0 of port A to 0
.endmacro

;
; Send a command to the LCD (r16)
;

lcd_command:                        ; send a command to LCD IR
	out PORTF, r16
	nop
	lcd_set LCD_E                   ; use macro lcd_set to set pin 7 of port A to 1
	nop
	nop
	nop
	lcd_clr LCD_E                   ; use macro lcd_clr to clear pin 7 of port A to 0
	nop
	nop
	nop
	ret

lcd_data:                           ; send a data to LCD DR
	out PORTF, r16                  ; output r16 to port F
	lcd_set LCD_RS                  ; use macro lcd_set to set pin 7 of port A to 1
	nop
	nop
	nop
	lcd_set LCD_E                   ; use macro lcd_set to set pin 6 of port A to 1
	nop
	nop
	nop
	lcd_clr LCD_E                   ; use macro lcd_clr to clear pin 6 of port A to 0
	nop
	nop
	nop
	lcd_clr LCD_RS                  ; use macro lcd_clr to clear pin 7 of port A to 0
	ret

lcd_wait:                            ; LCD busy wait
	push r16                         ; push r16 into stack
	clr r16                          ; clear r16
	out DDRF, r16                    ; set port F to output mode
	out PORTF, r16                   ; output 0x00 in port F 
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E                    ; use macro lcd_set to set pin 6 of port A to 1
	nop
	nop
    nop
	in r16, PINF                     ; read data from port F to r16
	lcd_clr LCD_E                    ; use macro lcd_clr to clear pin 6 of port A to 0
	sbrc r16, 7                      ; Skip if Bit 7 in R16 is Cleared
	rjmp lcd_wait_loop               ; rjmp to lcd_wait_loop
	lcd_clr LCD_RW                   ; use macro lcd_clr to clear pin 7 of port A to 0
	ser r16                          ; set r16 to 0xFF
	out DDRF, r16                    ; set port F to input mode
	pop r16                          ; pop r16 from stack
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:                                   ; sleep 1ms
	push r24                                 ; push r24 to stack
	push r25                                 ; push r25 to stack
	ldi r25, high(DELAY_1MS)                 ; load high 8 bits of DELAY_1MS to r25
	ldi r24, low(DELAY_1MS)                  ; load low 8 bits of DELAY_1MS to r25
delayloop_1ms:
	sbiw r25:r24, 1                          ; r25:r24 = r25:r24 - 1
	brne delayloop_1ms                       ; branch to delayloop_1ms
	pop r25                                  ; pop r25 from stack
	pop r24                                  ; pop r24 from stack
	ret

sleep_5ms:                                    ; sleep 5ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	rcall sleep_1ms                           ; 1ms
	ret
