#Program czyta plik .BMP zawierający obraz zapisany w formacie 1, 2 lub 4 bpp (jeden
#format do wyboru) i wyświetla górny lewy róg obrazu (max. 64×24 piksele) na konsoli
#używając do reprezentacji poszczególnych pikseli pojedynczych znaków ASCII. Program
#musi poprawnej obsługiwać pliki zawierające obrazy o dowolnej rozdzielczości, również
#mniejszej od 64×24.
#Wybrane BPP: 4

#registers used in this portio:
#a0 - used for calls
#a1 - used for calls 
#a2 - used for calls
#a3 - image width
#a4 - image height
#a5 - width to process
#a6 - heght to process

#a7 - call number
#t0 - contains the bmp file's descriptor before the bitmap's loaded in
#t1 - bpp(should be 4)
#t2 - offset
#t3 - pointer to heap memory
#t4 - current line number
#t5 - current column number
#t6 - stores current byte

#s0 - size of the file, used for 
#s1 - stores current byte
#s2 - left pixel in byte
#s3 - right pixel in byte
#s4 - relative address of leftmost byte in the current line
#s5 - header, afterwards the bitmap
#s7 - buffer containing signs from the currently processed line
#s8 - contains newline

	.eqv 	PRTSTR, 4
	.eqv	INSTR, 8
	.eqv	SBRK, 9
	.eqv	EXIT0, 10
	.eqv	PRTCHAR, 11
	.eqv	CLOSE, 57
	.eqv	LSEEK, 62
	.eqv	READ, 63
	.eqv	OPENFILE, 1024

	.data			
bitmap:	.space  15000			#buffer, header then bitmap
fname:	.space	128
line:	.space  66


#file_name:.asciz	"ninth.bmp"
start_msg:.asciz	"enter the file name\n"
DIB_debug:.asciz	"File has a DIB size different than 40 - unsupported."
filename_debug:.asciz "File not found- please double check the spelling."
bpp_debug:.asciz	"Unsupported bpp value - please use files with 4bpp."

	.text
main:
	la	a0, start_msg
	li	a7, PRTSTR
	ecall
	
	la	a0, fname
	li	a1, 128
	li	a7, INSTR
	ecall				#file selection

	
	mv	a2, a0
	li	s8, '\n'
	
remove_newline:
	lbu	t1, (a2)
	addi	a2, a2, 1
	bne	t1, s8, remove_newline
	sb	zero, -1(a2)
	
	la	a0, fname
	li	a1, 0
	li	a7, OPENFILE		
	ecall				#file opened
	bltz	a0, file_error
	mv	t0, a0			#descriptor saved

	mv	a0, t0
	la	a1, bitmap
	li	a2, 2			#first 2 bytes - just mark the file as .bmp
	li	a7, READ
	ecall				#skipped - they're useless to us, loaded first to prevent alingment issues
	
	mv	a0, t0
	la	a1, bitmap
	li	a2, 12
	li	a7, READ
	ecall				#next 12 bytes of the header loaded in, also of no interest.
	
	lw	s1, 8(a1)
	
	mv	a0, t0
	la	a1, bitmap
	li	a2, 40
	li	a7, READ
	ecall					#part of DIB header loaded in
	
	lw	a3, 4(a1)			#load width
	lw	a4, 8(a1)			#load height	
	lh	t1, 14(a1)			#load bpp
	li	a0, 4
	bne	a0, t1, bpp_error
	lw	t2, 20(a1)			#bitmap size
	
	mv	a0, t0
	mv	a1, s1
	li	a2, 0
	li	a7, LSEEK
	ecall					#skip through offset
	
	mv	a0, t2				#load size
	li	a7, SBRK
	ecall					#load in bitmap
	
	mv	t3, a0
	
	
	mv	a0, t0
	mv	a1, t3
	mv	a2, t2
	li	a7, READ
	ecall
	
	mv	a0, t0
	li	a7, CLOSE
	ecall
	
	mv	t0, t3
	
	li	a5, 64				#default width
	li	a6, 24				#default height
	
	bleu	a5, a3, check_width		#skip reassigning a5 if img width is at least 64
	mv	a5, a3

check_width:

	bleu	a6, a4, calc_stride 		#skip reassigning a6 if img height is at least 24
	mv	a6, a4

calc_stride:
	
	mv	t2, a3				#stride = (image_width_in_pixels * bits_per_pixel + 31) / 32 * 4
	slli	t2, t2, 2			#bpp is 4, so left bitshift by 2 -> * bits_per pixel
	addi	t2, t2, 31			
	srli	t2, t2, 5			#right shift by 5 is the same as dividing by 32
	slli	t2, t2, 2			#left shift by 2 is the same as multiplying by 4
	
	mv	t4, zero
	mv	t4, a3					#we start from the top - y = max
	mv	t5, zero				#we start from the left - x = 0

#registers used in this portion:
#a0 - used for calls
#a1 - used for calls 
#a2 - used for calls	
#a3 - image width
#a4 - image height
#a5 - width to process per row
#a6 - total height to process
#a7 - call number
#t0 - pointer to the start of the heap
#t1 - pointer to current byte
#t2 - stride
#t3 - stride - width per line
#t4 - x to process
#t5 - y to process
#s1 - stores current byte
#s2 - left pixel in byte
#s3 - right pixel in byte
#s5 - header, afterwards the bitmap
#s6 - relative address of current byte
#s7 - buffer containing signs from the currently processed line
#s8 - contains newline sign
#s11 - pointer to start of new line

	la	s11, line
	mul	t1, a4, t2			#distance to (y,0)
	add	t0, t0, t1			#bitmap set to (y,0)
	mv	t5, a6				#counter set to 24 or the amount of lines, whichever is smaller
	srli	s9, t4, 1			#divide x by 2
	
line_loop:
	sub	t0, t0, t2			#go down 1 line
	mv	s7, s11
	mv	t4, a5
	
column_loop:					#1 iteration per x coord in y coord	
#returns value of byte with the following coords:
#heap - t0
#other used registers:
#t1, t3, t6
	
	lbu 	s1,(t0)				#load byte

	srli	s2, s1, 4			#shifting right to remove the right 4 bits and put the left 4 bits in their place
	addi	s2, s2, 'A'

	andi	s3, s1, 15			#and with 1111 - will remove the leftmost 4 bytes
	addi	s3, s3, 'A'

	
	addi	t4, t4, -1			#decrement width counter by 1 per pixel
	sb	s2, (s7)
	addi	s7, s7, 1
	beqz	t4, display_line
	addi	t4, t4, -1			#decrement width counter by 1 per pixel
	sb	s3, (s7)
	addi	s7, s7, 1
	addi	t0, t0, 1
	
	bnez	 t4, column_loop			#continue loop


display_line:
	sb	s8, (s7)
	addi	s7, s7, 1
	sb	zero, (s7)
	
	la	a0, line
	li	a7, PRTSTR
	ecall
	
	addi	t5, t5, -1
	sub	t0, t0, s9			#move the pointer back to the start of the line
	bnez	t5, line_loop


end:	
	li	a7, 10				#exit with code 0
	ecall

file_error:
	la	a0, filename_debug
	li	a7, PRTSTR
	ecall
	j	end

bpp_error:
	la	a0, bpp_debug
	li	a7, PRTSTR
	ecall
	j	end

