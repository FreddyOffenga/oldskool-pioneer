; Oldskool Pioneer
; 16K Atari 8-bit intro for Silly Venture 2k17
; Gfx mode: IVOP, Gfx conversion: FRS
; Msx: MIKER, Design/Code: F#READY
; Original images by Helios
; (actually, they were ripped from an animated gif)

; A tribute to Eadweard Muybridge (pseudo: Helios)
; On 15 June 1878, Muybridge set up a line of cameras with tripwires,
; each of which would trigger a picture for a split second as the horse ran past.
; The first motion picture was born!

; 'Horse in motion' - Sallie Gardner at a Gallop
; Photographs from Eadweard Muybridge, 1878

; GR.15 version

; DONE - Exomizer version is now: 12K
; - DL generator for vertical spinning animation
; - image conversion 80 width instead of 160
; - OS/IRQ off, own NMI handler
; - add scrolling fx
; - ivop mode in DLI
; - put the horse in centre, might need to recalculate the image?
; - fx player
; - move code under ROM $c000-$cfff
; - use new version image FRS
; - try to cover part of image with pm
; - view horse in fx2 instead of main loop
; - generate 2nd half of DL, which is the inverse of the first
; - init screen blank
; - credits added in top scroller
; - cinema fx after intro
; - open curtain transition
; - vertical align image using image_offset (generating empty dma lines)
; - impove transition to vertical movement

; compression results
; g15 : 31800 (original)
; exo :  ???? (horizontal concat, background removed)

; 32416 horse_gr15_v1.xex
; 11436 horse_gr15_v1_exo.xex
; 20980 less
; 
; 32514 horse_gr15_v2.xex
; 11179 horse_gr15_v2_exo.xex
; 21335 less, = 355 bytes saved by EOR $aa,$ff trick

; single frame : 
; 80 x 106, 4-pixels per byte : 2120 bytes

; data file structure: 
; 15 images wide = 15 x 80 pixels, 15 x 20 bytes 
; = 300 bytes / scanline

; target memory layout
; 15 images wide + 160 pixel screen buffer (to allow rotating buffer)
; 15 images wide = 15 x 80 pixels, 15 x 20 bytes
; = 300 bytes, plus 40 bytes screen buffer = 340 bytes

; boundary at 4096
; 12 x 340 = 4080
; 4096 - 4080 = 16 bytes (alignment bytes after 12 copied scanlines)

; extra memory for image
; 106 x 40 = 4240
; 16 x 9 (106/12) = 144
; 4240 + 144 = 4384 buffer space

; stepnr 15,16 = $4c lines
; 2 x $4c = $98 = 152 (19 char.lines!)
; 152 - 106 = 46

SCREEN_BUFFER_SPACE = 4384

HORSE_MODE	=	$4e		; mode 15 with dma

horse_screen_start	= $1000
horse_dataline_size = 300
HORSE_LINE_COUNT    = 106
HORSE_DOUBLE_SCAN   = HORSE_LINE_COUNT / 2
GEN_DL_DMA_LINES	= HORSE_LINE_COUNT+46		;+2
DL_HOOK_OFFSET		= (HORSE_LINE_COUNT+8)*3
LINES_IN_4K         = 12
ALIGNMENT_4K        = 16	; alignment bytes
STEP_TABLE_SIZE     = 31

; intro fx
PM_TOP_MARGIN		= 40

; Hardware/O.S. labels

		icl 'hardware_labels.asm'

; Zero page

; RMT ZeroPage addresses run from $CB (203) to $CB+19
; Exomizer uses $f0 - $f8, $400 for unpacker!
		
		org $80
tmp_src				.ds 2
tmp_tar				.ds 2
tmp_size			.ds 2
tmp_base_tar		.ds 2
horse_line_number	.ds 1
pm_src				.ds 2
pm_tar				.ds 2
tmp_index			.ds 1
pm_height			.ds 1
pm_char_index		.ds 1
pm_upper_offset		.ds 1
dli_x_count			.ds 1

line_number			.ds 2
step_size			.ds 2
scroll_offset		.ds 2
music_play_on		.ds 1
horse_animation_on	.ds 1
shadow_hpos0		.ds 1
shadow_hpos1		.ds 1

; fx globals
used_double_upper	.ds 1
used_double_lower	.ds 1
used_double_lines	.ds 1
upper_flip			.ds 1
fx_seq_index		.ds 1
fx_seq_value		.ds 1
fx_status			.ds 1
fx_jiffy_count		.ds 2
fx_param1			.ds 1
fx_param2			.ds 1
fx_info_pointer		.ds 2
fx_running_pointer	.ds 2

; fx vars can be re-used for diffent fx routines
fx1_pmsize_index	.ds 1
fx1_fade_in			.ds 1
horse_delay			.ds 1	; initial delay
horse_move_delay	.ds 1	; move delay, starts from horse_delay until 0
horse_scroll_speed	.ds 1
side_color_index	.ds 1
info_vscrol			.ds 1
info_delay			.ds 1
saved_hook			.ds 2
fx4_init_delay		.ds 1	; initial delay for fx4
fx4_cinema_delay	.ds 1	; down counting delay
fx4_cinema_color	.ds 1	; current color
curtain_pos1		.ds 1
curtain_pos2		.ds 1	
fx3_rotation_count	.ds 1

; memory map

VDSLST		= $0200
OSFONT		= $e000
font		= $0c00		; copied font

pm_area  	= $e000
msl_area	= pm_area+$180
pm0_area	= pm_area+$200
pm1_area	= pm_area+$280
pm2_area	= pm_area+$300
pm3_area	= pm_area+$380

horse_dma_lo	= $e400				; 1 page is enough
;		.ds HORSE_LINE_COUNT+2		
horse_dma_hi	= $e500				; 1 page is enough
;		.ds HORSE_LINE_COUNT+2

