	.file	"main.c"
	.machine ppc
	.section	".text"
	.globl __eabi
	.section	.rodata.str1.1,"aMS",@progbits,1
.LC0:
	.string	"\033[2;0H"
.LC2:
    .string "\x1b[2J" #For resetting the console
.LC3:
    .string "\n\nExiting to HBC..."
.LC4:
    .string "%02X %02X %02X %02X " #See the space at end
.LC5:
    .string "%02X %02X %02X %02X\n" #For going into new row
.LC6:
    .string "\n\n\x1b[31mMemalign Error. Auto-exiting to HBC. Please wait..."
.LC7:
    .string "\n\n\x1b[31mSprintf Error. Auto-exiting to HBC. Please wait..."
.LC1:
	.string	"\n\nSEEPROM Viewer (v0.8) by \x1b[45m\x1b[30mVega\x1b[40m\x1b[37m. Build Date: Dec 22, 2021\n\nOriginal seeprom_read code by Team Twiizers.\n\nPress Home/Start button to return back to \x1b[36mHBC\x1b[37m.\n\n"
	.section	.text.startup,"ax",@progbits
	.align 2
	.globl main
	.type	main, @function
main:
.LFB64:
	.cfi_startproc
	stwu 1,-16(1)
	.cfi_def_cfa_offset 16
	mflr 0
	stw 0,20(1)
	stmw 30,8(1)
	.cfi_offset 65, 4
	.cfi_offset 30, -8
	.cfi_offset 31, -4
	bl __eabi
	bl VIDEO_Init
	lis 31,.LANCHOR0@ha
	bl WPAD_Init
	bl PAD_Init #Added in Manually for GC Controller support
	li 3,0
	bl VIDEO_GetPreferredMode
	la 30,.LANCHOR0@l(31)
	stw 3,.LANCHOR0@l(31)
	bl SYS_AllocateFramebuffer
	lwz 9,.LANCHOR0@l(31)
	li 5,20
	li 4,20
	addis 3,3,0x4000
	lhz 6,4(9)
	lhz 7,8(9)
	slwi 8,6,1
	stw 3,4(30)
	bl CON_Init
	lwz 3,.LANCHOR0@l(31)
	bl VIDEO_Configure
	lwz 3,4(30)
	bl VIDEO_SetNextFramebuffer
	li 3,0
	bl VIDEO_SetBlack
	bl VIDEO_Flush
	bl VIDEO_WaitVSync
	lwz 9,.LANCHOR0@l(31)
	lwz 9,0(9)
	andi. 9,9,0x1
	beq+ 0,.L2
	bl VIDEO_WaitVSync
.L2:
	lis 3,.LC0@ha #Clear the Console
	la 3,.LC0@l(3)
	crxor 6,6,6
	bl printf
	
	lis 3,.LC2@ha #Reset the Console
	la 3,.LC2@l(3)
	crxor 6,6,6
	bl printf
	
	#SEEPROM args for seeprom_read
    lis r3, 0x8000
    ori r3, r3, 0x1400
    li r4, 0
    li r5, 0x80
	
#r0 = scrap
#r3 = Arg 1
#r4 = Arg 2
#r5 = Arg 3
#r6 = another LR backup
#r7 = Unused
#r8 = current bit to send to SEEPROM
#r9 = 1st arg of send_bits
#r10 = Loop Tracker of send_bits
#r11 = GPIO
#r12 = Unused

#GPIO_OUT
#Bit 19 = DI
#Bit 20 = SK
#Bit 21 = CS

#GPIO_IN
#Bit 18 = DO

#Args
#r3 = Address to Dump Seeprom Contents To
#r4 = Seeprom Offset start
#r5 = Amount of 16-bit reads to read starting at r4

#Set GPIO Upper 16 bits
lis r11, 0xCD80

#Unclock and Clear CS
lwz r0, 0x00E0 (r11)
sync
rlwinm r0, r0, 0, 22, 19 #Clear CS and SK
stw r0, 0x00E0 (r11)
eieio
bl wait

