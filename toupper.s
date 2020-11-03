#PURPOSE: This program converts an input file
#         to an output file with all letters
#         converted to uppercase.

#PROCESSING: 1)	open the input file
#	     2) open the output file
#            3) while we're not at the end of the input file
#		a) read part of file into our memory buffer
#               b) go through each byte of memory if the
#		   byte is a lower-case letter, convert it 
#	           to uppercase
#		c) write the memory buffer to output file

.section .data

######CONSTANTS######

#system call numbers
.equ SYS_OPEN, 5
.equ SYS_WRITE, 4
.equ SYS_READ, 3
.equ SYS_CLOSE, 6
.equ SYS_EXIT, 1

#options for open (look at 
#/usr/include/asm/fcntl.h for
#various values. You can combine them 
#by adding them or ORing them)
#This is discussed at greater length
#in "Counting Like a Computer"
.equ O_RDONLY, 0
.equ O_CREATE_WRONLY_TRUNC, 03101

#standard file descriptors
.equ STDIN, 0
.equ STDOUT, 1
.equ STDERR, 2

#system call interrupt
.equ LINUX_SYSCALL, 0x80
.equ END_OF_FILE, 0        #This is the return value 
			   #of read which means we've
			   #hit the end of the file

.equ NUMBER_ARGUMENTS, 2

.section .bss
#Buffer - this is where the data is loaded into
#	  from the data file and written from
# 	  into the output file. This should
#	  never exceed 16000 for various reasons.
.equ BUFFER_SIZE, 500
.lcomm BUFFER_DATA, BUFFER_SIZE

.section .text

#STACK POSITIONS
.equ ST_SIZE_RESERVE, 8
.equ ST_FD_IN, -4
.equ ST_FD_OUT, -8
.equ ST_ARGC, 0       #Number of arguments
.equ ST_ARGV_0, 4     #Name of program
.equ ST_ARGV_1, 8     #Input file name
.equ ST_ARGV_2, 12    #Output file name

.globl _start
_start:
###INITIALIZE PROGRAM###
#save the stack pointer
movl %esp, %ebp

#Allocate space for our file descriptors on the stack
subl $ST_SIZE_RESERVE, %esp

open_files:
open_fd_in:
###OPEN INPUT FILE###
movl $SYS_OPEN, %eax              #open syscall
movl ST_ARGV_1(%ebp), %ebx        #input filename into %ebx
movl $O_RDONLY, %ecx              #read-only flag
movl $0666, %edx                  #this doesn't really matter for reading 
int $LINUX_SYSCALL                #call Linux

store_fd_in:
movl %eax, ST_FD_IN(%ebp)         #save the given file descriptor

open_fd_out:
###OPEN OUTPUT FILE###
movl $SYS_OPEN, %eax             #open the file
movl ST_ARGV_2(%ebp), %ebx        #output filename into %ebx
movl $O_CREATE_WRONLY_TRUNC, %ecx #flags for writing to the file
movl $0666, %edx                  #mode for new file (if it's created)
int $LINUX_SYSCALL                #call Linux

strore_fd_out:
movl %eax, ST_FD_OUT(%ebp)        #save the file descriptor here

###BEGIN MAIN LOOP###
read_loop_begin:

#READ IN A BLOCK FROM THE INPUT FILE###
movl $SYS_READ, %eax
movl ST_FD_IN(%ebp), %ebx         #get the input file descriptor 
movl $BUFFER_DATA, %ecx           #the location to read into
movl $BUFFER_SIZE, %edx           #the size of the buffer
int $LINUX_SYSCALL                #Size of buffer read is returned in %eax

###EXIT IF WE'VE REACHED THE END###
cmpl $END_OF_FILE, %eax           #check for end of file marker
jle end_loop                      #if found or on error,go to the end

continue_read_loop:
###CONVERT THE BLOCK TO UPPER CASE###
pushl $BUFFER_DATA                #location of buffer
pushl %eax                        #size of the buffer
call convert_to_upper
popl %eax                         #get the size back
addl $4, %esp                     #restore %esp

###WRITE THE BLOCK OUT TO THE OUTPUT FILE###
movl %eax, %edx                   #size of the buffer
movl $SYS_WRITE, %eax             
movl ST_FD_OUT(%ebp), %ebx        #file to use
movl $BUFFER_DATA, %ecx           #location of the buffer
int $LINUX_SYSCALL

###CONTINUE THE LOOP###
jmp read_loop_begin

end_loop:
###CLOSE THE FILES###
#NOTE - we don't need to do error checking 
#       on these, because error confitions
#       don't signify anything special here
movl $SYS_CLOSE, %eax
movl ST_FD_OUT(%ebp), %ebx
int $LINUX_SYSCALL

movl $SYS_CLOSE, %eax
movl ST_FD_IN(%ebp), %ebx
int $LINUX_SYSCALL

###EXIT###
movl $SYS_EXIT, %eax
movl $0, %ebx
int $LINUX_SYSCALL

#PURPOSE: This function actually does the 
#         conversion to upper case for a block
#	  
#INPUT:   The first parameter is the location 
#	  of the block of memory to convert
#         The second parameter is the length of that buffer
#
#OUTPUT:  This function overwrites the current
#         buffer with the upper-casified version
#VARIABLES:
#	  %eax - beginning of buffer
# 	  %ebx - length of buffer
#	  %edi - current buffer offset
#	  %cl  - current byte being examined
#	         (first part of %ecx)
#
###CONSTANTS##
.equ LOWERCASE_A, 'a'       #The lower boundary of our search
.equ LOWERCASE_Z, 'z'	    #The upper boundary of our search
.equ UPPER_CONVERSION, 'A' - 'a'  #Conversion between upper and lower case

###STACK STUFF###
.equ ST_BUFFER_LEN, 8       #Length of buffer
.equ ST_BUFFER, 12          #actual buffer
convert_to_upper:
pushl %ebp
movl %esp, %ebp

###SET UP VARIABLES###
movl ST_BUFFER(%ebp), %eax
movl ST_BUFFER_LEN(%ebp), %ebx
movl $0, %edi
cmpl $0, %ebx               #if a buffer with zero length was given
			    #to us, just leave
je end_convert_loop

convert_loop:
movb (%eax,%edi,1), %cl     #get the current byte

cmpb $LOWERCASE_A, %cl      #go to the next byte unless it is between
			    #'a' and 'z'
jl next_byte
cmpb $LOWERCASE_Z, %cl      
jg next_byte

addb $UPPER_CONVERSION, %cl  #otherwise convert the byte to uppercase
movb %cl, (%eax,%edi,1)      #and store it back

next_byte:
 incl %edi                   #next byte
 cmpl %edi, %ebx             #continue unless we've reachd the end
 jne convert_loop

end_convert_loop:
#no return value,just leave
movl %ebp, %esp
popl %ebp
ret




