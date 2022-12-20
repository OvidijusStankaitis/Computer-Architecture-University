# Computer Architecture

In this repository I'm keeping my assembler programming projects.

```asm
; Life Motto

.model small
.stack 100h

.data
    msg db "Be Awesome!!!", 0Dh,0Ah, 24h

.code

start:
    mov dx, @data          
    mov ds, dx                    

    mov ah, 09h
    mov dx, offset msg
    int 21h

    mov ah, 4ch          
    mov al, 0     
    int 21h              
end start
```

To compile I'm using tasm.
