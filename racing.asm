;;;;;;;;;;;;;;;;;;;;;
;;; port of a racing game from zx spectrum code by Jon Kingsman by Adrian Pilkington
;;; have added some bit like a message if/when you crash, and changed the collision detection
;;; which didn't appear to work on the zx81
;;;;;;;;;;;;;;;;;;;;;

#include "zx81defs.asm" ;; https://www.sinclairzxworld.com/viewtopic.php?t=2186&start=40
;EQUs for ROM routines
#include "zx81rom.asm"
;ZX81 char codes/how to survive without ASCII
#include "charcodes.asm"
;system variables
#include "zx81sys.asm"

;the standard REM statement that will contain our 'hex' code
#include "line1.asm"

; these variables need converting to screen addresses for zx81
; problem with zx81 is the screen display D_FILE memory address changes with size of basic program 
; see https://www.sinclairzxworld.com/viewtopic.php?t=3919
; (the asm here is converted to one line of basic)
#define ROWS_IN_SCREEN 24
#define COL_IN_SCREEN 32
#define ROAD_SCREEN_MEM_OFFSET 9    
#define WIDTH_OF_ROAD 9
#define CAR_SCREEN_MEM_START_OFFSET 773
;#define SCREEN_MEM_OFFSET_TO_LAST_ROW 736
#define ROADFROM_SCREEN_MEM_LOCATION 769
#define ROADTO_SCREEN_MEM_LOCATION 778
#define RANDOM_BYTES_MEM_LOCATION 2000
;((32*23)-1)
#define SCREEN_SCROLL_MEM_OFFSET 735


