
	.file	"main.c"
	.section	".text"
	.lcomm	xfb,4,4
	.type	xfb, @object
	.lcomm	rmode,4,4
	.type	rmode, @object
	.globl __eabi
	.section	.rodata
	.align 2
.LC0:
	.string	"\033[2;0H"
	.section	".text"
	.align 2
	.globl main
	.type	main, @function
main:
.LFB64:
	.cfi_startproc
	stwu 1,-40(1)
	.cfi_def_cfa_offset 40
	mflr 0
	stw 0,44(1)
	stw 31,36(1)
	.cfi_offset 65, 4
	.cfi_offset 31, -4
	mr 31,1
	.cfi_def_cfa_register 31
	stw 3,24(31)
	stw 4,28(31)
	bl __eabi
	bl VIDEO_Init
	bl WPAD_Init
	li 3,0
	bl VIDEO_GetPreferredMode
	mr 10,3
	lis 9,rmode@ha
	stw 10,rmode@l(9)
	lis 9,rmode@ha
	lwz 9,rmode@l(9)
	mr 3,9
	bl SYS_AllocateFramebuffer
	mr 9,3
	addis 9,9,0x4000
	mr 10,9
	lis 9,xfb@ha
	stw 10,xfb@l(9)
	lis 9,xfb@ha
	lwz 10,xfb@l(9)
	lis 9,rmode@ha
	lwz 9,rmode@l(9)
	lhz 9,4(9)
	mr 6,9
	lis 9,rmode@ha
	lwz 9,rmode@l(9)
	lhz 9,8(9)
	mr 7,9
	lis 9,rmode@ha
	lwz 9,rmode@l(9)
	lhz 9,4(9)
	slwi 9,9,1
	mr 8,9
	li 5,20
	li 4,20
	mr 3,10
	bl CON_Init
	lis 9,rmode@ha
	lwz 9,rmode@l(9)
	mr 3,9
	bl VIDEO_Configure
	lis 9,xfb@ha
	lwz 9,xfb@l(9)
	mr 3,9
	bl VIDEO_SetNextFramebuffer
	li 3,0
	bl VIDEO_SetBlack
	bl VIDEO_Flush
	bl VIDEO_WaitVSync
	lis 9,rmode@ha
	lwz 9,rmode@l(9)
	lwz 9,0(9)
	rlwinm 9,9,0,31,31
	cmpwi 7,9,0
	beq 7,.L2
	bl VIDEO_WaitVSync
.L2:
	lis 9,.LC0@ha
	la 3,.LC0@l(9)
	crxor 6,6,6
	bl printf
	
	#~~~~~~~~~~~~~~~~~~~#
	# Custom Inline ASM #
	#~~~~~~~~~~~~~~~~~~~#

	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
	# Setup Args for SEEPROM READ #
	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
	
	lis r3, 0x8166
	li r4, 0
	li r5, 0x80
	
#~~~~~~~~~~~~~~#
# SEEPROM READ #
#~~~~~~~~~~~~~~#

#~~~~~~~~~~~~~~~~#
# Register Notes #
#~~~~~~~~~~~~~~~~#

#r12 = LR
#r11 = GPIO
#r10 = send bits arg 2, also part of rec bits
#r9 = send bits arg 1, also part of rec bits
#r8 = temp reg for send bits
#r7 = wait loop
#r6 = temp reg to check args, LR for clock/unclock subroutine

#~~~~~~#
# Args #
#~~~~~~#

#r3 = Address to Dump Seeprom Contents To
#r4 = Offset of Seeprom for 1st 16 bit word to read then dump
#r5 = Amount of 16 bit words to dump.

#~~~~~~~~~~~~~~~~~~#
# Set GPIO Address #
#~~~~~~~~~~~~~~~~~~#

lis r11, 0xCD80

#~~~~~~~~~~~~~~~~~~~~~~~~~#
# Unclock, Clear CS, Wait #
#~~~~~~~~~~~~~~~~~~~~~~~~~#

lwz r0, 0x00E0 (r11)
sync
rlwinm r0, r0, 0, 22, 19
stw r0, 0x00E0 (r11)
eieio

bl wait

#~~~~~~#
# LOOP #
#~~~~~~#

seeprom_read_loop:

#~~~~~~#
# READ #
#~~~~~~#

#SB = 1
#OpCode = 10
#Address x16 = XXXXXXXX (Seeprom Offset 0x00 thru 0x7F)