CODE_SOURCE	= $4000
CODE_TARGET = $c000
CODE_PAGES	= 16		; 16 x 256 bytes
		
; lookup table for HORSE_LINE_COUNT dma lines
		
		org $600
		
screen_off
		lda #0
		sta SDMCTL
		lda #1
		sta $220
wait_blank
		lda $220
		bne wait_blank
		rts
		
		ini screen_off

		org CODE_TARGET, CODE_SOURCE
		
; must be within 1k boundary	
horse_dl
		dta 112
		dta 112+128		; dli_header
		dta $46
		dta a(header_text)
		dta $42+32
dl_info_text
		dta a(info_text)
		dta 2
		
		dta 0,0,0

		dta 128			; horse DLI
		dta 0

; horse image dl is generated here
gen_dl
dl_hook		= *+DL_HOOK_OFFSET
;		.ds GEN_DL_DMA_LINES*3		; $4f, dma lo/hi
:GEN_DL_DMA_LINES*3		dta 0
	
footer_dl
		dta 112+128		; dli_footer
		dta $46
		dta a(footer_text)
		
		dta $41
		dta a(horse_dl)

piano_roll_dl
		dta 0,0,48,128
		dta 112
		dta 112
		dta 112
		dta 48,0,0

; space for piano
		dta $01
		dta a(footer_dl)

; text stuff

header_text
		dta d'  OLDSKOOL PIONEER  '
footer_text
		dta d' SILLY VENTURE 2K17 '

; to have all dma lines in place, but these show a blank line
; 40 bytes
dummy_line
		dta $00,$00,$00,00
		dta $00,$00,$00,00
		dta $00,$00,$00,00
		dta $00,$00,$00,00
		dta $00,$00,$00,00

		dta $00,$00,$00,00
		dta $00,$00,$00,00
		dta $00,$00,$00,00
		dta $00,$00,$00,00
		dta $00,$00,$00,00
				
; real code here :)

horse_code
		jsr init_fx_player
		
		jsr clean_gen_dl
		
; inits used_double_upper, used_double_lower
		lda #0
		sta stepnr
		sta info_vscrol
		lda #1
		sta info_delay

		lda #<10
		sta scroll_offset
		lda #>10
		sta scroll_offset+1
		
;		jsr show_horse
		
		jsr step_copy_lines

		jsr sync_start

		lda #0
		jsr fill_pm_area
		
		lda #>pm_area
		sta PMBASE
		lda #>font
		sta CHBASE
		
; init. global vars
		lda #0
		sta music_play_on		; music is off
		sta horse_animation_on	; horse animtion is off
		
; own NMI handler
        MVA #<NMI_handler NMIVKT
        MVA #>NMI_handler NMIVKT+1
		
; pm settings for intro
		lda #$0E	;$2E		; size 40, pm dma on, double line
		sta DMACTL
		
		lda #3		;0
		sta GRACTL
		
		lda #1		;1
		sta PRIOR

		lda #0
		sta COLPF0

; this can be done during 1,2,3 horse, but must be done _before_ horse animation!
		jsr prepare_images
		
		MVA #%11000000 NMIEN	;$C0
		
; main loop is not used...
blob	jmp blob

NMI_handler
	    bit NMIST
        bpl VBI_handler
        jmp (VDSLST)
         	
VBI_handler
		pha
		txa
		pha
		tya
		pha

		lda #<horse_dl
		sta DLISTL
		lda #>horse_dl
		sta DLISTH
			
		lda #<dli_header
		sta VDSLST
		lda #>dli_header
		sta VDSLST+1

		jsr fx_player

		lda horse_animation_on
		beq horse_off
; DEBUG
;		lda #$24
;		sta COLBK
				
		jsr show_horse

; DEBUG		
;		lda #0
;		sta COLBK

horse_off
		lda music_play_on
		beq exit_vbi
		
		jsr rmt_play		; play main musix!
		
; DEBUG	
;		lda #6
;		sta COLBK
		
exit_vbi
		pla
		tay
		pla
		tax
		pla
		rti
		
dli_header
		pha
		txa
		pha
		tya
		pha
		
		ldx #7
colbar_header
		lda header_colors,x
		sta WSYNC
		sta COLPF0
		dex
		bpl colbar_header

		lda #<dli0
		sta VDSLST
		lda #>dli0
		sta VDSLST+1
		
		lda #8
		sta COLPF1

		pla
		tay
		pla
		tax
		pla
		rti
		
header_colors
		dta $c4,$c6,$c8,$ca
		dta $ca,$c8,$c6,$c4

dli0
		pha
		txa		
		pha
		tya
		pha
		
		lda #$ff
		sta GRAFP0
		sta GRAFP1
		sta GRAFP2
		sta GRAFP3
		sta GRAFM
		
; ------ UPPER DLI ------
		ldx used_double_upper
		sta WSYNC
		
eat_cpu_cycles
		lda #0	;$a6
		sta WSYNC
		
		sta COLBK

UPPER_C2	= *+1		
		lda #8			; 8
		sta COLPF0
UPPER_C3	= *+1
		lda #12			; 12
		sta COLPF1
UPPER_C0	= *+1		
		lda #0			; 0
		sta COLPF2
UPPER_C1	= *+1		
		lda #$04		; 4
		sta COLBK
		
		lda #0	;$a6
		sta WSYNC
		
		sta COLBK

UPPER_C4	= *+1				
		lda #2			; 2
		sta COLPF0
UPPER_C5	= *+1				
		lda #6			; 6
		sta COLPF1
UPPER_C7	= *+1				
		lda #14			; 14
		sta COLPF2
UPPER_C6	= *+1				
		lda #$0a		; 10
		sta COLBK
		
		dex
		bne eat_cpu_cycles

; ------ LOWER DLI ------
		ldx used_double_lower
		
