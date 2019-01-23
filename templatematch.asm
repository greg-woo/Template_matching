# WOO
# Greg
# 260777364
.data
displayBuffer:  .space 0x40000 # space for 512x256 bitmap display 
errorBuffer:    .space 0x40000 # space to store match function
templateBuffer: .space 0x100   # space for 8x8 template
imageFileName:    .asciiz "pxlcon512x256cropgs.raw" 
templateFileName: .asciiz "template8x8gs.raw"
# struct bufferInfo { int *buffer, int width, int height, char* filename }
imageBufferInfo:    .word displayBuffer  512 128  imageFileName
errorBufferInfo:    .word errorBuffer    512 128  0
templateBufferInfo: .word templateBuffer 8   8    templateFileName


.text
main:	la $a0, imageBufferInfo
	jal loadImage
	la $a0, templateBufferInfo
	jal loadImage
	la $a0, imageBufferInfo
	la $a1, templateBufferInfo
	la $a2, errorBufferInfo
	jal matchTemplateFast      # MATCHING DONE HERE
	la $a0, errorBufferInfo
	jal findBest
	la $a0, imageBufferInfo
	move $a1, $v0
	jal highlight
	la $a0, errorBufferInfo	
	jal processError
	li $v0, 10		# exit
	syscall
	
# Question Answers
# 1) I find that the base address of the image and the one of the error buffer don't fall in the same block with a direct mapped cache.
# My image base address lands in block 2 and the error's base address lands in block 3.
# 2) We want to avoid as many cache misses as possible in order to avoid having cache miss penalties.
# Therefore, for the matchTemplateFast, it does matter if the template buffer base address falls in the same block.
# However, the change is really negligible.		
##########################################################
# matchTemplate( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplate:	
	addi $sp $sp -36
	sw $ra 0($sp)
	sw $s0 4($sp)
	sw $s1 8($sp)
	sw $s2 12($sp)
	sw $s3 16($sp)
	sw $s4 20($sp)
	sw $s5 24($sp)
	sw $s6 28($sp)
	sw $s7 32($sp)
	
	# s0 = y / s1 = x / s2 = j / s3 = i / s4 = SAD / s5 = I / s6 = T
	
	# en bas c pour calculer y
	#lw $s0 8($a0)# y = height - 7
	#addi $s0 $s0 -7
	addi $s0 $0 0 # init y to 0
	lw $t0 8($a0)# temp y = height - 7
	addi $t0 $t0 -7 # temp y = height - 7
	
	lw $s4 0($a2) # SAD counter(on increment le counter +4 a chaque fois) (utiliser error buffer)
	lw $s5 0($a0) # I address
	lw $s6 0($a1) # T address
	
	addi $t2 $0 8
	
yLoop:
	# reset x
	# en bas c pour calculer x
	#lw $s1 4($a0)# x = width - 7 // CORRECTION x = width
	#addi $s1 $s1 -7
	#addi $t4 $0 7 # use t4 as counter for right side of display
	
	addi $s1 $0 0 # init x to 0
	lw $t1 4($a0)# temp x = width - 7
	addi $t1 $t1 -7 # temp x = width - 7
	
xLoop:
		# reset j
		addi $s2 $0 0 # j = 0
jLoop:
			# reset i
			addi $s3 $0 0 # i = 0
iLoop:
				# fix	
				lw $t7 4($a0) # loading image width
				add $t4 $s0 $s2 # y + j
				mult $t7 $t4 # width * (y+j)
				mflo $t7 # store result of mult in t7
				add $t7 $t7 $s1 # add x
				add $t7 $t7 $s3 # add i
					addi $t3 $0 4 # t3 = 4 (pour multiplier par 4 apres)
				mult $t7 $t3 # multiply sum by 4
				mflo $t7
				la $t3 0($s5) # load I
				add $t7 $t7 $t3 # add base address (t3 instead of s5)			
				#end fix
				
				lbu $t5 0($t7) # load I
				lbu $t6 0($s6) # load T
				sub $t5 $t5 $t6 # I - T
	
				sra $t6 $t5 31 # ABS
				xor $t5 $t5 $t6 # ABS
				sub $t5 $t5 $t6 # ABS
				#t5 now contains the absolute value of t5
	
				lw $t6 0($s4) # load SAD in t3
				add $t6 $t6 $t5
				sw $t6 0($s4) # SAD = abs etc...
	
				addi $s3 $s3 1 # i ++
				beq $s3 $t2 iDone # if i = 8 then go to iDone
				#addi $s5 $s5 4 # else I update
				addi $s6 $s6 4 # T update
				j iLoop # go back to loop
	
