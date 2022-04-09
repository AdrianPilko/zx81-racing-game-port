;; zx81 -fibonacci 

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

#define ROAD_SCREEN_MEM_LOCATION 22537    
#define CAR_SCREEN_MEM_LOCATION 23278
#define ROADFROM_SCREEN_MEM_LOCATION 23263
#define ROADTO_SCREEN_MEM_LOCATION 23295
#define RANDOM_BYTES_MEM_LOCATION 14000
;D_FILE is location of screen memory (which moves depending on length of basic, but should be fixed after program is loaded
#define D_FILE 16396

; keyboard caps to v
#define KEYBOARD_READ_MEMORY_LOCATION_CAPV 65278
; keyboard space to b
#define KEYBOARD_READ_MEMORY_LOCATION_SPACEB 32766

	jp main
var_car_pos  ; was 32900 in zx spec version
	DEFB 0,0
var_road_pos
	DEFB 0,0
var_scroll_road_from
	DEFB 0,0
var_scroll_road_to
	DEFB 0,0

main
	
	di
	ld hl, ROAD_SCREEN_MEM_LOCATION ;initialise road
	push hl  ;save road posn
	xor a
	ld b,24
fillscreen
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,9
	add hl,de
	ld (hl),a
	inc hl
	ld (hl),a
	ld de,21
	add hl,de
	djnz fillscreen
	ld c,b  ;initialise score
	push bc  ;save score
	ld hl,CAR_SCREEN_MEM_LOCATION ;initialise car
	ld a,8
	ld (hl),a
	ld (var_car_pos),hl ;save car posn
principalloop
	ld hl,(var_car_pos) ;retrieve car posn
	ld a,56  ;erase car
	ld (hl),a
	ei
	ld bc,KEYBOARD_READ_MEMORY_LOCATION_CAPV ;read keyboard caps to v
	in a,(c)
	cp 191
	jr nz, moveright
	inc l
moveright
	ld bc,KEYBOARD_READ_MEMORY_LOCATION_SPACEB ;read keyboard space to b
	in a,(c)
	cp 191
	jr nz, dontmove
	dec l
dontmove
	di
	ld (var_car_pos),hl ;store car posn
	ld de, 32 ;new carposn
	xor a  ;set carry flag to 0
	sbc hl,de
	ld a,(hl) ;crash?
	or a
	jr z,gameover
	ld a,8  ;print car
	ld (hl),a
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
	ld bc,$1fff ;max waiting time
wait
	dec bc
	ld a,b
	or c
	jr nz, wait
	jp principalloop
gameover
	pop bc  ;retrieve score
	pop hl  ;empty stack
	ei
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