eat_cpu_cycles2
		lda #0	;$a6
		sta WSYNC
		
		sta COLBK

LOWER_C2	= *+1		
		lda #$08			; 8
		sta COLPF0
LOWER_C3	= *+1		
		lda #$0c			; 12
		sta COLPF1
LOWER_C0	= *+1		
		lda #$00			; 0
		sta COLPF2
LOWER_C1	= *+1		
		lda #$04			; 4
		sta COLBK
		
		lda #0	;$a6
		sta WSYNC
		
		sta COLBK
		
LOWER_C4	= *+1		
		lda #$02			; 2
		sta COLPF0
LOWER_C5	= *+1		
		lda #$06			; 6
		sta COLPF1
LOWER_C7	= *+1		
		lda #$0e			; 14
		sta COLPF2
LOWER_C6	= *+1		
		lda #$0a			; 10
		sta COLBK
		
		dex
		bne eat_cpu_cycles2
		
		lda #0
		sta WSYNC
		sta COLBK
		sta COLPF0
		sta COLPF1
		sta COLPF2
		sta COLPF3

;		lda #0
		sta GRAFP0
		sta GRAFP1
		sta GRAFP2
		sta GRAFP3
		sta GRAFM

		lda dl_hook
		cmp #1			; jump hook?
		bne no_hook
; hook to piano_roll_dl
		lda #<dli_piano
		sta VDSLST
		lda #>dli_piano
		sta VDSLST+1

		pla
		tay
		pla
		tax
		pla
		rti
		
no_hook
		lda #<dli_footer
		sta VDSLST
		lda #>dli_footer
		sta VDSLST+1
		
		pla
		tay
		pla
		tax
		pla
		rti

dli_piano
		pha
		txa
		pha
		tya
		pha

		lda #0
		sta WSYNC
		sta SIZEM
		lda #4+16
		sta PRIOR
		
		lda #$ff
		sta GRAFP0
		sta GRAFP1
		lda #$aa
		sta GRAFM

		lda #$60
		sta HPOSP0
		lda #$80
		sta HPOSP1
		
; put music notes from RMT in missiles
show_music_notes
		ldx #3
show_msx
		lda trackn_note,x
;		asl
		adc #$6a
		sta HPOSM0,x
		dex
		bpl show_msx
				
		ldx #0
piacol
		lda piano_tube,x
		sta WSYNC
		sta COLPM0
		sta COLPM1
		lda piano_keys,x
		sta COLPF3
		inx
		cpx #24
		bne piacol

		lda #1
		sta PRIOR

		lda #0
		sta COLPM0
		sta COLPM1
		sta GRAFP0
		sta GRAFP1
		sta HPOSM0
		sta HPOSM1
		sta HPOSM2
		sta HPOSM3
		
		lda shadow_hpos0
		sta HPOSP0
		lda shadow_hpos1
		sta HPOSP1

		lda #<dli_footer
		sta VDSLST
		lda #>dli_footer
		sta VDSLST+1
		
		pla
		tay
		pla
		tax
		pla
		rti

piano_keys
		dta $72,$74,$76,$78,$7a,$7a,$7e,$7e
		dta $7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e
		dta $7e,$7e,$7c,$7a,$78,$76,$74,$72

piano_tube
		dta $00,$00,$00,$00
		dta $00,$02,$04,$06
		dta $08,$0a,$0c,$0e
		dta $0e,$0c,$0a,$08
		dta $06,$04,$02,$00
		dta $00,$00,$00,$00

set_upper_color
		sta UPPER_C0		; x0
		ora #$04
		sta UPPER_C1		; x4
		ora #$0C
		sta UPPER_C3		; xC
		and #$f8
		sta UPPER_C2		; x8
		and #$f0
		ora #2				; x2
		sta UPPER_C4
		ora #6				; x6
		sta UPPER_C5
		ora #10
		and #$fa			; xa
		sta UPPER_C6
		ora #4				; xe
		sta UPPER_C7			
		rts

set_lower_color
		sta LOWER_C0		; x0
		ora #$04
		sta LOWER_C1		; x4
		ora #$0C
		sta LOWER_C3		; xC
		and #$f8
		sta LOWER_C2		; x8
		and #$f0
		ora #2				; x2
		sta LOWER_C4
		ora #6				; x6
		sta LOWER_C5
		ora #10
		and #$fa			; xa
		sta LOWER_C6
		ora #4				; xe
		sta LOWER_C7			
		rts

set_cinema_colors
		sta UPPER_C0		; x0
		sta LOWER_C0		; x0

		sta UPPER_C4		; x2
		sta LOWER_C4		; x2

		sta UPPER_C1		; x4
		sta LOWER_C1		; x4

		sta UPPER_C5		; x6
		sta LOWER_C5		; x6

		lda #8
		sta UPPER_C2		; x8
		sta LOWER_C2		; x8
;		lda #12
		sta UPPER_C3		; xC
		sta LOWER_C3		; xC
		lda #10
		sta UPPER_C6		; xa
		sta LOWER_C6		; xa
;		lda #14
		sta UPPER_C7		; xe
		sta LOWER_C7		; xe
		rts

dli_footer
		pha
		txa
		pha
		
		ldx #7
colbar_footer
		lda footer_colors,x
		sta WSYNC
		sta COLPF0
		dex
		bpl colbar_footer

		ldx info_vscrol
		lda info_delay
		beq do_vscrol
		inc info_delay
		jmp no_end_vscrol
		
do_vscrol
		inx
		cpx #8
		bne no_end_vscrol

; show next info text
		lda dl_info_text
		cmp #<end_info_text
		bne not_end_info
		lda dl_info_text+1
		cmp #>end_info_text
		bne not_end_info
		
		lda #<info_text
		sta dl_info_text
		lda #>info_text
		sta dl_info_text+1
		jmp reset_vscrol
		
