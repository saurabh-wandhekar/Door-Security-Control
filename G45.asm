#make_bin#

#LOAD_SEGMENT=FFFFh#
#LOAD_OFFSET=0000h#

#CS=0000h#
#IP=0000h#
#DS=0000h#
#ES=0000h#
#SS=0000h#
#SP=FFFEh#
#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#


    jmp     st1 
    db     5 dup(0)
		 
    ;IVT entry for NMI (INT 02h)
    dw     Nmi_24hrtimer
    dw     0000		 
    db     500 dup(0)
		 
	;IVT entry for 80H
	dw     Switch_intR
    dw     0000
	db     508 dup(0)
	st1:   cli 
		
	;Intialize DS,ES,SS to start of RAM
    mov    ax,0200h    
    mov    ds,ax
    mov    es,ax
    mov    ss,ax
    mov    sp,0FFFEH  
		  
	;8255-1  	  
	A1 equ 00h
	B1 equ 02h
	C1 equ 04h
	CR1 equ 06h
	
	;8255-2
	A2 equ 08H
	B2 equ 0Ah
	C2 equ 0Ch
	CR2 equ 0Eh
		
	;8253-1	
	clk_01 equ 10h
	clk_11 equ 12h
	clk_21 equ 14h
	CR3 equ 16h
		
	;8253-2	
	clk_02 equ 18h
	clk_12 equ 1Ah
	clk_22 equ 1Ch
	CR4 equ 1Eh
	
; INITIALIZATION OF 8255
	sti	  	
	mov al,89h  	; control word for 8255-2 
	out CR2,al    
	
	mov al,88h	; control word for 8255-1 
	out CR1,al
	
; INITIALIZATION OF TIMERS
	mov al,36h	;control word for 8253-1 counter 0, Mode 3
	out CR3,al
	
	mov al,56h  	;control word for 8253-1 counter 1, Mode 3
	out CR3,al
	
	mov al,92h  	;control word for 8253-1 counter 2, Mode 1
	out CR3,al    

	mov al,34h  	;control word for 8253-2 counter 0, Mode 2
	out CR4,al    

	mov al,5ah  	;control word for 8253-2 counter 1 , Mode 5
	out CR4,al    

	mov al,94h  	;control word for 8253-2 counter 2 ,Mode 2
	out CR4,al
    
	mov al,50h	;load count lsb for 8253-1 counter 0 | Count value = 50000(dec)
	out clk_01, al
	
	mov al,0C3h 	;load count msb for 8253-1 counter 0 
	out clk_01, al
	
	mov al,64h	;load count for 8253-1 counter 1 | Count value = 100(dec)
	out clk_11, al
	
	mov al,1eh	;load count lsb for 8253-1 counter 2 (1 minute Timer) | Count value = 30(dec)
	out clk_21, al
	
	mov al,0C0h	;load count for 8253-2  LSB counter 0 (24 hour counter) | Count value =43200(dec)
	out clk_02, al
	
	mov al,0A8h	;load count for 8253-2  MSB counter 0      (24 hour counter)
	out 18h,al
	
	mov al,3	;load count for 8253-2 counter 1 (Switch trigger counter) | Count value = 3(dec)
	out clk_12, al
	
	mov al,2	;load count for 8253-2 counter 2 | Count value = 2(dec)
	out clk_22, al
	
	mov al,00h 	;default low output from 8255-2 upper port C
	out C2, al
	
; LCD INITIALIZATION 
	call DELAY_20ms 
	mov al,04h
	out B1,al
	call DELAY_20ms
	mov al,00h
	out B1,al
	
	mov al,38h
	out A1,al
	
	mov al,04h
	out B1,al
	call DELAY_20ms
	mov al,00h
	out B1,al
	call DELAY_20ms
	mov al,0Fh
	out A1,al
	mov al,04h
	out B1,al
	call DELAY_20ms
	mov al,00h
	out B1,al
	
	mov al,06h
	out A1,al
	call DELAY_20ms
	mov al,04h
	out B1,al
	call DELAY_20ms
	mov al,00h
	out B1,al
	mov al,01h
	out A1,al
	call DELAY_20ms  		