ori r9, r4, 0x600

#~~~~~~~~~~~~~~~~~~~~~#
# Turn on Chip Select #
#~~~~~~~~~~~~~~~~~~~~~#

lwz r0, 0x00E0 (r11)
sync
ori r0, r0, 0x400
stw r0, 0x00E0 (r11)
eieio

#No waiting, need rising edge

#~~~~~~~~~~~~~~~~~~~~~~#
# Send Bits to Seeprom #
#~~~~~~~~~~~~~~~~~~~~~~#

#~~~~~~~~~~~~~~~~~~#
# Bit Sending Loop #
#~~~~~~~~~~~~~~~~~~#

li r10, 10 #Instruction length minus 1

bit_loop:
srw r8, r9, r10 #Starting at Most Sig. Bit, each bit will have a spot in bit 31 to send in via DI of GPIO_OUT
clrlwi. r8, r8, 31 #SB bit, then OP Code bit, then OP Code bit, then Address/Don't-Care bit, etc etc

lwz r0, 0x00E0 (r11) #Load GPIO before taking branch routes
sync

bne- send_bit_to_seeprom
rlwinm r0, r0, 0, 20, 18 #Clear DI (Data to Seeprom) bit

b clock_unclock_then_decrement_loop

send_bit_to_seeprom:
ori r0, r0, 0x1000 #TURN ON DI (Data to Seeprom) bit

clock_unclock_then_decrement_loop:
stw r0, 0x00E0 (r11)
eieio

bl wait

bl clock_unclock

subic. r10, r10, 1
bge+ bit_loop

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Command + Address Sent, Retrieve Data #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

#~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Receive Bits from Seeprom #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~#

li r9, 0
li r10, 16 #16 for 16 bit atmel word

#~~~~~~~~~~~~~~~~~~~~#
# Bit Recieving Loop #
#~~~~~~~~~~~~~~~~~~~~#

retrieve_bit:
slwi r9, r9, 1

bl clock_unclock

lwz r0, 0x00E8 (r11) #Load GPIO_IN!!!
sync
rlwinm r0, r0, 19, 31, 31 #Rotate GPIO_IN Bit to Bit 31

#~~~~~~~~~~~~#
# Build Bits #
#~~~~~~~~~~~~#

or r9, r9, r0
subic. r10, r10, 1
bne+ retrieve_bit #Once Halfword is built, stop looping.

#~~~~~~~~~~~~~~~~~~~~~~#
# Store Retrieved Data #
#~~~~~~~~~~~~~~~~~~~~~~#

sth r9, 0 (r3)

#~~~~~~~~~~~~~#
# Turn Off CS #
#~~~~~~~~~~~~~#

lwz r0, 0x00E0 (r11)
sync
rlwinm r0, r0, 0, 22, 20
stw r0, 0x00E0 (r11)
eieio

bl wait

#~~~~~~~~~~~~~~~~~~#
# Loop Decrementer #
#~~~~~~~~~~~~~~~~~~#

subic. r5, r5, 1
addi r3, r3, 2 #Increment Address by 2 (atmel words are 16 bits ofc)
addi r4, r4, 1 #Increment Seeprom Offset by 1
bne+ seeprom_read_loop

#~~~~~~~~~~~~~~~~~~#
# END Seeprom READ #
#~~~~~~~~~~~~~~~~~~#

b hex_dump_conv

# This is a universal 'sleep'/'wait' subroutine needed to be executed when certain interactions are
# preformed to the SEEPROM. The amount of time to wait varies. However, it's easier to
# make-shift one universal sleep/wait routine. That is long enough to cover any type
# of interaction. Keep in mind, that the wait routine can't be way way too long or else
# you could exceed the Max Time Write Cycle (if you are writing to the Seeprom) which
# is 10 milli-seconds (a very long time lol)
# 
# Other devs in the past (in C) have used a time delay of 5 micro-seconds. 5 microseconds is a bit overkill.  
# The Bus has a speed of 60.75 ticks/nops per micro-second. We don't know which
# voltage version of the Seeprom the wii uses. So assuming the low-V/slowest model, we need atleast 
# 1 microsecond for clocking on/off, plus another 400 nano-seconds on top for DI Setup & 
# CS Setup time. 1400 nanoseconds. Bump it up to 2000 to be safe (2 microseconds)
# Instead of using 121.5 nops, we will use a loop. Most integer instructions in Broadway take
# just one cycle to complete. If not, they will take longer than one cycle. Let's assume
# every integer instructions takes one cycle to complete.
#
# In conclusion we need an execution of 122 integer/nop instructions for 2 microseconds to pass by