not_end_info
		lda dl_info_text
		clc
		adc #40
		sta dl_info_text
		lda dl_info_text+1
		adc #0
		sta dl_info_text+1
		
reset_vscrol
		ldx #0
		inc info_delay
no_end_vscrol
		stx info_vscrol				
		stx VSCROL

		pla
		tax
		pla
		rti

footer_colors
		dta $24,$26,$28,$2a
		dta $2a,$28,$26,$24

; x = config value 0,1,2,3
; 0 = normal width, 1 = double width, 2 = quad width, 3 = quad width

set_pm_config
		lda pm_size_table,x
		sta SIZEP0
		sta SIZEP1
		sta SIZEP2
		sta SIZEP3
		sta SIZEM

		lda pm_upper_offset_table,x
		sta pm_upper_offset
	
; config hpos
		txa
		asl
		asl
		asl
		tax		; x * 8

		lda pm_hpos_table,x
		sta shadow_hpos0
		lda pm_hpos_table+1,x
		sta shadow_hpos1

		ldy #0
all_config
		lda pm_hpos_table,x
		sta HPOSP0,y
		inx
		iny
		cpy #8
		bne all_config
		
		rts
	
; fill pm area with value A

fill_pm_area
		ldx #0
setpm
		sta pm_area,x
		sta pm_area+$100,x
		sta pm_area+$200,x
		sta pm_area+$300,x
		inx
		bne setpm
		rts
		
; print 1,2,3,HORSE in pm
; 0= "1"
; 3= "2"
; 6= "3"
; 9= 5 x space
; 14="HORSE"

print_horse
		ldy #0				; target table
print_5pm
		tya
		pha

		txa
		pha					; char index
		
		jsr print_pm_char

		pla
		tax
		pla
		tay
		
		inx
		iny
		cpy #5
		bne print_5pm
		
		rts
		
; print character to pm
; y = pm target table index 0,1,2,3,4		
; a = index for pm_char_table
; pm_height = height of pm character line (1,2,4)

print_pm_char
		asl
		tax
		lda pm_char_table,x
		sta pm_src
		inx
		lda pm_char_table,x
		sta pm_src+1

		tya
		asl
		tax
		lda pm_target_table,x
		sta pm_tar
		clc
		adc pm_upper_offset
		sta pm_tar

		inx
		lda pm_target_table,x
		sta pm_tar+1

; copy char to pm with given height
; height 

copy_one_char
		lda #8
		sta tmp_index
		ldy #0
copychar
		ldx #0
		lda (pm_src),y
copyhgt
		sta (pm_tar),y
		inc pm_tar		; lo-byte only
		inx
		cpx pm_height
		bne copyhgt
		
		inc pm_src		; lo-byte only
		dec tmp_index
		bne copychar
		
		rts
		
pm_hpos_table
		dta $6C,$74,$7C,$84,$92,$90,$8E,$8C		; $00 : 0 - $8C,$8E,$90,$92
		dta $58,$68,$78,$88,$A4,$A0,$9C,$98		; $08 : 1 - $98,$9C,$A0,$A4
		dta $30,$50,$70,$90,$C8,$C0,$B8,$B0		; $10 : 2 - $B0,$B8,$C0,$C8
		dta $18,$00,$00,$C8,$00,$00,$00,$00		; $18 : 3
		dta $18,$38,$A8,$C8,$00,$00,$00,$00		; $20 : 4

pm_size_table
		dta $00,$55,$ff,$ff,$ff
pm_upper_offset_table
		dta 12,8,0,0,0

pm_char_table
; 0
		dta a(font)				; <space>
		dta a(font)				; <space>
		dta a(font+$88)			; 1
; 3
		dta a(font)				; <space>
		dta a(font)				; <space>
		dta a(font+$90)			; 2
; 6
		dta a(font)				; <space>
		dta a(font)				; <space>
		dta a(font+$98)			; 3
; 9
		dta a(font)				; <space>
		dta a(font)				; <space>
		dta a(font)				; <space>
		dta a(font)				; <space>
		dta a(font)				; <space>
; 14
		dta a(font+$140)		; H
		dta a(font+$178)		; O
		dta a(font+$190)		; R
		dta a(font+$198)		; S
		dta a(font+$128)		; E

pm_target_table
		dta a(pm0_area+PM_TOP_MARGIN)
		dta a(pm1_area+PM_TOP_MARGIN)
		dta a(pm2_area+PM_TOP_MARGIN)
		dta a(pm3_area+PM_TOP_MARGIN)
		dta a(msl_area+PM_TOP_MARGIN)

; init. fx player stuff
init_fx_player
		lda #0
		sta fx_jiffy_count
		sta fx_jiffy_count+1
		sta fx_status
		sta fx_seq_value
		sta fx_seq_index
		dec fx_seq_index	; on first fx, it will increase to 0 :)
		rts
		
; fx player, should execute each frame
fx_player
		lda fx_jiffy_count
		ora fx_jiffy_count+1
		beq reached_zero		; countdown timer
; timer not finished
		dec fx_jiffy_count
		lda fx_jiffy_count
		cmp #255
		bne nh_fx_jif
		dec fx_jiffy_count+1
nh_fx_jif
; check status to see if we want to run fx, 0=idle, 1=running
		lda fx_status
		beq dummy_jsr
; jump to current fx
		jmp (fx_running_pointer)
dummy_jsr
		rts

; timer finished, next fx!
reached_zero
		inc fx_seq_index		; first time this is 255, so will be 0 after inc
		ldx fx_seq_index
reset_sequence
		lda fx_sequence_table,x
		sta fx_seq_value
		bpl regular_fx
		cmp #255
		bne pause_fx

; end of sequence!
		ldx #REPEAT_INDEX				; repeat after intro
		stx fx_seq_index
		jmp reset_sequence