; LCD INITIALIZATION ENDS
	
    mov ax,0200h ;initaialize DS
	mov ds,ax
	
;hard coding master password : 1111111111111111
	mov si,0000h
    mov cx,16d
x_master_pass:	
    mov al,0edh
	mov [si],al                 
	inc si
	dec cx
	jnz x_master_pass
	
	
;hard coding alarm password : 99999999999999	
	mov cx,14
x_alarm_pass:		
    mov al,0bdh
    mov [si],al
    inc si
	dec cx
	jnz x_alarm_pass
		
	mov al,0ffh 
	out 08h,al
		
start:	
    call clear_LCD	
	call welcome_msg
	mov bp,00h
	call keypad_input
	cmp al,0bbh
	jz Master_mode
	jmp start ;press valid key
	
x6: call clear_LCD
	call welcome_msg
	call keypad_input
	cmp al,0b7h
	jz User_mode
	jmp x6 ;press valid key
	
Master_mode:	
    call intitiate_master_seq
    mov bp,0abcdh
    cmp ax,0abcdh
    jnz x6
x8: call keypad_input
	cmp al,7Dh ;A key
	jz Alarm_mode
	jnz x8
	
Alarm_mode:
   call intitiate_alarm_seq
   cmp dh,6h ;Alarm caused by wrong Master pwd
   jz start
   cmp dh,1h ;Alarm caused by wrong User pwd
   jz x6
   jmp x70
   
User_mode:	
   call intitiate_user_seq
   cmp ax,0abcdh
   jz x8
   jnz x6		

x70:	
stop: jmp stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;-------PROCEDURES--------;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DELAY_20ms proc
	MOV	CH,5
	X4:	NOP
		NOP
		DEC 	CH
		JNZ 	X4
	RET
DELAY_20ms endp

DELAY_max proc
	MOV	cx,0ffffh
	X16:NOP
		NOP
		DEC 	cx
		JNZ 	X16
	RET
DELAY_max endp

clear_LCD proc
	mov al,00h
	out B1,al
	call DELAY_20ms
	mov al,01h		;Clear Display
	out A1,al
	call DELAY_20ms
	mov al,04h
	out B1,al
	call DELAY_20ms
	mov al,00h
	out B1,al  
RET
clear_LCD endp

press_enter_msg proc  
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h ;E=1 RW=0 RS=1 -> data write 
	out B1,al
	call DELAY_20ms
	mov al,01h ;E=1 RW=0 RS=1 -> data write H-L transition
	out B1,al  ;prints Space
	
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,50h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints P
	
	mov al,52h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints R
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,53h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints S
	
	mov al,53h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints S
	
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,4Eh
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints N
	
	mov al,54h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints T
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,52h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints R
RET
press_enter_msg endp	
	
welcome_msg proc
	
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,57h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints W
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,4Ch
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints L
		
	mov al,43h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints C
	
	mov al,4Fh
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints O
	
	mov al,4dh
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints M
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E

ret
welcome_msg endp
	
updateday_msg proc   
mov al,55h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints U
	
	mov al,50h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints P
	
	mov al,44h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints D
	
	mov al,41h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints A
	
	mov al,54h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints T
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,0a0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,44h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints D
	
	mov al,41h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints A
	
	mov al,59h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Y
	
	mov al,0a0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,50h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al ;prints P
	
	mov al,41h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints A
	
	mov al,53h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints S 
	
	mov al,53h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints S 
ret	
updateday_msg endp		

Display_* proc
		mov al,2Ah
		out A1,al
		call DELAY_20ms
		mov al,05h
		out B1,al
		call DELAY_20ms
		mov al,01h
		out B1,al  ;prints *
ret
Display_* endp		
	