iDone:			addi $s2 $s2 1# j ++
			beq $s2 $t2 jDone # if j = 8 then go to jDone
			#addi $s5 $s5 4 # else I update
			addi $s6 $s6 4 # T update
			j jLoop

xRightEdge:
		addi $s4 $s4 28 # SAD update
		#addi $t4 $t4 -1
		j xDone
jDone:
		addi $s1 $s1 1# x ++
		beq $s1 $t1 xRightEdge # if x = width - 7 then go to xDone
		#beq $s1 $t4 xRightEdge
		#addi $s5 $s5 -0xF4 # reset I to - (8*8*4 - 4)
		lw $s6 0($a1) # reset T
		addi $s4 $s4 4 # SAD update
		j xLoop
	
xDone:	
	addi $s0 $s0 1# y ++
	beq $s0 $t0 endLoop1 # if y = 0 then go to jDone
	#addi $s5 $s5 -0xF4 # reset I to - (8*8*4 - 4) -244 / -32,316
	lw $s6 0($a1) # reset T
	addi $s4 $s4 4 # SAD update
	j yLoop
	
endLoop1:
	move $t0 $0
	move $t1 $0
	move $t2 $0
	move $t3 $0
	move $t4 $0
	move $t5 $0
	move $t6 $0
	move $t7 $0

	lw $ra 0($sp)
	lw $s0 4($sp)
	lw $s1 8($sp)
	lw $s2 12($sp)
	lw $s3 16($sp)
	lw $s4 20($sp)
	lw $s5 24($sp)
	lw $s6 28($sp)
	lw $s7 32($sp)
	addi $sp $sp 36
	
	jr $ra	
	
##########################################################
# matchTemplateFast( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
      matchTemplateFast:	
	addi $sp $sp -40
	sw $ra 0($sp)
	sw $s0 4($sp)
	sw $s1 8($sp)
	sw $s2 12($sp)
	sw $s3 16($sp)
	sw $s4 20($sp)
	sw $s5 24($sp)
	sw $s6 28($sp)
	sw $s7 32($sp)
	
	# s0 = y / s1 = x / s2 = j / s3 = i / s4 = SAD / s5 = I / s6 = T

	#lw $a3 0($a2) # SAD counter(on increment le counter +4 a chaque fois) (utiliser error buffer)
	
	
	lw $s4 8($a0) # height
	addi $s4 $s4 -7 # height - 7 
	lw $s5 0($a0) # I address
	lw $t0 0($a1) # T address
	#TEST FOR QUESTIONS
	#la $t2 0($s5) # I base address
	#lw $t1 0($a2) # SAD address
	#la $t3 0($t1) # SAD base address
			
	# reset j
	addi $s2 $0 0 # j = 0
	
jLoop2:
	addi $s0 $0 0 # init y = 0
	sw $t0 36($sp)
	
 	lbu $t1 4($t0) # int t1 = T[1][j];
  	lbu $t2 8($t0) # int t2 = T[2][j];
  	lbu $t3 12($t0) # int t3 = T[3][j];
  	lbu $t4 16($t0) # int t4 = T[4][j];
  	lbu $t5 20($t0) # int t5 = T[5][j];
  	lbu $t6 24($t0) # int t6 = T[6][j];
   	lbu $t7 28($t0) # int t7 = T[7][j];
	lbu $t0 0($t0) # int t0 = T[0][j];
	
	
	
yLoop2:
		addi $s1 $0 0 # x = 0		