; pause fx, special case
pause_fx
		and #$7f		; remove pause indicator bit
		asl				; x 2
		tax
		lda fx_pause_table+$00,x
		sta fx_jiffy_count
		lda fx_pause_table+$01,x
		sta fx_jiffy_count+1
		
		lda #0
		sta fx_status	; no fx running
; stop previous fx
		jsr fx_stop_jsr
; put back dummy stop in case of two pause sequences!
		lda #<dummy_jsr
		sta fx_stop_jsr+1
		lda #>dummy_jsr
		sta fx_stop_jsr+2	
		rts
		
fx_stop_jsr
		jmp dummy_jsr		; first time stop, will be changed to fx stop address

; Regular fx info format
; - info pointer : 2 bytes pointer to fx block
; - jiffy counter : 2 bytes duration in jiffies
; - param : 2 bytes param, can be used by this fx

regular_fx
		jsr fx_stop_jsr

; start new regular fx
		lda fx_seq_value
		asl
		asl
		asl		; x 8

		tax
		lda fx_info_table+$00,x
		sta fx_info_pointer
		lda fx_info_table+$01,x
		sta fx_info_pointer+1

		lda fx_info_table+$02,x
		sta fx_jiffy_count
		lda fx_info_table+$03,x
		sta fx_jiffy_count+1

		lda fx_info_table+$04,x
		sta fx_param1
		lda fx_info_table+$05,x
		sta fx_param2

; @todo two unused bytes from info table could be used here

; fx config. block layout:
; - init. address : 2 bytes, address for fx init.
; - stop. address : 2 bytes, address for fx stop.
; - fx running routine : jsr here to execute the fx each frame

		ldy #0
		lda (fx_info_pointer),y
		sta fx_init_jsr+1
		iny
		lda (fx_info_pointer),y
		sta fx_init_jsr+2
		
		iny
		lda (fx_info_pointer),y
		sta fx_stop_jsr+1
		iny
		lda (fx_info_pointer),y
		sta fx_stop_jsr+2

		lda fx_info_pointer
		clc
		adc #4		; skip init,stop bytes
		sta fx_running_pointer
		lda fx_info_pointer+1
		adc #0				
		sta fx_running_pointer+1

		lda #1
		sta fx_status		; running

fx_init_jsr
		jsr dummy_jsr
		jmp (fx_running_pointer)

; fx sequence, the order of fx execution
; $00 : first fx index 0
; $80 : pause fx index 0
fx_sequence_table
		dta $81,$01,$81,$02,$81,$03,$81,$04,$82,$08		; index 0-8 intro
REPEAT_INDEX	= 10		;10
; repeating part, starts with index 10
		dta $81		; pause 10
		dta $07		; cinema
		dta $05		; running 20
		dta $09		; open curtains
		dta $0a		; close curtains
		dta $06		; vertical
		dta $05		; running 20
		dta $06		; vertical
		dta $05		; running 20
		dta $81		; pause 10
		dta $ff		; end

fx_info_table
		dta a(fx0_block), a(50), $00,$00,$00,$00		; $00 fx0
		dta a(fx1_block), a(60), $00,$00,$00,$00		; $01 fx1 - 1
		dta a(fx1_block), a(60), $03,$00,$00,$00		; $02 fx1 - 2
		dta a(fx1_block), a(60), $06,$00,$00,$00		; $03 fx1 - 3
		dta a(fx1_block), a(100), $0E,$03,$00,$00		; $04 fx1 - HORSE
		dta a(fx2_block), a(300), $00,$00,$00,$00		; $05 fx2 - show horse image
		dta a(fx3_block), a(300), $00,$00,$00,$00		; $06 fx3 - vertical movement
		dta a(fx4_block), a(300), $00,$00,$00,$00		; $07 fx4 - cinema start fx
		dta a(fx5_block), a(150), $00,$00,$00,$00		; $08 fx5 - white screen
		dta a(fx6_block), a(1200), $00,$00,$00,$00		; $09 fx6 - open curtains
		dta a(fx7_block), a(1200), $00,$00,$00,$00		; $0a fx7 - close curtains

fx_pause_table
		dta a(150)	; 150 jiffies
		dta a(10)	; 10 jiffies
		dta a(50)

; fx0 test fx
fx0_block
		dta a(fx0_init)
		dta a(fx0_stop)
fx0_running
		lda #$88
		sta COLBK
		rts
fx0_init
		rts
fx0_stop
		lda #$34
		sta COLBK
		rts

; fx1 fade-in 1,2,3 or Horse
; fx_param1 = 0,3,6,11
fx1_block
		dta a(fx1_init)
		dta a(fx1_stop)
; fx1 play
		lda fx1_pmsize_index
		cmp #3		; out of table index!
		bne do_fadein
		rts
do_fadein
		inc fx1_fade_in
		lda fx1_fade_in
		cmp #10
		bne no_end_fx1
		
		jsr fx1_writepm
		inc fx1_pmsize_index	; after read x !!!
		
		lda #0
		sta fx1_fade_in
		rts

no_end_fx1
		ldx fx1_pmsize_index
		lda fx1_fade_in
		lsr
		clc		
		adc fx1_base_colors,x
		ora #$50
setpmcol
		sta COLPM0
		sta COLPM1
		sta COLPM2
		sta COLPM3		
		rts
fx1_init
		lda fx_param2
		jsr SNGINIT
		lda #1
		sta music_play_on

		lda #0
		sta fx1_pmsize_index
		sta fx1_fade_in

		jsr setpmcol
fx1_writepm
		ldx fx1_pmsize_index	; should be ; 0,1,2
		jsr set_pm_config

		ldx fx1_pmsize_index
		lda fx1_pm_heigths,x	; 1,2,4
		sta pm_height

		ldx fx_param1
		jmp print_horse
fx1_stop
		ldx #9
		jsr print_horse
		jsr rmt_silence
		lda #0
		sta music_play_on	
		rts