wait:
li r7, 61

wait_loop:
nop
subic. r7, r7, 1
bne+ wait_loop

blr

#~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Clock Unclock Subroutine #
#~~~~~~~~~~~~~~~~~~~~~~~~~~#

clock_unclock:
mflr r6

lwz r0, 0x00E0 (r11)
sync
ori r0, r0, 0x800 #Clock the Seeprom
stw r0, 0x00E0 (r11)
eieio

bl wait

lwz r0, 0x00E0 (r11)
sync
rlwinm r0, r0, 0, 21, 19 #Unclock Seeprom
stw r0, 0x00E0 (r11)
eieio

bl wait

mtlr r6
blr

	#~~~~~~~~~~~~~~~~~~~~#
	# Hex Dump Converter #
	#~~~~~~~~~~~~~~~~~~~~#

	#Converts Large Dumps of Hex to ASCII
	
	#r3 = Memory Location for Dump is
	#r4 = Memory Location where converted contents go
	#r5 = Amount of Bytes to convert
	
	hex_dump_conv:

lis r3, 0x8165
ori r3, r3, 0xFFFF #-1 from 0x81660000
lis r4, 0x8166
ori r4, r4, 0xFFFE #-2 from 0x81670000

li r5, 0x100

li r9, 0

mega_loop:
lbzu r6, 0x1 (r3)

srwi r7, r6, 4
clrlwi r8, r6, 28

cmplwi r7, 0xA
blt- addthirty

addi r7, r7, 0x37
b done_one

addthirty:
addi r7, r7, 0x30

done_one:
slwi r7, r7, 8

cmplwi r8, 0xA
blt- addthirty_again

addi r8, r8, 0x37
b done_two

addthirty_again:
addi r8, r8, 0x30

done_two:
or r7, r7, r8

sthu r7, 0x2 (r4)

addi r9, r9, 1

cmpwi r9, 16
blt+ new_row

li r9, 0
li r6, 0x0A
b store_halfword

new_row:
li r6, 0x20

store_halfword:
stbu r6, 0x2 (r4)
addi r4, r4, -1

subic. r5, r5, 1
bne+ mega_loop

stb r9, 0x2 (r4) #r9 will be 0 at this point. Append Null at end (after final 0x0A) so printf won't continue forever and forever...
	
	#~~~~~~~~~~~~~#
	# Setup Title #
	#~~~~~~~~~~~~~#
	
	bl make_title
	
	#String for the title above the SEEPROM contents
	
	.string "SEEPROM Viewer (v0.7) by Vega.\n\nOriginal seeprom_read code by Team Twiizers.\n\nPress the Home button to return back to HBC.\n\n"
    .align 2
    
    make_title:
    mflr r12
    addi r12, r12, -4 #Buffer of 0x4 due to lwzu 0x4 offset
    
    lis r3, 0x8166 #Setup printf arg
    ori r3, r3, 0xFF84
    
    addi r4, r3, -4 #Buffer of 0x4 due to stwu 0x4 offset
    
    li r6, 31 #31 words (excluding null word created by align 2)
    
    title_loop:
    lwzu r5, 0x4 (r12)
    stwu r5, 0x4 (r4)
    subic. r6, r6, 1
    bne+ title_loop
    
	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
	# Display the Contents onto the Console #
	#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

	crxor 6, 6, 6 #r3 set from earlier
	bl printf
	
.L4:
	bl WPAD_ScanPads
	li 3,0
	bl WPAD_ButtonsDown
	stw 3,8(31)
	lwz 9,8(31)
	rlwinm 9,9,0,24,24
	cmpwi 7,9,0
	beq 7,.L3
	
	#Make quick exiting note on console once Home button is pressed
	bl VIDEO_WaitVSync
	bl exiting_title
	.string "Exiting to HBC..."
	.align 2
	exiting_title:
	mflr r3
	crxor 6, 6, 6
	bl printf
	
	li 3,0
	bl exit
.L3:
	bl VIDEO_WaitVSync
	b .L4
	.cfi_endproc
.LFE64:
	.size	main, .-main
	.ident	"GCC: (devkitPPC release 35) 8.3.0"
