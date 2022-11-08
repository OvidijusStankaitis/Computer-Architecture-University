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

        ; bh - units and bl - tens
        mov bh, 0
        mov bl, 0 

        ; di becomes the starting index for the input
        mov di, offset input + 2 

        ; Ittertaes through user input
        iteration:
            ; Moves from data segment to al register
            mov al, ds:[di]
            inc di

            ; Checks for newline, if encounter, the iteration will seize
            CMP al, 13 
            JE endIteration

            ; Checks for no space, and counts units if it doesn't encounter one
            CMP al, 32 
            JNE count1
            
            ; If both registers are zero, program jumps to next character
            CMP bl, 0
            CMP bh, 0
            JE iteration

            ; Checks if tens are zero, and only puts units in the output buffer and resets tens
            CMP bl, 0
            JE jump 

            ; Tens are moved to output buffer
            ADD bl, 30h
            mov ds:[output + si], bl 
            inc si

        ; Places the count of symbols of words that are shorter than 10 into output buffer and resets bh and bl values
        jump:
            ; Adds 0 to the single digits
            ADD bh, 30h

            ; Adds units to the output buffer
            mov ds:[output + si], bh
            inc si

            ; Adds space to separete different values
            mov ds:[output + si], 32
            inc si

            ; Reseting the values
            XOR bh, bh
            XOR bl, bl
            JMP iteration

        ; Checks if units exceed 9 and adds them to the tens register
        count1: 
            inc bh
            CMP bh, 10
            JE count10
            JMP iteration
            
        ; Units are reset grow by one
        count10:
            XOR bh, bh
            inc bl
            JMP iteration

        ; Ends the iteration of the user input
        endIteration:
            CMP bl, 0
            JE singleDigits

            ADD bl, 30h
            mov ds:[output + si], bl
            inc si

        ; Places the count of symbols of words that are shorter than 10 into output buffer
        singleDigits:
            ADD bh, 30h

            ; Adds units to the output buffer
            mov ds:[output + si], bh
            inc si
            
            ; Adds space to separete different values
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