fx1_pm_heigths
		dta 1,2,4
fx1_base_colors
		dta 0,5,10

; fx2 - horse movement		
FX2_HORSE_DELAY = 3
	
fx2_block
		dta a(fx2_init)
		dta a(fx2_stop)
; fx2 show horse
		rts
fx2_init
; save and set hook
		lda dl_hook+1
		sta saved_hook
		lda dl_hook+2
		sta saved_hook+1

		lda #$01		; dl jump
		sta dl_hook
		lda #<piano_roll_dl
		sta dl_hook+1
		lda #>piano_roll_dl
		sta dl_hook+2

; pm init.
		lda #$22		; size 40, pm dma off
		sta DMACTL
		
		lda #0
		sta GRACTL
		
		ldx #4
		jsr set_pm_config
		
		lda #$00
		jsr setpmcol

		lda #0		;STEP_TABLE_SIZE-1
		sta stepnr

		lda #20
		sta horse_scroll_speed

		lda #0
		jsr set_upper_color
		lda #0
		jsr set_lower_color

; init. music only when it is not running!
		lda music_play_on
		bne keep_on_playing_sir
		lda #6
		jsr SNGINIT
		lda #1
		sta music_play_on
keep_on_playing_sir

		lda #FX2_HORSE_DELAY
		sta horse_delay

; re-used by fx4
init_horse_animation
		lda horse_animation_on
		bne already_animated
		
; init. animate horse

;		lda #<70
;		sta scroll_offset
;		lda #>70
;		sta scroll_offset+1

		lda #1
		sta horse_animation_on
already_animated		
		rts
fx2_stop
		rts

; fx3 moving vertically
fx3_block
		dta a(fx3_init)
		dta a(fx3_stop)
; start		
		lda fx3_rotation_count
		beq end_rotation
		
		inc stepnr
		lda stepnr
		cmp #STEP_TABLE_SIZE
		bne no_flip_end

		lda #0
		sta stepnr

		dec fx3_rotation_count
		bne rotates_next
; top color adjust
		lda #0		
		jsr set_upper_color
		lda #0
		jsr set_lower_color
		rts

rotates_next
		
; flip colors	
flip_colors	
		ldx side_color_index
		lda side_color_table_up,x
		jsr set_upper_color
		lda side_color_table_down,x
		jsr set_lower_color

		dex
		bpl not_all_sides
		ldx #SIDE_TABLE_SIZE
not_all_sides
		stx side_color_index

end_rotation
no_flip_end
		rts
fx3_init
		lda #20
		sta horse_scroll_speed

;		lda #<10
;		sta scroll_offset
;		lda #>10
;		sta scroll_offset+1

		lda #SIDE_TABLE_SIZE
		sta side_color_index
		jsr flip_colors

		lda #8
		sta fx3_rotation_count

; restore hook
		lda #HORSE_MODE
		sta dl_hook
		lda saved_hook
		sta dl_hook+1
		lda saved_hook+1
		sta dl_hook+2
fx3_stop
		rts

; color of rotating sides, last color must be the same as first
SIDE_TABLE_SIZE = 7
side_color_table_up
		dta $00,$70,$a0,$60,$00,$40,$20,$c0
side_color_table_down
		dta $70,$a0,$60,$00,$40,$20,$c0,$00
		
fx4_block
		dta a(fx4_init)
		dta a(fx4_stop)
; fx4 - cinema start fx
		dec fx4_cinema_delay
		bne no_swap
		
		lda #20
		sta horse_scroll_speed		; next frame

		lda #14
		sta fx4_cinema_color
		jmp set_cinema_colors
		
no_swap
		bpl show_this_one
		
		lda fx4_init_delay
		sta fx4_cinema_delay
		
		lda #0
		sta horse_scroll_speed
		sta fx4_cinema_color
		jmp set_cinema_colors
		
show_this_one
		rts
fx4_init
		lda #3
		sta fx4_init_delay
		sta fx4_cinema_delay
		lda #0
		sta fx4_cinema_color
		
		jsr set_cinema_colors
		
		lda #$22		; size 40, pm dma off
		sta DMACTL
		
		lda #0
		sta GRACTL
		
		ldx #4
		jsr set_pm_config
		
		lda #$00
		jsr setpmcol

		lda #0		;STEP_TABLE_SIZE-1
		sta stepnr

		lda #0
		sta horse_scroll_speed
		sta horse_delay

		jmp init_horse_animation
fx4_stop
		rts
		
fx5_block
		dta a(fx5_init)
		dta a(fx5_stop)
; fx5 - white screen
		rts
fx5_init
		lda #$22		; size 40, pm dma off
		sta DMACTL
		
		lda #0
		sta GRACTL
		
		ldx #4
		jsr set_pm_config
		
		lda #$00
		jsr setpmcol
		
		lda #0
		sta horse_scroll_speed
fx5_stop
		rts

fx6_block
		dta a(fx6_init)
		dta a(fx6_stop)
; fx6 open curtains
		lda curtain_pos1
		cmp #$18
		beq already_open
		dec curtain_pos1
		inc curtain_pos2
already_open
		lda curtain_pos1
		sta HPOSP1
		lda curtain_pos2
		sta HPOSP2
		rts
fx6_init
		lda #$38
		sta curtain_pos1
		lda #$a8
		sta curtain_pos2
		
		lda #19
		sta horse_scroll_speed
		
		lda #3
		sta horse_delay
fx6_stop
		rts
		
fx7_block
		dta a(fx7_init)
		dta a(fx7_stop)
; fx7 close curtains
		lda curtain_pos1
		cmp #$38
		beq already_closed
		inc curtain_pos1
		dec curtain_pos2
already_closed
		lda curtain_pos1
		sta HPOSP1
		lda curtain_pos2
		sta HPOSP2
		
		lda scroll_offset+1
		cmp #>10
		bne fx7_not_stable
		lda scroll_offset
		cmp #<10
		bne fx7_not_stable