keypad_input proc ;SubR for keypad entry,al has unique key input value.
x0:		mov al,00h
		out C1,al
x1:		in al, C1
		and al,0f0h
		cmp al,0f0h
		jnz x1
		CALL DELAY_20ms
		
		mov al,00h				; Check for key press
		out 04,al

x2:		in al, C1
		and al,0F0h
		cmp al,0F0h
		jz x2
		CALL DELAY_20ms
		
		mov al,00h				; Check for key press
		out 04,al
		in al, C1
		and al,0F0h
		cmp al,0F0h
		jz x2
		
		mov al,0Eh				;Check for key press column 1
		mov bl,al
		out C1,al
		in al, C1
		and al,0f0h
		cmp al,0f0h
		jnz x3
		
		mov al,0Dh				;Check for key press column 2
		mov bl,al
		out C1,al
		in al, C1
		and al,0f0h
		cmp al,0f0h
		jnz x3
		
		mov al,0Bh				;Check for key press column 3
		mov bl,al
		out C1,al
		in al, C1
		and al,0f0h
		cmp al,0f0h
		jnz x3
		
		mov al,07h				;Check for key press column 4
		mov bl,al
		out C1,al
		in al,C1
		and al,0f0h
		cmp al,0f0h
		jz x2
		
x3:		or al,bl		
ret
keypad_input endp
	
error_msg proc
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,4Eh
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints N
	
	mov al,54h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints T
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,52h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints R
	
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,31h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints 1
	
	mov al,32h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints 2
	
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,44h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints D
	
	mov al,49h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints I
	
	mov al,47h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints G
	
	mov al,49h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints I
	
	mov al,54h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints T
	
	mov al,53h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints S
RET
error_msg endp

retry_msg proc
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Space
	
	mov al,52h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints R
	
	mov al,45h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints E
	
	mov al,54h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints T
	
	mov al,52h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints R
	
	mov al,59h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al  ;prints Y

ret
retry_msg endp	
	
clear_1digit_LCD proc
	mov al,00h
	out B1,al
	call DELAY_20ms
	mov al,10h			;shift left by 1 
	out A1,al
	call DELAY_20ms
	mov al,04h
	out B1,al
	call DELAY_20ms
	mov al,00h
	out B1,al  
	
	mov al,0A0h
	out A1,al
	call DELAY_20ms
	mov al,05h
	out B1,al
	call DELAY_20ms
	mov al,01h
	out B1,al 			;prints Space
	
	call DELAY_20ms
	mov al,10h			;shift left by 1 
	out A1,al
	call DELAY_20ms
	mov al,04h
	out B1,al
	call DELAY_20ms
	mov al,00h
	out B1,al  
	
RET
clear_1digit_LCD endp	

open_door proc
	call clear_LCD
	mov al,8ah
	out B2,al
	call DELAY_20ms
	mov al,0ah
	out B2,al
	
x31:in al, C2
	cmp al,0ffh
	jnz x31
	call DELAY_20ms
	call close_door		
ret
open_door endp

close_door proc
	mov al,03h
	out B2,al 
	mov bx,20
x_delay_max:
	call DELAY_max
	dec bx
	jnz x_delay_max	
ret
close_door endp			

;Master procedure	

intitiate_master_seq proc
			
		call clear_LCD	
		mov al,0feh
		out A2,al	;glow enter pass LED	  
		mov cx,16		;byte by byte pass enter
						;store the 16-bit entered pass after the hard coded pass word	
enter_16bit:		
		call keypad_input
		cmp al,7eh
		jz C_pressed
		cmp al,7bh
		jz AC_pressed
		cmp al,77h
		jz press_enter
		cmp al,0bbh
		jz do_nop    ;Invalid key pressed like M,O,A
		cmp al,0b7h
		jz do_nop
		cmp al,7dh
		jz do_nop
		mov [si],al		
		CALL Display_*
		inc si	
		dec cx
		jnz enter_16bit
		
