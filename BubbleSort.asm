.model small
.stack 100h

.data

    ;Message that will be printed in the teminal to prompt the user to enter a line of symbols
    msg db "This program will bubble sort your input in ascending order based on the ascii value of the element", 0dh, 0ah, 24h

    ; Input buffer
    change db 255, ?, 255 dup('$')

    ; New line
    newLine db 0dh, 0ah, 24h
    
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

        ; Prints newline
        mov dx, offset newLine
        call print

        ; How many times the loop will iterate
        xor cx, cx
        mov cl, [change + 1]
        jcxz exit
        xor bx, bx

        ; Loop that compares and swaps the elements
        comp:
            comp2:
                mov al, ds:[change + 2 + cx]
                mov dl, ds:[change + 2 + bx]
                cmp al, dl
                
                mov ds:[change + 2 + cx], dl
                mov ds:[change + 2 + bx], al

                inc bx

            loop comp2

            xor bx, bx

        loop comp

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