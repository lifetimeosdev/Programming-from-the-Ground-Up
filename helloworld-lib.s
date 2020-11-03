#PURPOSE: This program writes the message "hello world"
#         and exits

 .section .data
helloworld:
 .ascii "hello world\n\0"

 .section .text
 .globl _start
_start:
 pushl $helloworld
 call printf

 push $0
 call exit
