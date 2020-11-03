#PURPOSE: Count the characters until a null byte is reached.
#INPUT: The address of the character string
#OUTPUT: Returna the count in %eax

#PROCESS: 
#	Registers used:
#		%ecx - character count
#		%al - current character
#		%edx - current character address
.type count_chars, @function
.globl count_chars

#This is where our one parameter is on the stack
.equ ST_STRING_START_ADDRESS, 8
count_chars:
 pushl %ebp
 movl %esp, %ebp

 movl $0, %ecx		 #Counter starts at zero
 movl ST_STRING_START_ADDRESS(%ebp), %edx #Starting address of data

count_loop_begin:
 movb (%edx), %al        #Grab the current character
 cmpb $0, %al            #Is it null?
 je count_loop_end       #If yes, we're done
 incl %ecx               #Otherwise, increment the counter and the pointer
 incl %edx
 jmp count_loop_begin    #Go back to the beginning of the loop
 
count_loop_end:
 movl %ecx, %eax         #We're done.Move the count into %eax

 popl %ebp
 ret

