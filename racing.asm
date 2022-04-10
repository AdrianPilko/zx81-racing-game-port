;;;;;;;;;;;;;;;;;;;;;
;;; port of a racing game from zx spectrum code by Jon Kingsman by Adrian Pilkington
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
#define ROWS_IN_SCREEN 22
#define COL_IN_SCREEN 32
#define ROAD_SCREEN_MEM_OFFSET 9    
#define WIDTH_OF_ROAD 9
#define CAR_SCREEN_MEM_START_OFFSET 742
#define SCREEN_MEM_OFFSET_TO_LAST_ROW 736
#define ROADFROM_SCREEN_MEM_LOCATION 23263
#define ROADTO_SCREEN_MEM_LOCATION 23295
#define RANDOM_BYTES_MEM_LOCATION 14000

;D_FILE is location of screen memory (which moves depending on length of basic, but should be fixed after program is loaded
; probably should run some code to detect if this is 1K or 16K as well, or just have 2 verisons 1K and 16K
#define D_FILE 16396
;black block
#define CAR_CHARACTER_CODE 128  
;blank space
#define NOT_CAR_CHARACTER_CODE 0
;black grey block
#define ROAD_CHARACTER_CODE 136

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
var_last_row_addr
	DEFB 0,0
var_road_pos
	DEFB 0,0
var_scroll_road_from
	DEFB 0,0
var_scroll_road_to
	DEFB 0,0

hprint 		;;http://swensont.epizy.com/ZX81Assembly.pdf?i=1
	PUSH AF ;store the original value of A for later
	AND $F0 ; isolate the first digit
	RRA
	RRA
	RRA
	RRA
	ADD A,$1C ; add 28 to the character code
	CALL PRINT ;
	POP AF ; retrieve original value of A
	AND $0F ; isolate the second digit
	ADD A,$1C ; add 28 to the character code
	CALL PRINT
	LD A,_NL
	CALL PRINT ; print a space character
	RET


main
	call CLS	
	di
	
	ld hl, (D_FILE)		; detect crash with edge of road
	ld de, SCREEN_MEM_OFFSET_TO_LAST_ROW	
	add hl,de ; hl is now the address of last row of screen memory    
	ld (var_last_row_addr),hl    ; store last row

	
	ld hl,(D_FILE) ;initialise road start memory address
	ld de, ROAD_SCREEN_MEM_OFFSET
	add hl, de	
	push hl  ;save road posn
	xor a  ;???? possibly clears cpu flags?
	ld a, ROAD_CHARACTER_CODE
	ld b,ROWS_IN_SCREEN
	
initialiseRoad  ;; was fillscreen in zx spectrum version, initialiseRoad is beter name of what it's doing!!
	ld (hl),a    ;; road starts as two staight vertical lines 
	inc hl   	 ;; make each edge of road 2 characters wide
	ld (hl),a   
	ld de,WIDTH_OF_ROAD   
	add hl,de			  ;; add offset to get to other side of road
	ld (hl),a				;; make each edge of road 2 characters wide
	inc hl					
	ld (hl),a
	ld de,22  ;; on zx spectrum had ld de,21
	add hl,de
	djnz initialiseRoad

	ld b,ROWS_IN_SCREEN
	ld c,b  ;initialise score
	push bc  ;save score
	
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
	ld (var_car_pos),hl ; store new car pos	
		
	ld de, (var_last_row_addr)
	ld hl, (var_car_pos);load car pos to hl
	
	xor a  			;set carry flag to 0
	sbc hl,de		; get the offset from edge of screen (range 0 to 31)
	
	
	call hprint
	
	ld a,(hl) ;crash?
	or a
	jr z,gameover
	ld hl,(var_car_pos) ; get car pos	
	ld a,CAR_CHARACTER_CODE 
	ld (hl),a		
		
	
	jp preWaitloop		; cut next bit for debug to get car moving left right	
	
;jp gameover; return early for debug	
	ld hl,ROADFROM_SCREEN_MEM_LOCATION ;scroll road
	ld de,ROADTO_SCREEN_MEM_LOCATION 
	ld bc,736
	lddr
	pop bc  ;retrieve score
	pop hl  ;retrieve road posn
	push hl  ;save road posn
	ld a,56  ;delete old road
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,9
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
	pop hl  ;retrieve road posn
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
	push hl  ;save road posn
	xor a  ;print new road
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,9
	add hl,de
	ld (hl),a
	inc hl
	ld (hl),a
	inc bc  ;add 1 to score
	push bc  ;save score
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
	pop bc  ;retrieve score
	pop hl  ;empty stack
	ei
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