#Main Loop (for multiple reads if done)
seeprom_read_loop:

#Turn on Chip Select
lwz r0, 0x00E0 (r11)
sync
ori r0, r0, 0x0400 #CS high
stw r0, 0x00E0 (r11)
eieio
bl wait

###READ###
#SB = 1
#OpCode = 10
#Address x16 = XXXXXXXX (SEEPROM offset, 0x00 thru 0x7F)
ori r9, r4, 0x600

#Send bits to SEEPROM

#Setup Loop amount
li r10, 10 #Instruction length minus 1

send_bit_loop:
srw r8, r9, r10 #Make current bit being sent be placed on bit 31 slot

#Load GPIO
lwz r0, 0x00E0 (r11)
sync

#Replace bit 19 of loaded GPIO with bit 31 of r8
rlwimi r0, r8, 12, 19, 19 #Hex mask of 0x00001000

#Send the bit!
stw r0, 0x00E0 (r11)
eieio
bl wait

#Clock and Unclock
bl clock_unclock

subic. r10, r10, 1
bge+ send_bit_loop

#Current READ command & address sent, now retrieve the data
li r10, 0
li r0, 16 #16 for 16 bits in a atmel word
mtctr r0

#Bit receiving loop
retrieve_bit_loop:
slwi r10, r10, 1

bl clock_unclock

lwz r0, 0x00E8 (r11) #GPIO_IN!!!!!!!!!!!
sync
rlwinm r0, r0, 19, 31, 31 #Place bit into bit 31 slot, clear all other bits

#Compile Bits to 16-bit Hex atmel word; decrement loop
or r10, r10, r0
bdnz+ retrieve_bit_loop

#Store finished Data
sth r10, 0 (r3)

#Turn Chip Select Low, need to do this if we wanna issue another Read Command
lwz r0, 0x00E0 (r11)
sync
rlwinm r0, r0, 0, 22, 20
stw r0, 0x00E0 (r11)
eieio
bl wait

#Main Loop Decrementer
subic. r5, r5, 1
addi r3, r3, 2 #Increment to next place to store newly read Atmel word
addi r4, r4, 1 #Increment to next SEEPROM offset
bne+ seeprom_read_loop

#Everything is done, CS and SK already low, and a wait was already done
b allocate_memory

#Clock and unclock subroutine
clock_unclock:
mflr r6

lwz r0, 0x00E0 (r11)
sync
ori r0, r0, 0x0800 #SK; bit 20 high
stw r0, 0x00E0 (r11)
eieio
bl wait
lwz r0, 0x00E0 (r11)
sync
rlwinm r0, r0, 0, 21, 19 #Sk; bit 20 low
stw r0, 0x00E0 (r11)
eieio
bl wait

mtlr r6
blr

#Wait subroutine
wait:
li r0, 0 #Reset Starlet Timer
stw r0, 0x0010 (r11)

wait_loop:
lwz r0, 0x0010 (r11)
cmplwi r0, 2 #Check if 2 'tick's (~1000 nanoseconds) has elapsed
blt- wait_loop

