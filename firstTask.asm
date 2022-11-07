.model small
.stack 100h

.data

    msg db "This program will sort your input in ascending order based on the ascii value of the element$" 
    ;Message that will be printed in the teminal to prompt the user to enter a line of symbols

    change db ?
    ;Variable to hold user input and later print it out
    
.code

    start:

        mov ax, @data ;Moves data to ax register
        mov ds, ax ;Moves data stored in ax rester to data segment

        lea dx, msg
        mov ah, 09h ;Prints a message that is specified by the dx offset
        int 21h

        mov ah, 4ch           
        mov al, 0     
        int 21h

    end start