.model small
.stack 100h

.data 
    ; Message that tells what the program does and prompts the user to enter text
    msg db "Enter text, the program will count the number of symbols in each word: $"

    ; An answer message
    answer db 0dh, 0ah, "The count of symbols in each word from the entered text: $"

    ; Input buffer
    input db 255, ?, 255 dup(?)

    ; Outut buffer
    output db 255*4 dup('$')

.code  
    start:
        ; Adds data to the data segment
        mov ax, @data
        mov ds, ax

        ; Prints msg
        mov dx, offset msg
        call print

        ; Takes user input
        mov dx, offset input
        call inputt

        ; bh - units and bl - tens and ch - hundreds
        mov bh, 0
        mov bl, 0 
        mov ch, 0

        ; di becomes the starting index for the input
        mov di, offset input + 2 

        ; Ittertaes through user input
        iteration:
            ; Moves from data segment to al register
            mov al, ds:[di]
            inc di

            ; Checks for newline, if encounter, the iteration will seize
            cmp al, 13 
            je endIteration

            ; Checks for no space, and counts units if it doesn't encounter one
            cmp al, 32 
            jne count1
            
            ; If all registers are zero, program jumps to next character
            cmp ch, 0
            cmp bl, 0
            cmp bh, 0
            je iteration

            ; Checks if tens and hundreds are zero, and only puts units in the output buffer and resets tens
            cmp ch, 0
            cmp bl, 0
            je jump 

            ; Checks if hundreds are zero
            cmp ch, 0
            je jump2

            ; Hundreds are moved to output buffer
            add ch, 30h
            mov ds:[output + si], ch 
            inc si

        ; Places the count of symbols of words that are shorter than 10 into output buffer and resets bh and bl values
        jump:
            ; Adds 0 to the single digits
            add bh, 30h

            ; Adds units to the output buffer
            mov ds:[output + si], bh
            inc si

            ; Adds space to separete different values
            mov ds:[output + si], 32
            inc si

            ; Reseting the values
            xor ch, ch
            xor bl, bl
            xor bh, bh
            jmp iteration

        ; Places the count of symbols of words that are longer than 10 into output buffer and resets bh and bl values
        jump2:
            ; Adds tens to output buffer
            add bl, 30h
            mov ds:[output + si], bl
            inc si

            ; Adds units to the output buffer
            add bh, 30h
            mov ds:[output + si], bh
            inc si

            ; Adds space to separate different values
            mov ds:[output + si], 32
            inc si

            ; Reseting the values
            xor ch, ch
            xor bl, bl
            xor bh, bh
            jmp iteration

        ; Counter for units
        count1:
            inc bh
            cmp bh, 10
            je count10
            jmp iteration
        
        ; Counter for tens
        count10:
            xor bh, bh
            inc bl
            cmp bl, 10
            je count100
            jmp iteration

        ; Counter for hundreds
        count100:
            xor bl, bl
            inc ch
            jmp iteration

        ; Ends the iteration of the user input
        endIteration:
            cmp ch, 0
            cmp bl, 0
            je singleDigits

            cmp ch, 0
            je mediumDigits

            add ch, 30h
            mov ds:[output + si], ch
            inc si

        ; Places the count of symbols of words that are longer than 10 into output buffer
        mediumDigits:
            add bl, 30h
            mov ds:[output + si], bl
            inc si

        ; Places the count of symbols of words that are shorter than 10 into output buffer
        singleDigits:
            add bh, 30h
            mov ds:[output + si], bh
            inc si
            mov ds:[output + si], 32

        mov dx, offset answer
        call print

        mov dx, offset output
        call print

        ; Exits the program
        exit:
            mov ah, 4ch
            mov al, 0
            int 21h

        ; Print function
        print:
            mov ah, 09h
            int 21h
            ret

        ; User input function
        inputt: 
            mov ah, 0ah
            int 21h
            ret       

    end start