last_key_master:
		call keypad_input
		cmp al,7eh
		jz C_pressed
		cmp al,7bh
		jz AC_pressed
		cmp al,77h
		jz press_enter
				
other_key:	CALL clear_LCD
		CALL press_enter_msg	;To display 'PRESS ENTER' on lcd
		call keypad_input
		cmp al,77h
		jz press_enter
		jnz other_key	
		
do_nop: nop
		jmp enter_16bit	
		
C_pressed:  
		call clear_1digit_LCD
		dec si
		inc cx
		jmp enter_16bit
		
AC_pressed: 
		CALL clear_LCD
		mov cx,16
		mov si,1eh  ;start of pass segment
		jmp enter_16bit
		
press_enter:
		CALL clear_LCD
		mov al,0ffh   ;Turn Off all LEDs
		out A2,al
		cmp cx,0
		jz cmp_pass
		jmp raise_alarm
		;glow retry/update led
		;byte by byte

day_pass:
		mov si,002Eh
		mov al,0fdh  
		out A2,al   ;Turn On Retry/Update LED
		
		call DELAY_max
		call DELAY_max
		call DELAY_max
		
		call clear_LCD
		mov cx,12
		
enter_12bit:		
		call keypad_input
		cmp al,7eh
		jz C_pressed_day_pass
		cmp al,0bbh
		jz do_nop_day_pass
		cmp al,0b7h
		jz do_nop_day_pass
		cmp al,7dh
		jz do_nop_day_pass
		cmp al,7bh
		jz AC_pressed_day_pass
		cmp al,77h
		jz press_enter_day
		mov [si],al		
		CALL Display_*
		inc si	
		dec cx
		jnz enter_12bit	
		
last_key_day:
		call keypad_input
		cmp al,7eh
		jz C_pressed_day_pass
		cmp al,7bh
		jz AC_pressed_day_pass
		cmp al,77h
		jz press_enter_day

other_key1:	CALL clear_LCD
		CALL press_enter_msg				;To display 'PRESS ENTER' on lcd
		call keypad_input
		cmp al,77h
		jz press_enter_day
		jnz other_key1
			
do_nop_day_pass:nop
		jmp enter_12bit	
		
C_pressed_day_pass: 
		call clear_1digit_LCD
		dec si
		inc cx
		jmp enter_12bit
		
AC_pressed_day_pass:
		CALL clear_LCD
		jmp day_pass
		
press_enter_day:
		CALL clear_LCD
		mov al,0ffh
		out A2,al   ; Shut down all LEDs
		cmp cx,0
		jnz err_msg
		mov al,0fbh
		out A2,al    ; Turn On Pwd Updated LED
		call DELAY_max
		call DELAY_max
		mov al,0ffh
		out A2,al
		jz end_69h
		
err_msg:
		call error_msg
		jmp day_pass
		
cmp_pass:
		cld
		mov si,0000h
		mov di,001Eh
		mov cx,17
		
x5:		mov al,[si]
		mov bl,[di]
		dec cx
		jz day_pass
		cmp al,bl
		jnz raise_alarm
		inc si
		inc di
		jmp x5
		
raise_alarm:
		mov dh,5h
		mov al,0fh
		out A2,al	
		mov ax,0abcdh
		
end_69h: ret	
			
intitiate_master_seq endp

;Alarm procedure

intitiate_alarm_seq proc 
	mov al,00eh
	out A2,al
	mov cx,14
	mov si,3ah	;store the 16-bit entered pass after the hard coded pass word	
	
enter_14bit:		
		call keypad_input
		cmp al,7eh
		jz C_pressed_alarm 
		cmp al,0bbh
		jz nop_alarm
		cmp al,0b7h
		jz nop_alarm
		cmp al,7dh
		jz nop_alarm
		cmp al,7bh
		jz AC_pressed_alarm
		cmp al,77h
		jz press_enter_alarm
		mov [si],al		
		CALL Display_*
		inc si	
		dec cx
		jnz enter_14bit	
		
