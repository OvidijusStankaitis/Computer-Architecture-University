# Computer Architecture

In this repository I'm keeping my assembler programming projects.

```asm
; Life motto
name "hi"

org 100h

jmp start       

msg:    db      "Be awesome!!!", 0Dh,0Ah, 24h

start:  mov     dx, msg  ;
        mov     ah, 09h  
        int     21h      
        
        mov     ah, 0 
        int     16h     
        
ret
```