blr
	
	#Allocate some memory for sprintf shit
	allocate_memory:
	li r3, 32 #32 bit alignment, why not
	li r4, 0x2000 #Should be more than enough
	bl memalign
	cmpwi r3, 0
	beq- err_memalign
	
	#Inline ASM stack pop for one register
	stwu sp, -0x0020 (sp)
	stmw r28, 0x8 (sp)
	
	#Backup memalign pointer
	mr r31, r3
	
	#Set r30 (seeprom raw contents pointer - 1)
	lis r30, 0x8000
	ori r30, r30, 0x13FF #For loading sprintf args
	
	#Copy r31 to r28; used for cursor updating after every sprintf
	mr r28, r31
	
	#Sprintf program title, basically transfer the string from rodata to memalign block
	#r3 already set
	lis r4, .LC1@ha
	la r4, .LC1@l (r4)
	crxor 6,6,6
	bl sprintf
	cmpwi r3, 0
	blt- err_sprintf
	
	#Increment r28 based on r3 amount to keep updating the cursor spot for next sprintf call
	add r28, r28, r3
	
	#Loop to sprintf all the rows
	#Loop iterations 4,8,12, etc etc do the enter in row, not space
	#Set loop tracker byte; 64 is max
	li r29, 0
	
	#Loop
	sprintf_loop:
	addi r29, r29, 1
	cmpwi r29, 65 #Once 65 is hit, 64 32-bit words have been done
	beq- setup_the_printf
	
	#Check for loop iteration 4,8,12,16 etc etc
	clrlwi. r0, r29, 30 #Clear everything but final two right side bits
	bne+ do_spacer_line
	
	#Do enter down line
	lis r4, .LC5@ha
	la r4, .LC5@l (r4)
	b call_sprintf
	
	#Spacer line instead
	do_spacer_line:
	lis r4, .LC4@ha
	la r4, .LC4@l (r4)
	
	#Sprintf it!
	call_sprintf:
	mr r3, r28
	lbzu r5, 0x1 (r30) #Do lwzu's to always keep r30 updated
	lbzu r6, 0x1 (r30)
	lbzu r7, 0x1 (r30)
	lbzu r8, 0x1 (r30)
	crxor 6,6,6
	bl sprintf
	cmpwi r3, 0
	blt- err_sprintf
	
	#Update r28 based on r3 amount to keep updating the cursor spot for next sprintf call
	add r28, r28, r3
	
	#Now Loop Back
	b sprintf_loop
	
	#Setup printf's only GPR arg
	setup_the_printf:
	mr r3, r31
	
	#Pop the Inline stack; don't need it anymore
	lmw r28, 0x8 (sp)
	addi sp, sp, 0x0020
	
	#Everything has been 'sprintf'd', now print that bitch!
	crxor 6,6,6
	bl printf
	
	#Check if Home/Start was pressed. If so, exit HBC.
.L4:
	bl WPAD_ScanPads
	li r3, 0
	bl WPAD_ButtonsDown
	andi. r3, r3, 0x0080 #Bit 24 for HOME on any Wii Remote Based Controller
	bne- exit_to_hbc
	bl PAD_ScanPads
	li r3, 0
	bl PAD_ButtonsDown
	andi. r3, r3, 0x1000 #Bit 19 for Start on GCN
	beq+ .L3
	
	#Exit to HBC
	exit_to_hbc:
	lis 3,.LC2@ha #Reset the Console
	la 3,.LC2@l(3)
	crxor 6,6,6
	bl printf
	lis 3,.LC3@ha #Exiting to HBC...
	la 3,.LC3@l(3)
	crxor 6,6,6
	bl printf
	li r3, 0
	bl exit
	b .L3
	
	#Memalign error
	err_memalign:
	lis 3,.LC2@ha #Reset the Console
	la 3,.LC2@l(3)
	crxor 6,6,6
	bl printf
	lis 3,.LC6@ha
	la 3,.LC6@l(3)
	crxor 6,6,6
	bl printf
	b .L4
	
	#sprintf error; first pop the stack
	err_sprintf:
	lmw r28, 0x8 (sp)
	addi sp, sp, 0x0020
	lis 3,.LC2@ha #Reset the Console
	la 3,.LC2@l(3)
	crxor 6,6,6
	bl printf
	lis 3,.LC7@ha
	la 3,.LC7@l(3)
	crxor 6,6,6
	bl printf
	b .L4
	
.L3:
	bl VIDEO_WaitVSync
	b .L4
	.cfi_endproc
.LFE64:
	.size	main, .-main
	.section	".bss"
	.align 2
	.set	.LANCHOR0,. + 0
	.type	rmode, @object
	.size	rmode, 4
rmode:
	.zero	4
	.type	xfb, @object
	.size	xfb, 4
xfb:
	.zero	4
	.ident	"GCC: (devkitPPC release 39) 11.1.0"