last_key_alarm:
		call keypad_input
		cmp al,7eh
		jz C_pressed_alarm
		cmp al,7bh
		jz AC_pressed_alarm
		cmp al,77h
		jz press_enter_alarm
		
other_key2:	CALL clear_LCD
		CALL press_enter_msg	
		call keypad_input
		cmp al,77h
		jz press_enter_alarm
		jnz other_key2	
		
nop_alarm: nop
	  jmp enter_14bit	
	  
C_pressed_alarm:  
		call clear_1digit_LCD
		dec si
		inc cx
		jmp enter_14bit
		
AC_pressed_alarm: 
		call clear_LCD
		mov cx,14
		mov si,3ah  ;start of pass segment
		jmp enter_14bit
		
press_enter_alarm:
		CALL clear_LCD
		mov al,0fh
		out A2,al    ;Turn off LEDs
		cmp cx,0
		jz cmp_pass_alarm
		jnz x56
		
cmp_pass_alarm:
		cld
		mov si,10h
		mov di,3ah
		mov cx,14
		repe cmpsb
		cmp cx,00h
		jnz x56
		mov al,0ffh
		out A2,al
		add dh,1h
x56: 	ret	
	
intitiate_alarm_seq endp

;User procedure
intitiate_user_seq proc
		call clear_LCD
		mov dl,1  ;flag for checking two inputs		
		mov al,0feh
	    out A2,al
	   	mov cx,12
	    mov si,48h	;store the 16-bit entered pass after the hard coded pass word
		
enter_12bit_user:		
		call keypad_input
		cmp al,7eh
		jz C_pressed_user
		cmp al,7bh
		jz AC_pressed_user
		cmp al,0bbh
		jz nop_user
		cmp al,0b7h
		jz nop_user
		cmp al,7dh
		jz nop_user
		cmp al,77h
		jz press_enter_user
		mov [si],al		
		CALL Display_*
		inc si	
		dec cx
		jnz enter_12bit_user
		
last_key:
		call keypad_input
		cmp al,7eh
		jz C_pressed_user
		cmp al,7bh
		jz AC_pressed_user
		cmp al,77h
		jz press_enter_user     
		
other_key3:	CALL clear_LCD
		CALL press_enter_msg	;'PRESS ENTER' on lcd
		call keypad_input
		cmp al,77h
		jz press_enter_user
		jnz other_key3	
		
nop_user:
		nop
		jmp enter_12bit_user	
			
C_pressed_user:  
		call clear_1digit_LCD
		dec si
		inc cx
		jmp enter_12bit_user
		
AC_pressed_user: 
		call clear_LCD
		mov cx,12
		mov si,48h   ;start of pass segment
		jmp enter_12bit_user
		
press_enter_user:
		mov al,0ffh
		out A2,al
		cmp cx,0
		jz cmp_pass_user
		jnz wrong_pass
		
cmp_pass_user:
		cld
		mov si,2eh
		mov di,48h
		mov cx,12
		repe cmpsb
		cmp cx,00h
		jnz wrong_pass
		jz open_door_user
		
wrong_pass : 
		call clear_LCD
		mov si,48h
		mov cx,12
		cmp dl,0
		jz raise_alarm_user
		mov al,0fdh
		out A2,al
		call retry_msg
		call DELAY_max
		call DELAY_max
		call clear_LCD
		mov cx,12
		dec dl
		jmp enter_12bit_user
		
raise_alarm_user:
		mov dh,0
		mov al,0fh
		out A2,al
		mov ax,0abcdh
		jmp end_70h	
		
open_door_user:
		call open_door	
		
end_70h: ret	
	
intitiate_user_seq endp		
	
Nmi_24hrtimer:    
		call clear_LCD
		call clear_1digit_LCD
		call updateday_msg
startnmi:	

		call keypad_input
		cmp al,0bbh
		jz Master_mode
		jmp startnmi
		
 iret
 Switch_intR:
		call open_door
		sti
		cmp bp,0abcdh
		jz x6
		jmp start