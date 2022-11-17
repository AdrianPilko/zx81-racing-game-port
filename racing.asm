;;;;;;;;;;;;;;;;;;;;;
;;; port of a racing game from zx spectrum code by Jon Kingsman 
;;; https://worldofspectrum.org/forums/discussion/27207/redirect/p1
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
#define CAR_SCREEN_MEM_START_OFFSET 709
#define ROADFROM_SCREEN_MEM_LOCATION 769
#define RANDOM_BYTES_MEM_LOCATION 2000
;((32*23)-1)
#define SCREEN_SCROLL_MEM_OFFSET 693


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
#define KEYBOARD_READ_PORT_A_TO_G	$FD
; starting port numbner for keyboard, is same as first port for shift to v
#define KEYBOARD_READ_PORT $FE 

	jp setHighScoreZero

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
title_screen_txt
	DEFB	_Z,_X,_8,_1,__,_R,_A,_C,_I,_N,_G,__,__,__,__,__,__,$ff
keys_screen_txt
	DEFB	_S,__,_T,_O,__,_S,_T,_A,_R,_T,26,__,_Z,__,_L,_E,_F,_T,26,__,_M,__,_R,_I,_G,_H,_T,$ff
keys_screen_txt_2
	DEFB	$10,_O,_R,__,_J,_O,_Y,_S,_T,_I,_C,_K,__,_P,_R,_E,_S,_S,__,_F,_I,_R,_E,$11,$ff    
using_joystick_string
	DEFB	$10,_J,_O,_Y,_S,_T,_I,_C,_K,__,_S,_E,_T,$11,$ff        
not_using_joystick_string
	DEFB	__,__,__,__,__,__,__,__,__,__,__,__,__,__,$ff        
last_Score_txt
	DEFB	21,21,21,21,_L,_A,_S,_T,__,__,_S,_C,_O,_R,_E,21,21,21,21,$ff	
high_Score_txt
	DEFB	21,21,21,21,_H,_I,_G,_H,__,__,_S,_C,_O,_R,_E,21,21,21,21,$ff		
chequrered_flag		
	DEFB	6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,$ff		
test_str		
	DEFB	6,$ff			
score_mem_tens
	DEFB 0
score_mem_hund
	DEFB 0
score_mem_thou
	DEFB 0
high_score_mem_tens
	DEFB 0
high_score_mem_hund
	DEFB 0		
last_score_mem_tens
	DEFB 0
last_score_mem_hund
	DEFB 0			
speedUpLevelCounter	
	DEFB 0,0
initialCarLeftCountDown
	DEFB 0,0
credits_and_version_1	
	DEFB _Z,_X,__,_S,_P,_E,_C,_T,_R,_U,_M,__,_C,_O,_D,_E,__,_B,_Y,__,_J,__,_K,_I,_N,_G,_S,_M,_A,_N,$ff
credits_and_version_2
	DEFB _P,_O,_R,_T,_E,_D,__,_T,_O,__,_Z,_X,36,29,__,_B,_Y,__,_A,__,_P,_I,_L,_K,_I,_N,_G,_T,_O,_N,$ff
var_keys_or_joystick
	DEFB 0	
to_print .equ to_print_mem ;use printByte16

;; note on the zx81 display 
; from previous crashes and experimenting with printing characters to the screen;; 
; and also some forums, it's clear that the zx81 has 32 column* 24 rows of printable/addressable
; screen area, but at the end of each row is is a chr$127, which if overritten
;; can cause unpredictable behavoir and system instabiltiy . It also menas calculating 
;; addresses/offsets to print to is not as straightforward as say c64
;; printing to very last column and row, is 32col * 24row + (24"end of lines" - 1)
;; printing to [row][col], use (row * 33) + col, 
;; (row is 0 to 23 for addressing purposes, and column 1 to 32)
;;
;; 1k is different to 16K, on 1K system saves space by putting "end of row markers" chr$127
;; on every line until there is something else on it. 16K preallocates whole display
;; 16K zx81 offsets from D_FILE
;; 1  = top row, first column 
;; 32 = top right, last column
;; 760 = bottom row, first column
;; 791 = bottom row, last column
	
;set b to row, c to col	
printByte 		;;http://swensont.epizy.com/ZX81Assembly.pdf?i=1
	PUSH AF ;store the original value of A for later
	
	CALL PRINTAT ;
	POP AF 
	PUSH AF ;store the original value of A for later
	AND $F0 ; isolate the first digit
	RRA
	RRA
	RRA
	RRA
	ADD A,$1C ; add 28 to the character code
	CALL PRINT
	POP AF ; retrieve original value of A
	AND $0F ; isolate the second digit
	ADD A,$1C ; add 28 to the character code
	CALL PRINT
	RET