;D_FILE is location of screen memory (which moves depending on length of basic, but should be fixed after program is loaded
; probably should run some code to detect if this is 1K or 16K as well, or just have 2 verisons 1K and 16K
#define D_FILE 16396
;black block
#define CAR_CHARACTER_CODE 128  
;blank space
#define NOT_CAR_CHARACTER_CODE 0
;blank space
#define NOT_ROAD_CHARACTER_CODE 0
;black grey block
#define ROAD_CHARACTER_CODE 136
#define ROAD_START_MARKER_CHARACTER_CODE 138

#define GREY_SQAURE 8  

; keyboard port for shift key to v
#define KEYBOARD_READ_PORT_SHIFT_TO_V $FE
; keyboard space to b
#define KEYBOARD_READ_PORT_SPACE_TO_B $7F 
; starting port numbner for keyboard, is same as first port for shift to v
#define KEYBOARD_READ_PORT $FE 

	jp main

var_car_pos 
	DEFB 0,0
var_road_left_addr
	DEFB 0,0
var_road_right_addr
	DEFB 0,0	
var_road_pos
	DEFB 0,0
var_scroll_road_from
	DEFB 0,0
var_scroll_road_to
	DEFB 0,0
to_print_mem
	DEFB 0,0
	
crash_message_txt
		DEFB	_Y,_O,_U,__,_C,_R,_A,_S,_H,_E,_D,$ff
game_title_txt
		DEFB	__,__,_D,_E,_A,_T,_H,__,__,__,__,__,__,__,__,__,__,__,__,__,__,_R,_A,_C,_E,__,__,__,__,__,$ff
		
to_print .equ to_print_mem ;use hprint16
	

hprint16  ; print one 2byte number stored in location $to_print
	;ld hl,$to_print
	ld hl,$to_print+2
	ld b,2	
hprint16_loop	
	ld a, (hl)
	push af ;store the original value of a for later
	and $f0 ; isolate the first digit
	rra
	rra
	rra
	rra
	add a,$1c ; add 28 to the character code
	call PRINT ;
	pop af ; retrieve original value of a
	and $0f ; isolate the second digit
	add a,$1c ; add 28 to the character code
	call PRINT
	ld a, 00;_NL ;print new line ; 00 is space
	;call PRINT ; print a space character
	
	dec hl
	djnz hprint16_loop
	; restore registers
	ld a, _NL
	call PRINT
	ret


main
	call CLS	
	
	;ld bc,1
	;ld de,game_title_txt
	;call printGameBannerString
		
	;; initialise the scroll from and too, 
	;; scroll from is the D_FILE+(cols*(rows-1)-1
	;; scroll to is the D_FILE + (cols*rows)-1     (= scroll from + 32)
	ld hl,(D_FILE) ;initialise road start memory address
	ld de, SCREEN_SCROLL_MEM_OFFSET
	add hl, de	
	ld (var_scroll_road_from), hl
	ld de, 32
	add hl, de
	ld (var_scroll_road_to), hl

	ld hl,(D_FILE) ;initialise road start memory address
	ld de, ROAD_SCREEN_MEM_OFFSET
	add hl, de	
	xor a  ;???? possibly clears cpu flags?
	ld a, ROAD_CHARACTER_CODE
	ld b,ROWS_IN_SCREEN
	
initialiseRoad  ;; was fillscreen in zx spectrum version, initialiseRoad is beter name of what it's doing!!
	ld (hl),a    ;; road starts as two staight vertical lines 
	inc hl   	 ;; make each edge of road 2 characters wide
	ld (hl),a   	
	ld (var_road_left_addr),hl ; store road left pos (every time but on last iteration will be correct for last row	
	ld de,WIDTH_OF_ROAD   
	add hl,de			  ;; add offset to get to other side of road	
	ld (var_road_right_addr),hl ; store road right pos (every time but on last iteration will be correct for last row
	ld (hl),a				;; make each edge of road 2 characters wide
	inc hl					
	ld (hl),a
	ld de,22  ;; on zx spectrum had ld de,21
	add hl,de
	djnz initialiseRoad	

	ld b,ROWS_IN_SCREEN
	;ld c,b  ;initialise score
	;push bc  ;save score
	
	ld hl,(D_FILE) ;initialise car
	ld de, CAR_SCREEN_MEM_START_OFFSET
	add hl, de
	ld a,CAR_CHARACTER_CODE 
	ld (hl),a
	ld (var_car_pos),hl ;save car posn
	
principalloop
	ld hl,(var_car_pos)						;retrieve car posn
	ld a,NOT_CAR_CHARACTER_CODE  					;erase car
	ld (hl),a
	
	ld a, KEYBOARD_READ_PORT_SHIFT_TO_V			; read keyboard shift to v
	in a, (KEYBOARD_READ_PORT)						; read from io port	
	bit 2, a								; check bit set for key press right move "M"

	jr nz, moveright
	dec l

moveright
	ld a, KEYBOARD_READ_PORT_SPACE_TO_B			; read keyboard shift to v
	in a, (KEYBOARD_READ_PORT)						; read from io port	
	bit 2, a								; check bit set for key press right move "M"

	jr nz, dontmove	
	inc l
	
dontmove
	di
	ld (var_car_pos),hl ; store new car pos			
	ld de, 32 ;new carposn
	xor a  ;set carry flag to 0
	sbc hl,de
	ld a,(hl) ;crash?
	or a	
	jp z,gameover

	ei
	ld hl, (var_car_pos)
	ld a,CAR_CHARACTER_CODE 
	ld (hl),a	
		
	jp preWaitloop		; cut next bit for debug to get car moving left right	
	
	;scroll road	
	ld hl,(var_scroll_road_from)  ; load left road address	
	ld de,(var_scroll_road_to) ; load right road address		
	ld bc,736					; 736 = 32columns * 23 rows
	; LDDR repeats the instruction LDD (Does a LD (DE),(HL) and decrements 
	; each of DE, HL, and BC) until BC=0. Note that if BC=0 before 
	; the start of the routine, it will try loop around until BC=0 again.	
	lddr	
	
	;pop bc  ;retrieve score
	ld hl,(var_road_left_addr) ; get road position
	ld a,NOT_ROAD_CHARACTER_CODE  ;delete old road
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,WIDTH_OF_ROAD 
	add hl,de
	ld (hl),a
	inc hl
	ld (hl),a

	
	;random road left or right
	ld hl,RANDOM_BYTES_MEM_LOCATION ;source of random bytes in ROM
	ld d,0
	ld e,c
	add hl, de
	ld a,(hl)
	ld (var_road_left_addr),hl
	dec hl  ;move road posn 1 left
	and 1
	jr z, roadleft
	inc hl
	inc hl

roadleft
	ld a,l  ;check left
	cp 255
	jr nz, checkright
	inc hl
	inc hl
checkright
	ld a,l
	cp 21
	jr nz, newroadposn
	dec hl
	dec hl
newroadposn
	;ld (var_road_left_addr),hl
	xor a  ;print new road
	ld a, ROAD_CHARACTER_CODE
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,WIDTH_OF_ROAD
	add hl,de
	ld (hl),a
	inc hl
	ld (hl),a
	;inc bc  ;add 1 to score
	;push bc  ;save score
	;wait routine		
preWaitloop	
	ld bc,$05ff ;max waiting time
waitloop
	dec bc
	ld a,b
	or c
	jr nz, waitloop
	jp principalloop
gameover
	ld bc,1
	ld de,crash_message_txt
	call printstring
	pop bc  ;retrieve score
	pop hl  ;empty stack

	ret     ; game and tutorial written by Jon Kingsman

fill_screen_with_char    ; adapted from http://swensont.epizy.com/ZX81Assembly.pdf screen1
	ld hl,(D_FILE) ; Get start of display
	ld c,22 ; line counter (22 lines)
loop1
	inc hl ; get past EOL
	ld b,32 ; character counter (32 rows)
loop2 
	ld (HL),GREY_SQAURE ; print grey square character
	inc hl ; move to next print position
	djnz loop2 ; Do it again until B=0
	dec c ; next line
	jr nz,loop1
	ret 

print_to_screen_at    ; adapted from http://swensont.epizy.com/ZX81Assembly.pdf screen1
	ld hl,(D_FILE) ; Get start of display
	ld c,22 ; line counter (22 lines)
Ploop1
	inc hl ; get past EOL
	ld b,32 ; character counter (32 rows)
Ploop2 
	ld (HL),$08 ; print grey square character
	inc hl ; move to next print position
	djnz Ploop2 ; Do it again until B=0
	dec c ; next line
	jr nz,Ploop1
	ret 	

	

printstring
	ld hl,(D_FILE)
	add hl,bc	
printstring_loop
	ld a,(de)
	cp $ff
	jp z,printstring_end
	ld (hl),a
	inc hl
	inc de
	jr printstring_loop
printstring_end	
	ret

printGameBannerString
	ld hl,(D_FILE)
	add hl,bc	
printGameBannerString_loop
	ld a,(de)
	cp $ff
	jp z,printGameBannerString_end
	ld (hl),a
	inc hl
	inc de
	jr printGameBannerString_loop
printGameBannerString_end	
	ret
	
;include our variables
#include "vars.asm"

; ===========================================================
; code ends
; ===========================================================
;end the REM line and put in the RAND USR line to call our 'hex code'
#include "line2.asm"

;display file defintion
#include "screen.asm"               

;close out the basic program
#include "endbasic.asm"