;		lda #0
;		sta horse_animation_on
;		sta horse_scroll_speed
;		sta horse_move_delay
		lda #20
		sta horse_scroll_speed
		
fx7_not_stable
		rts
fx7_init
		lda #$18
		sta curtain_pos1
		lda #$c8
		sta curtain_pos2
		
		lda #19
		sta horse_scroll_speed
		
		lda #3
		sta horse_delay
fx7_stop
		rts

; display horse lines according to the following settings
; stepnr : index to step table

show_horse
		jsr step_copy_lines
		
		dec horse_move_delay
		bpl wait_horsie
		lda horse_delay
		sta horse_move_delay
		
		lda horse_scroll_speed
		jsr add_to_scroll_offset
				
		lda scroll_offset+1
		cmp #>horse_dataline_size
		bne wait_horsie
		lda scroll_offset
		cmp #<horse_dataline_size
		bcc wait_horsie
		
; substract horse_dataline_size to reset to a first image position
		sec
		lda scroll_offset
		sbc #<horse_dataline_size
		sta scroll_offset
		lda scroll_offset+1
		sbc #>horse_dataline_size
		sta scroll_offset+1

wait_horsie
		rts

; move images to memory blocks without crossing 4K boundary
prepare_images
		lda #<horse_source_data
		sta tmp_src
		lda #>horse_source_data
		sta tmp_src+1
	
		lda #<horse_screen_start
		sta tmp_tar
		lda #>horse_screen_start
		sta tmp_tar+1
	
		lda #0			; line count, 0-105
		sta horse_line_number

copy_all_lines
		ldx #0
next_scanline
; base_tar keeps a pointer to the start of the source line
		ldy horse_line_number
		lda tmp_tar
		sta tmp_base_tar
		sta horse_dma_lo,y
		lda tmp_tar+1
		sta tmp_base_tar+1
		sta horse_dma_hi,y

		lda #0
		sta tmp_size
		sta tmp_size+1
	
copy_dataline
		ldy #0
		lda (tmp_src),y
; tryout to preprocess image xor $aa (line 0), $ff (line 1)
image_exor		
		eor #$aa
		sta (tmp_tar),y

		inc tmp_src
		bne nh_src
		inc tmp_src+1
nh_src

		inc tmp_tar
		bne nh_tar
		inc tmp_tar+1
nh_tar

		inc tmp_size		
		bne nh_size
		inc tmp_size+1
nh_size
		lda tmp_size
		cmp #<horse_dataline_size
		bne copy_dataline
		lda tmp_size+1
		cmp #>horse_dataline_size
		bne copy_dataline

; 300 bytes (15x20) copied, now first 40 bytes to tmp_tar (scanline buffer space)

copy_buffer
		lda (tmp_base_tar),y
		sta (tmp_tar),y
		iny
		cpy #40
		bne copy_buffer
		
		lda tmp_tar
		clc
		adc #40
		sta tmp_tar
		lda tmp_tar+1
		adc #0
		sta tmp_tar+1

		lda #$aa
		cmp image_exor+1
		bne not_aa
		lda #$ff
not_aa
		sta image_exor+1
		
; now tmp_src = tmp_src+300, tmp_tar = tmp_tar + 340

		inc horse_line_number
		inx
		cpx #LINES_IN_4K
		bne next_scanline
		
; LINES_IN_4K x 340 bytes copied
; add ALIGNMENT_4K to src_tar to advance to 4k boundary!
		lda tmp_tar
		clc
		adc #ALIGNMENT_4K
		sta tmp_tar
		lda tmp_tar+1
		adc #0
		sta tmp_tar+1

		ldx #0
		lda horse_line_number
		cmp #HORSE_LINE_COUNT
		bcc copy_all_lines
		rts	

; clean up gen_dl, filling it with dummy_line dma
clean_gen_dl
		jsr set_tmp_tar_to_gen_dl
		
		ldx #0
		
gen_clean_all
		ldy #0
		
		lda #<dummy_line
		sta horse_dma_lo,x
		lda #>dummy_line
		sta horse_dma_hi,x
		
		lda #HORSE_MODE
		sta (tmp_tar),y
		iny
		lda #<dummy_line
		sta (tmp_tar),y
		iny
		lda #>dummy_line
		sta (tmp_tar),y
		
		lda tmp_tar
		clc
		adc #3
		sta tmp_tar
		lda tmp_tar+1
		adc #0
		sta tmp_tar+1
		
		inx
		cpx #GEN_DL_DMA_LINES
		bne gen_clean_all
		rts

set_tmp_tar_to_gen_dl
		lda #<gen_dl
		sta tmp_tar
		lda #>gen_dl
		sta tmp_tar+1
		rts
		
add_to_scroll_offset
		clc
		adc scroll_offset
		sta scroll_offset
		lda scroll_offset+1
		adc #0
		sta scroll_offset+1
		rts

; DL generation

; copy horse dma lines to tmp_tar by using a 16-bit step counter
step_copy_lines
		lda #0
		sta used_double_lines
; target is gen_dl
		jsr set_tmp_tar_to_gen_dl
; set upper halve
		ldx stepnr
		jsr step_lines
		
		lda used_double_lines
		sta used_double_upper
		bne no_fix_upper
		inc used_double_upper
no_fix_upper

;		rts
; set lower halve
		lda #0
		sta used_double_lines

		lda #STEP_TABLE_SIZE
		clc
		sbc stepnr
		tax
		jsr step_lines

		lda used_double_lines
		sta used_double_lower
		bne no_fix_lower
		inc used_double_lower
no_fix_lower
		rts