introWaitLoop
	ld bc,$00ff ;max waiting time
introWaitLoop_1
	dec bc
	ld a,b
	or c
	jr nz, introWaitLoop_1
	jp read_start_key
	
	
setHighScoreZero
	xor a
	ld (high_score_mem_tens), a
	ld (high_score_mem_hund), a
	ld (last_score_mem_tens), a
	ld (last_score_mem_hund), a	
	
	
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
    
    ld bc,236
	ld de,keys_screen_txt_2
    call printstring
	;ld bc,337
	;ld de,high_Score_txt
	;call printstring	
	;ld b, 11			; b is row to print in
	;ld c, 13			; c is column
    ;ld a, (high_score_mem_hund) ; load hundreds
	;call printByte    
	;ld b, 11			; b is row to print in
	;ld c, 15			; c is column
	;ld a, (high_score_mem_tens) ; load tens		
	;call printByte	
	ld bc,436
	ld de,last_Score_txt
	call printstring	
	ld b, 14			; b is row to print in
	ld c, 13			; c is column
    ld a, (last_score_mem_hund) ; load hundreds
	call printByte    
	ld b, 14			; b is row to print in
	ld c, 15			; c is column
	ld a, (last_score_mem_tens) ; load tens		
	call printByte	

	ld bc,530	
	ld de,credits_and_version_1
	call printstring		
	ld bc,563	
	ld de,credits_and_version_2
	call printstring		
	
	ld bc,727
	ld de,chequrered_flag
	call printstring		
	ld bc,760
	ld de,chequrered_flag
	call printstring	
    ld c, $1f
    xor a
    out (c),a
    ld a, 1 
    ld (var_keys_or_joystick), a    

read_start_key
    ; read fire button to start , works on real zx81 but not on EightyOne emulator
    ; comment out for version on github until work out a way of stopping EightyOne
    ; always returning bit set
	ld a, KEYBOARD_READ_PORT_A_TO_G	
	in a, (KEYBOARD_READ_PORT)					; read from io port	
	bit 3, a									; check  key pressed
    jp nz, carryOnCheckingStart
    
    xor a
    ld (var_keys_or_joystick), a    ; zero the flag for using joystick, so use keys
    ld bc,298
	ld de,using_joystick_string
    call printstring    
    
    
carryOnCheckingStart 
    ld a, (var_keys_or_joystick)    ; keys = 1
    and 1
    jp nz, dont_check_fire_button
    
    ld b, 00010000b   ; 16 decimal, fire button
    in a,($1F)       ; a now has the input byte from the port 1f (which is the joystick port)
    and b 
    jp nz, main
    
dont_check_fire_button    
    ld bc,298
	ld de,not_using_joystick_string
    call printstring    
    
	ld a, KEYBOARD_READ_PORT_A_TO_G	
	in a, (KEYBOARD_READ_PORT)					; read from io port	
	bit 1, a									; check S key pressed
    jp nz, introWaitLoop
    ; this means that they pressed  s to start so only use keys
    ld a, 1
    ld (var_keys_or_joystick), a   ; keys = 1
main
	call CLS
	ld a, 7
	ld (initialCarLeftCountDown),a
	
	xor a 						; initialise score to zero, and 0 results in a equal to zero
	ld (score_mem_tens),a	
	ld (score_mem_hund),a
	ld (score_mem_thou),a	

	ld bc, $03ff					; set initial difficulty
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
	ld de, 33
	add hl, de
	ld (var_scroll_road_to), hl

	ld hl,(D_FILE) ;initialise road start memory address
	ld de, ROAD_SCREEN_MEM_OFFSET
	add hl, de	
	ld (var_road_left_addr),hl ; store initial road left pos at top left of screen

	ld a, 136	; initial road character, grey block at start
	ld b, 22    ; number of rows to initialise 
initialiseRoad  ; was fillscreen in zx spectrum version, initialiseRoad is beter name of what it's doing!!
	
	ld (hl),a    			; road starts as two staight vertical lines 
	inc hl   	 			; make each edge of road 2 characters wide
	ld (hl),a   	
	ld de,WIDTH_OF_ROAD   
	add hl,de			  	;add offset to get to other side of road	
	ld (hl),a				; make each edge of road 2 characters wide
	inc hl					
	ld (hl),a
	ld de,22  				; on zx spectrum had ld de,21, but end of line on zx81 has chr$128 needs skip
	add hl,de
	djnz initialiseRoad	
	
	ld a, 136
	ld (roadCharacter), a
	ld a, 2
	ld (roadCharacterControl), a

	;;;;;;;;;;;;;;;initialise car	
	ld hl,(D_FILE) 
	ld de, CAR_SCREEN_MEM_START_OFFSET
	add hl, de	
	ld a,CAR_CHARACTER_CODE 
	ld (hl),a
	ld (var_car_pos),hl ;save car posn

