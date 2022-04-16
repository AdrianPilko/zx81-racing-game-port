;;;;;;;;;;;;;;;;;;;;;
;;; port of a racing game from zx spectrum code by Jon Kingsman 
;;; reworked for zx81 by Adrian Pilkington, and added title screen etc
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
#define CAR_SCREEN_MEM_START_OFFSET 772
#define ROADFROM_SCREEN_MEM_LOCATION 769
#define ROADTO_SCREEN_MEM_LOCATION 778
#define RANDOM_BYTES_MEM_LOCATION 2000
;((32*23)-1)
#define SCREEN_SCROLL_MEM_OFFSET 735


;D_FILE is location of screen memory (which moves depending on length of basic, but should be fixed after program is loaded
; probably should run some code to detect if this is 1K or 16K as well, or just have 2 verisons 1K and 16K
#define D_FILE 16396
;black block
#define CAR_CHARACTER_CODE 138  
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
#define KEYBOARD_READ_PORT_A_TO_G	$FD
; starting port numbner for keyboard, is same as first port for shift to v
#define KEYBOARD_READ_PORT $FE 

	jp intro_title

var_car_pos 
	DEFB 0,0
var_road_left_addr
	DEFB 0,0
var_road_pos
	DEFB 0,0
var_scroll_road_from
	DEFB 0,0
var_scroll_road_to
	DEFB 0,0
to_print_mem
	DEFB 0,0
road_offset_from_edge	
	DEFB 0
roadCharacter
	DEFB 0
roadCharacterControl
	DEFB 0	
crash_message_txt
	DEFB	_G,_A,_M,_E,__,_O,_V,_E,_R,$ff	
score_txt
	DEFB	_S,_C,_O,_R,_E,__,$ff
title_screen_txt
	DEFB	_Z,_X,_8,_1,__,_R,_A,_C,_I,_N,_G,__,__,__,__,__,__,$ff
keys_screen_txt
	DEFB	_S,__,_T,_O,__,_S,_T,_A,_R,_T,26,__,_Z,__,_L,_E,_F,_T,26,__,_M,__,_R,_I,_G,_H,_T,$ff
warning_message_line_1
	DEFB	_W,_A,_R,_N,_I,_N,_G,$ff			
warning_message_line_2
	DEFB	_C,_A,_R,__,_H,_A,_S,__,_A,__,_F,_A,_U,_L,_T,$ff
warning_message_line_3
	DEFB    _I,_T,__,_W,_I,_L,_L,__,_P,_U,_L,_L,__,_T,_O,__,_R,_I,_G,_H,_T,__,_A,_T,__,_S,_T,_A,_R,_T,$ff				
	
chequrered_flag		
	DEFB	6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,$ff		
test_str		
	DEFB	6,$ff			
score_mem
	DEFB 0,0	
speedUpLevelCounter	
	DEFB 0,0
		
to_print .equ to_print_mem ;use hprint16

;; note on the zx81 display 
; from previous crashes and experimenting with printing characters to the screen;; 
; and also some forums, it's clear that the zx81 has 32 column* 24 rows of printable/addressable
; screen area, but at the end of each row is is a chr$127, which if overritten
;; can cazuse unpredictable behavoir and system instabiltiy . It also menas calculating 
;; addresses/offsets to print to is not as straightforward as say c64
;; printing to very last column and row, is 32col * 24row + (24"end of lines" - 1)
;; printing to [row][col], use (row * 33) + col, 
;; (row is 0 to 23 for addressing purposes, and column 1 to 32)
;;
;; 1k is different to 16K, on 1K system saves space by putting "end of row markers" ch$127
;; on every line until there is something else on it. 16K preallocates whole display
;; 16K zx81 offsets from D_FILE
;; 1  = top row, first column 
;; 32 = top right, last column
;; 760 = bottom row, first column
;; 791 = bottom row, last column
	

hprint16  ; print one 2byte number stored in location $to_print
	ld hl,$to_print
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
	inc hl
	djnz hprint16_loop
	ret

introWaitLoop
	ld bc,$00ff ;max waiting time
introWaitLoop_1
	dec bc
	ld a,b
	or c
	jr nz, introWaitLoop_1
	jr read_start_key


intro_title
	call CLS
	ld bc,1
	ld de,chequrered_flag
	call printstring	
	ld bc,34
	ld de,chequrered_flag
	call printstring		
	ld bc,110
	ld de,title_screen_txt
	call printstring
	ld bc,202
	ld de,keys_screen_txt
	call printstring	
	ld bc,331
	ld de,warning_message_line_1
	call printstring	
	ld bc,364
	ld de,warning_message_line_2
	call printstring	
	ld bc,397
	ld de,warning_message_line_3
	call printstring	
	ld bc,727
	ld de,chequrered_flag
	call printstring		
	ld bc,760
	ld de,chequrered_flag
	call printstring	

read_start_key
	ld a, KEYBOARD_READ_PORT_A_TO_G	
	in a, (KEYBOARD_READ_PORT)					; read from io port	
	bit 1, a									; check S key pressed
	jr nz, introWaitLoop

main
	call CLS
	ld hl, 0						; initialise score to zero
	ld (score_mem),hl

	ld bc, $09ff					; set initial difficulty
	ld (speedUpLevelCounter), bc
	ld bc,0
	
	ld a,9
	ld (road_offset_from_edge),a
	
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
	ld (var_road_left_addr),hl ; store initial road left pos at top left of screen

	ld a, 136
	ld b,23 ; for this debug version do half and alternate pattern to see scroll
initialiseRoad  ;; was fillscreen in zx spectrum version, initialiseRoad is beter name of what it's doing!!
	
	ld (hl),a    ;; road starts as two staight vertical lines 
	inc hl   	 ;; make each edge of road 2 characters wide
	ld (hl),a   	
	ld de,WIDTH_OF_ROAD   
	add hl,de			  ;; add offset to get to other side of road	
	ld (hl),a				;; make each edge of road 2 characters wide
	inc hl					
	ld (hl),a
	ld de,22  ;; on zx spectrum had ld de,21, but end of line on zx81 has chr$128 needs skip
	add hl,de
	djnz initialiseRoad	
	
	ld a, 136
	ld (roadCharacter), a
	ld a, 2
	ld (roadCharacterControl), a

;initialise car	
	ld hl,(D_FILE) 
	ld de, CAR_SCREEN_MEM_START_OFFSET
	add hl, de	
	ld a,CAR_CHARACTER_CODE 
	ld (hl),a
	ld (var_car_pos),hl ;save car posn

principalloop
	ld hl,(var_car_pos)							; get car position
	
	;user input to move road left or right	
	ld a, KEYBOARD_READ_PORT_SHIFT_TO_V			; read keyboard shift to v
	in a, (KEYBOARD_READ_PORT)					; read from io port	
	bit 1, a									; check bit set for key press left  (Z)
	jr z, carleft								; jump to move car left
	ld a, KEYBOARD_READ_PORT_SPACE_TO_B			; read keyboard space to B
	in a, (KEYBOARD_READ_PORT)					; read from io port	
	bit 2, a									; check bit set for key press right (M)
	jr z, carright								; jump to move car right
	
	jr noCarMove								; dropped through to no move
	
carleft
	dec hl	
	jr noCarMove	
carright
	inc hl
noCarMove		
	ld (var_car_pos), hl		
	ld de, 32 
	xor a  ;set carry flag to 0
	sbc hl,de
	ld a,(hl)
	or a
	jp nz,gameover
	
	ld a, CAR_CHARACTER_CODE
	ld (hl),a
	
	
	;scroll road	
	ld hl,(var_scroll_road_from)  ; load left road address	
	ld de,(var_scroll_road_to) ; load right road address		
	ld bc,736					; 736 = 32columns * 23 rows
	; LDDR repeats the instruction LDD (Does a LD (DE),(HL) and decrements 
	; each of DE, HL, and BC) until BC=0. Note that if BC=0 before 
	; the start of the routine, it will try loop around until BC=0 again.	
	lddr
	
	; random number gen from https://spectrumcomputing.co.uk/forums/viewtopic.php?t=4571
    add hl,hl    
    sbc a,a      
    and %00101101 
    xor l         
    ld l,a       
    ld a,r       
    add a,h     
	
	and 1
	jr z, roadleft	
	
	jr roadright
	
	jr printNewRoad 

roadleft	
	; erase old road
	ld a, 0
	ld hl,(var_road_left_addr)
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,WIDTH_OF_ROAD
	add hl,de
	ld (hl),a
	inc hl
	ld (hl),a
	
; move road position to left
	ld hl,(var_road_left_addr)
	dec hl
	ld (var_road_left_addr), hl	
	ld a, (road_offset_from_edge)
	dec a 
	ld (road_offset_from_edge),a
	cp 0
	jp nz, printNewRoad   ; skip inc if it's not at edge otherwise inc 
	inc a
	ld (road_offset_from_edge),a
	inc hl
	ld (var_road_left_addr), hl

	jr printNewRoad
	
roadright
	; erase old road
	ld a, 0
	ld hl,(var_road_left_addr)
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,WIDTH_OF_ROAD
	add hl,de
	ld (hl),a
	inc hl
	ld (hl),a
	
	ld hl,(var_road_left_addr)
	inc hl
	ld (var_road_left_addr), hl		
	ld a, (road_offset_from_edge)
	inc a 
	ld (road_offset_from_edge),a
	cp 21
	jp nz, printNewRoad   ; skip inc if it's not at edge otherwise inc 

	dec a
	ld (road_offset_from_edge),a
	dec hl
	ld (var_road_left_addr), hl

printNewRoad

	ld hl,(var_road_left_addr)	
	ld a, (roadCharacter)	
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,WIDTH_OF_ROAD
	add hl,de
	ld (hl),a
	inc hl
	ld (hl),a

	;toggle road character to show if scrolling is working
	xor a  
	ld a,(roadCharacterControl)
	dec a
	ld (roadCharacterControl),a
	ld a, 136
	ld (roadCharacter), a
	jp nz, preWaitloop
	ld a, 4
	ld (roadCharacterControl), a
	ld a, 128
	ld (roadCharacter), a
	
preWaitloop
	ld hl,(score_mem)				; add one to score
	inc hl
	ld (score_mem),hl
	
	;;ld bc,$05ff 					;max waiting time
	ld hl, (speedUpLevelCounter)   ; makes it more difficult as you progress
	ld a, h
	cp $ff
	jr z, waitloop_set_min
	dec hl 
	ld a, h
	cp $ff
	jr z, waitloop_set_min	
	dec hl
	ld a, h
	cp $ff
	jr z, waitloop_set_min	
	dec hl
	ld (speedUpLevelCounter), hl
	ld bc, (speedUpLevelCounter)
	jr waitloop
waitloop_set_min
	ld hl, $00ff
	ld (speedUpLevelCounter), hl
	ld bc, (speedUpLevelCounter)
waitloop
	dec bc
	ld a,b
	or c
	jr nz, waitloop
	jp principalloop
	
gameover
	ld bc,10
	ld de,crash_message_txt
	call printstring
	ld hl, score_mem	; copy from score memory location to "print buffer"
	ld de, to_print		;
	ld bc, 2			; 2 bytes
	ldir				; copy 2 bytes from hl to de	
	call hprint16 		; print 

	ld hl, $ffff   ;; wait max time for 16bits then go back to intro
	ld (speedUpLevelCounter), hl
	ld bc, (speedUpLevelCounter)
waitloop_end_game
	dec bc
	ld a,b
	or c
	jr nz, waitloop_end_game
	jp intro_title
	
	;ret  ; never return to basic
	
	
	
; original game written by Jon Kingsman, for zx spectrum, ZX81 port/rework by Adrian Pilkington 


; this prints at top any offset (stored in bc) from the top of the screen D_FILE
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