; @todo remove
; generate end of display list			
		ldy #0
		lda #$41	
		sta (tmp_tar),y
		iny
		lda #<horse_dl
		sta (tmp_tar),y
		iny
		lda #>horse_dl
		sta (tmp_tar),y
		rts

step_lines
		lda steps_table_lo,x
		sta step_size
		lda steps_table_hi,x
		sta step_size+1
		
		lda #0
		sta line_number
		sta line_number+1
		
next_line
		lda line_number+1		; hi byte as index
		asl						; x 2
		tax
		ldy #0

; gen_line
;		lda #HORSE_MODE
;		sta (tmp_tar),y
		iny
		lda scroll_offset
		clc
		adc horse_dma_lo,x
		sta (tmp_tar),y
		lda scroll_offset+1
		adc horse_dma_hi,x
		iny
		sta (tmp_tar),y
		iny
; end gen_line

; inx -> horse_dma_lo+1, horse_dma_hi+1

; gen_line
;		lda #HORSE_MODE
;		sta (tmp_tar),y
		iny
		lda scroll_offset
		clc
		adc horse_dma_lo+1,x
		sta (tmp_tar),y
		lda scroll_offset+1
		adc horse_dma_hi+1,x
		iny
		sta (tmp_tar),y
		iny
; end gen_line
		
		inc used_double_lines
		
		lda tmp_tar
		clc
		adc #6			; mode,lo,hi
		sta tmp_tar
		lda tmp_tar+1
		adc #0
		sta tmp_tar+1
		
		lda line_number
		clc
		adc step_size
		sta line_number
		lda line_number+1
		adc step_size+1
		sta line_number+1

		cmp #HORSE_DOUBLE_SCAN-1
		bcc next_line

		rts
				
stepnr			dta 0

; ------ step table ------

steps_table_lo
; size 19
;		dta 0,153,148,201,221,91,0,188,137,105,74,55,38,23,15,7,2,0,253
; size 31
		dta 0,170,213,227,106,201,30,202,104,30,246,211,168,143,120
		dta 101,83,67,59,45,38,26,20,15,10,4,4,0,0,0,251
;		dta 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;		dta 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;,0
				
steps_table_hi
; size 19
;		dta 106,10,5,3,2,2,2,1,1,1,1,1,1,1,1,1,1,1,0
; size 31
		dta 53,17,8,5,4,3,3,2,2,2,1,1,1,1,1
		dta 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0
;		dta 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
;		dta 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; must not cross 4K boundary
info_text
		dta d'          A tribute to Helios!          '
		dta d'        The First motion picture        '
		dta d'          The Horse in motion           '
		dta d'         Eadweard Muybridge 1878        '
		dta d'                                        '
		dta d'  Gfx mode: IVOP, Gfx conversion: FRS   '
		dta d'    Msx: MIKER, Design/Code: F#READY    '
		dta d'       Original images by Helios        '                        
		dta d'                                        '
		dta d'Greetz to all visitors at Silly Venture!'
		dta d'                                        '
end_info_text
		dta d'          A tribute to Helios!          '

;------------------------------------------------------------------------------

; ins includes binary files - opt h- means that binary file contains address header already
; MUSIC static loaded at $4000
MUSIC			= $A000  ; that's address of RMT module 
	 	opt h-
		ins ".\music\dill_pickels_rag3a1_stripped.rmt"
		
	 	opt h+

;------------------------------------
; including player
; PLAYER entry is set to $B800 but it takes PLAYER - $0320 (mono)
; so effectively it takes space from $B4E0 ($b400 - $0320)
; PLAYER must be set to beginning of page
; start op $b800
STEREOMODE      equ 0
		icl ".\music\rmtplayr.a65"
		
; @todo trick to let the assembler know where the MUSIC file ends...
		.ds 1

; SONG INIT
; player initialisation
        .PROC SNGINIT
        	ldx #<MUSIC
        	ldy #>MUSIC
;        	lda #6
        	jmp rmt_init ; init music			
		.ENDP
			
; copies the code part under ROM $c000 - $cfff 

copy_code
		lda #0
		sta SDMCTL

		lda 20
wt20
		cmp 20
		bne wt20
		
		lda #<CODE_SOURCE
		sta tmp_src
		lda #>CODE_SOURCE
		sta tmp_src+1

		lda #<CODE_TARGET
		sta tmp_tar
		lda #>CODE_TARGET
		sta tmp_tar+1
		
		php
		sei				; irq off
		lda NMIEN
		pha
		lda #0
		sta NMIEN
		lda PORTB
		and #$FE		; OS ROM off
		sta PORTB				
		
		ldx #CODE_PAGES
		ldy #0
copage
		lda (tmp_src),y
		sta (tmp_tar),y
		iny
		bne copage
		inc tmp_src+1
		inc tmp_tar+1
		dex
		bne copage

		lda PORTB
		ora #$01		; OS ROM on
		sta PORTB				

		pla
		sta NMIEN
		plp
		cli
		
; copy system font
		ldx #0
copyfont
		lda OSFONT,x
		sta font,x
		lda OSFONT+$100,x
		sta font+$100,x
		lda OSFONT+$200,x
		sta font+$200,x
		lda OSFONT+$300,x
		sta font+$300,x
		inx
		bne copyfont
		
		rts

; sync to start of screen
sync_start
		lda VCOUNT
		bne sync_start
		rts

; run main program
main_horse
		lda #0
		sta NMIEN
		sta IRQEN
		lda PORTB
		and #$FE		; OS ROM off
		sta PORTB

		jmp horse_code
		
		ini copy_code
		
; -----------------------------------------------------------------------------
		
		org horse_screen_start + SCREEN_BUFFER_SPACE
horse_source_data
;		ins 'horse_all.gr9'
;		ins 'horsetst.g15'
;		ins 'horse_gr15_80x106.g15'
		ins 'horsexor.g15'

; should not be overwritten?
		.db $01,$02,$03,$ff

		run main_horse