principalloop


; adding code to optionally use joystick interface, 
; some code from https://sinclairzxworld.com/viewtopic.php?t=3265, made into youtube video https://www.youtube.com/watch?v=9MAbO6oDE_0&t=77s (by ByteForever)
; IN A,(1F)
; LD C,A
; LD B,0
; RET
; This was done inline REM basic at line 1, then calls with USR 16514, and decodes the result using 1=right, 2= right, 4=up, 8=down, 16=fire
; here we only need left and right, and also we don't need most of the assembler code "ld c,a" onwards as this just setup the return result into bc
; we just need in a,(1f) and the decode for left right so should be super fast


	ld hl, (var_car_pos)						; load car position into hl

    ld a, (var_keys_or_joystick)    ; keys = 1
    and 1
    jp nz, use_keys_only
    
    ; this works if the joystick is plugged in, and if not then the keys still work, ace :)
    ld b, 00000001b   ; 1 , joystick right
    in a,($1F)       ; a now has the input byte from the port 1f (which is the joystick port)
    ld c, a
    and b 
    jp nz, carright
    ld a, c
    ld b, 00000010b   ; 2 decimal, joystick left
    and b
    jp nz, carleft   
    
use_keys_only
	;user input to move road left or right	
	ld a, KEYBOARD_READ_PORT_SHIFT_TO_V			; read keyboard shift to v
	in a, (KEYBOARD_READ_PORT)					; read from io port	
	bit 1, a
	; check bit set for key press left  (Z)
	jp z, carleft								; jump to move car left
	ld a, KEYBOARD_READ_PORT_SPACE_TO_B			; read keyboard space to B
	in a, (KEYBOARD_READ_PORT)					; read from io port		
	bit 2, a									; check bit set for key press right (M)
	jr z, carright								; jump to move car right	
	jp noCarMove								; dropped through to no move
carleft
	dec hl	
	jp noCarMove	
carright
	inc hl
noCarMove		
	ld (var_car_pos), hl		
	xor a  ;set carry flag to 0
	ld de, 32 
	sbc hl,de
	ld a,(hl)
	or a
	jp nz,gameover
	
	ld a, CAR_CHARACTER_CODE
	ld (hl),a
	
	
	;scroll road	
	ld hl,(var_scroll_road_from)  ; load left road address	
	ld de,(var_scroll_road_to) ; load right road address		
	ld bc,694 ;736 = 32columns * 23 rows
	; LDDR repeats the instruction LDD (Does a LD (DE),(HL) and decrements 
	; each of DE, HL, and BC) until BC=0. Note that if BC=0 before 
	; the start of the routine, it will try loop around until BC=0 again.	
	lddr
	
	; random number gen from https://spectrumcomputing.co.uk/forums/viewtopic.php?t=4571
	ld hl, (score_mem_tens)
    add hl,hl    	
	dec hl
    sbc a,a      
    and %10101001 
    xor l         
    ld l,a       
    ld a,r       
    add a,h     	
	and 1
	jp z, roadleft	
	jp roadright

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
	jp printNewRoad
	
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

	;toggle road character to show give more impression of movement
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
	ld a,(score_mem_tens)				; add one to score, scoring is binary coded decimal (BCD)
	add a,1	
	daa									; z80 daa instruction realigns for BCD after add or subtract
	ld (score_mem_tens),a	
	cp 153
	jr z, addOneToHund
	jr skipAddHund
addOneToHund
	ld a, 0
	ld (score_mem_tens), a
    ld a, (score_mem_hund)
	add a, 1
	daa
	ld (score_mem_hund), a
skipAddHund	

printScoreInGame
	ld b, 21			; b is row to print in
	ld c, 1			; c is column
    ld a, (score_mem_hund) ; load hundreds
	call printByte    
	ld b, 21			; b is row to print in
	ld c, 3			; c is column
	ld a, (score_mem_tens) ; load tens		
	call printByte

	ld bc, (speedUpLevelCounter)
	ld hl, (speedUpLevelCounter)   ; makes it more difficult as you progress
	ld a, h
	cp 0
	jr z, waitloop
	dec hl 
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
	; copy the current score to high score, need to check it is higher!!
	
	ld a, (score_mem_tens) ; load tens		
	ld (last_score_mem_tens),a 
	ld a, (score_mem_hund) ; load tens		
	ld (last_score_mem_hund),a	



	ld bc, $ffff   ;; wait max time for 16bits then go back to intro	
waitloop_end_game
	dec bc
	ld a,b
	or c
	jp nz, waitloop_end_game
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