xLoop2:
				lw $s3 4($a0) # width
				# CALCULER SAD t9 / s4
				mult $s0 $s3 # width * y
				mflo $t9 # store result of mult in t8
				add $t9 $t9 $s1 # add x
				sll $t9 $t9 2 # multiply by 4
				lw $s4 0($a2) # SAD base address
				add $t9 $t9 $s4 # add base address and calcul
				
				lw $s4 0($t9) # SAD (x,y) in s4
				
				# CALCULER I t8 / s7
				add $t8 $s0 $s2 # y + j
				mult $t8 $s3 # width * (y+j)
				mflo $t8 # store result of mult in t8
				add $t8 $t8 $s1 # add x
				sll $t8 $t8 2 # multiply by 4
				la $s3 0($s5) # I base address
				add $t8 $t8 $s3 # add calcul and base address
				
				########## t0
				lbu $s7 0($t8) # load I
				sub $s7 $s7 $t0 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7	
				
				########## t1
				lbu $s7 4($t8) # load I
				sub $s7 $s7 $t1 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7
				
				########## t2
				lbu $s7 8($t8) # load I
				sub $s7 $s7 $t2 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7
				
				########## t3
				lbu $s7 12($t8) # load I
				sub $s7 $s7 $t3 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7
				
				########## t4
				lbu $s7 16($t8) # load I
				sub $s7 $s7 $t4 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7
				
				########## t5
				lbu $s7 20($t8) # load I
				sub $s7 $s7 $t5 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7
				
				########## t6
				lbu $s7 24($t8) # load I
				sub $s7 $s7 $t6 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7
				
				########## t7
				lbu $s7 28($t8) # load I
				sub $s7 $s7 $t7 # I - T XXXX a changer a chaque fois
				abs $s7 $s7 # abs value of t8
				add $s4 $s4 $s7
				
				sw $s4 0($t9) # store SAD
				j iDone2

iDone2:
			addi $s1 $s1 1# x ++
			lw $s3 4($a0) # width
			addi $s3 $s3 -7
			#addi $s3 $s3 249
			beq $s1 $s3 xDone2 # if x = width - 7
			j xLoop2
xDone2:		
		addi $s0 $s0 1# y ++
		lw $s4 8($a0) # height
		addi $s4 $s4 -7 # height - 7 
		#addi $s4 $s4 505 # height - 7 
		beq $s0 $s4 yDone2 # if y = height -7
		j yLoop2
yDone2:	
	addi $s2 $s2 1# j ++
	addi $t9 $0 8
	beq $s2 $t9 endLoop2 # if j = 8 then go to jDone
	lw $t0 36($sp)
	addi $t0 $t0 32 # T update
	j jLoop2
endLoop2:
	move $t0 $0
	move $t1 $0
	move $t2 $0
	move $t3 $0
	move $t4 $0
	move $t5 $0
	move $t6 $0
	move $t7 $0
	move $t8 $0
	move $t9 $0

	lw $ra 0($sp)
	lw $s0 4($sp)
	lw $s1 8($sp)
	lw $s2 12($sp)
	lw $s3 16($sp)
	lw $s4 20($sp)
	lw $s5 24($sp)
	lw $s6 28($sp)
	lw $s7 32($sp)
	addi $sp $sp 40
	
	jr $ra
###############################################################
# loadImage( bufferInfo* imageBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
loadImage:	lw $a3, 0($a0)  # int* buffer
		lw $a1, 4($a0)  # int width
		lw $a2, 8($a0)  # int height
		lw $a0, 12($a0) # char* filename
		mul $t0, $a1, $a2 # words to read (width x height) in a2
		sll $t0, $t0, 2	  # multiply by 4 to get bytes to read
		li $a1, 0     # flags (0: read, 1: write)
		li $a2, 0     # mode (unused)
		li $v0, 13    # open file, $a0 is null-terminated string of file name
		syscall
		move $a0, $v0     # file descriptor (negative if error) as argument for read
  		move $a1, $a3     # address of buffer to which to write
		move $a2, $t0	  # number of bytes to read
		li  $v0, 14       # system call for read from file
		syscall           # read from file
        		# $v0 contains number of characters read (0 if end-of-file, negative if error).
        		# We'll assume that we do not need to be checking for errors!
		# Note, the bitmap display doesn't update properly on load, 
		# so let's go touch each memory address to refresh it!
		move $t0, $a3	   # start address
		add $t1, $a3, $a2  # end address
