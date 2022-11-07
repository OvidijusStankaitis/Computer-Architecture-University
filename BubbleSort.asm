.model small
.stack 100h

.data

    msg db "This program will bubble sort your input in ascending order based on the ascii value of the element", 0dh, 0ah, 24h
    ;Message that will be printed in the teminal to prompt the user to enter a line of symbols

    change db 255, ?, 255 dup('$')
    ; Input buffer

    newLine db 0dh, 0ah, 24h
    ; New line
    
.code

    start:

        ; Moves data to ax register, and ax to data segment
        mov ax, @data 
        mov ds, ax 

        ; Prints user prompt to enter a text line
        mov dx, offset msg 
        call print

        ; Takes user input
        input:
            mov dx, offset change
            mov ah, 0Ah
            int 21h
            ret

        ; Prints newline
        mov dx, offset newLine
        call print

        ; Count of cycles
        mov cx, 255
        dec cx

        ; Moves to the next element
        next:
            mov bx, cx
            mov si, 0

        ; Compares two elements
        comp:
            mov al, change[si]
            mov dl, change[si + 1]
            cmp al, dl
            jc noswap

        ; Swaps them
        mov change[si], dl
        mov change[si+1], al

        ; Doesn't swap, increments si and decrements bx
        noswap:
            inc si
            dec bx
            jnz comp

        ; Loops 255 times
        loop next

        ; Prints the output
        mov dx, offset change + 2
        call print

        ; Exits
        exit:
            mov ah, 4ch
            mov al, 0
            int 21h  

        ; Print function
        print:
            mov ah, 09h 
            int 21h
            ret

    end start