;;;;;;;;;;;;;;;;;;;;;
;test program screen scroll
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
road_offset_from_edge	
	DEFB 0
roadCharacter
	DEFB 0
roadCharacterControl
	DEFB 0	

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

	ld a,9
	ld (road_offset_from_edge),a
	
	;; initialise the scroll from and too, 
	;; scroll from is the D_FILE+(cols*(rows-1)-1
	;; scroll to is the D_FILE + (cols*rows)-1     (= scroll from + 32)
	ld hl,(D_FILE) ;initialise road start memory address
	ld de, SCREEN_SCROLL_MEM_OFFSET
	add hl, de	
	ld (var_scroll_road_from), hl
	ld de, 21
	add hl, de
	ld (var_scroll_road_to), hl

	ld hl,(D_FILE) ;initialise road start memory address
	ld de, ROAD_SCREEN_MEM_OFFSET
	add hl, de	
	ld (var_road_left_addr),hl ; store initial road left pos at top left of screen

	ld a, 136
	ld b,24 ; for this debug version do half and alternate pattern to see scroll
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
	
principalloop


	;scroll road	
	ld hl,(var_scroll_road_from)  ; load left road address	
	ld de,(var_scroll_road_to) ; load right road address		
	ld bc,736					; 736 = 32columns * 23 rows
	; LDDR repeats the instruction LDD (Does a LD (DE),(HL) and decrements 
	; each of DE, HL, and BC) until BC=0. Note that if BC=0 before 
	; the start of the routine, it will try loop around until BC=0 again.	
	lddr

	;user input to move road left or right
	ld a, KEYBOARD_READ_PORT_SHIFT_TO_V			; read keyboard shift to v
	in a, (KEYBOARD_READ_PORT)						; read from io port	
	bit 2, a								; check bit set for key press right move "M"
	jr z, roadleft

	ld a, KEYBOARD_READ_PORT_SPACE_TO_B			; read keyboard shift to v
	in a, (KEYBOARD_READ_PORT)						; read from io port	
	bit 2, a
	jr z, roadright
	
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
	cp 15
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
	ld bc,$05ff ;max waiting time
waitloop
	dec bc
	ld a,b
	or c
	jr nz, waitloop
	jp principalloop
	
gameover
	ret     ; game and tutorial written by Jon Kingsman

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