loadloop:	lw $t2, ($t0)
		sw $t2, ($t0)
		addi $t0, $t0, 4
		bne $t0, $t1, loadloop
		jr $ra
		
		
#####################################################
# (offset, score) = findBest( bufferInfo errorBuffer )
# Returns the address offset and score of the best match in the error Buffer
findBest:	lw $t0, 0($a0)     # load error buffer start address	
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		li $v0, 0		# address of best match	
		li $v1, 0xffffffff 	# score of best match	
		lw $a1, 4($a0)    # load width
        		addi $a1, $a1, -7 # initialize column count to 7 less than width to account for template
fbLoop:		lw $t9, 0($t0)        # score
		sltu $t8, $t9, $v1    # better than best so far?
		beq $t8, $zero, notBest
		move $v0, $t0
		move $v1, $t9
notBest:		addi $a1, $a1, -1
		bne $a1, $0, fbNotEOL # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
fbNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, fbLoop
		lw $t0, 0($a0)     # load error buffer start address	
		sub $v0, $v0, $t0  # return the offset rather than the address
		jr $ra
		

#####################################################
# highlight( bufferInfo imageBuffer, int offset )
# Applies green mask on all pixels in an 8x8 region
# starting at the provided addr.
highlight:	lw $t0, 0($a0)     # load image buffer start address
		add $a1, $a1, $t0  # add start address to offset
		lw $t0, 4($a0) 	# width
		sll $t0, $t0, 2	
		li $a2, 0xff00 	# highlight green
		li $t9, 8	# loop over rows
highlightLoop:	lw $t3, 0($a1)		# inner loop completely unrolled	
		and $t3, $t3, $a2
		sw $t3, 0($a1)
		lw $t3, 4($a1)
		and $t3, $t3, $a2
		sw $t3, 4($a1)
		lw $t3, 8($a1)
		and $t3, $t3, $a2
		sw $t3, 8($a1)
		lw $t3, 12($a1)
		and $t3, $t3, $a2
		sw $t3, 12($a1)
		lw $t3, 16($a1)
		and $t3, $t3, $a2
		sw $t3, 16($a1)
		lw $t3, 20($a1)
		and $t3, $t3, $a2
		sw $t3, 20($a1)
		lw $t3, 24($a1)
		and $t3, $t3, $a2
		sw $t3, 24($a1)
		lw $t3, 28($a1)
		and $t3, $t3, $a2
		sw $t3, 28($a1)
		add $a1, $a1, $t0	# increment address to next row	
		add $t9, $t9, -1		# decrement row count
		bne $t9, $zero, highlightLoop
		jr $ra

######################################################
# processError( bufferInfo error )
# Remaps scores in the entire error buffer. The best score, zero, 
# will be bright green (0xff), and errors bigger than 0x4000 will
# be black.  This is done by shifting the error by 5 bits, clamping
# anything bigger than 0xff and then subtracting this from 0xff.
processError:	lw $t0, 0($a0)     # load error buffer start address
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		lw $a1, 4($a0)     # load width as column counter
        		addi $a1, $a1, -7  # initialize column count to 7 less than width to account for template
pebLoop:		lw $v0, 0($t0)        # score
		srl $v0, $v0, 5       # reduce magnitude 
		slti $t2, $v0, 0x100  # clamp?
		bne  $t2, $zero, skipClamp
		li $v0, 0xff          # clamp!
skipClamp:	li $t2, 0xff	      # invert to make a score
		sub $v0, $t2, $v0
		sll $v0, $v0, 8       # shift it up into the green
		sw $v0, 0($t0)
		addi $a1, $a1, -1        # decrement column counter	
		bne $a1, $0, pebNotEOL   # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width to reset column counter
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
pebNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, pebLoop
		jr $ra
