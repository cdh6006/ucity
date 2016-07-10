;###############################################################################
;
;    BitCity - City building game for Game Boy Color.
;    Copyright (C) 2016 Antonio Nino Diaz (AntonioND/SkyLyrac)
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;    Contact: antonio_nd@outlook.com
;
;###############################################################################

    INCLUDE "hardware.inc"
    INCLUDE "engine.inc"

;-------------------------------------------------------------------------------

    INCLUDE "text_messages.inc"

;###############################################################################

    SECTION "Text Messages Functions",ROMX,BANK[ROM_BANK_TEXT_MSG]

;-------------------------------------------------------------------------------

CURINDEX SET 0

MSG_SET_INDEX : MACRO ; 1 = Index
    IF (\1) < CURINDEX ; check if going backwards and stop if so
        FAIL "ERROR : text_messages.asm : Index already in use!"
    ENDC
    IF (\1) > CURINDEX ; If there's a hole to fill, fill it
        REPT (\1) - CURINDEX
            DW $0000
        ENDR
    ENDC
CURINDEX SET (\1)
ENDM

MSG_ADD : MACRO ; 1=Name of label where the text is
    MSG_SET_INDEX ID_\1
    DW  \1
CURINDEX SET CURINDEX + 1
ENDM

;-------------------------------------------------------------------------------

; Labels should be named MSG_xxxx and IDs should be named ID_MSG_xxxx

MSG_EMPTY:
    DB $00

MSG_POLLUTION_HIGH:
    DB "Pollution is too high!",$00

;-------------------------------------------------------------------------------

MSG_POINTERS: ; Array of pointer to messages. LSB first
    MSG_ADD  MSG_EMPTY
    MSG_ADD  MSG_POLLUTION_HIGH

;###############################################################################

    SECTION "Text Messages Variables",WRAM0

;-------------------------------------------------------------------------------

MSG_QUEUE_DEPTH EQU 16 ; must be a power of 2

msg_stack:   DS MSG_QUEUE_DEPTH ; emtpy elements must be set to 0
msg_in_ptr:  DS 1
msg_out_ptr: DS 1

;###############################################################################

    SECTION "Text Messages Functions Bank 0",ROM0

;-------------------------------------------------------------------------------

MessageRequestAdd:: ; a = message ID to show

    ld      c,a ; (*) save ID

    ; Check if this message is already in the queue

    ld      hl,msg_stack
    ld      b,MSG_QUEUE_DEPTH
.loop:
    ld      a,[hl+]
    cp      a,c
    ret     z

    dec     b
    jr      nz,.loop

    ; Check if there is space to save another message

    ld      a,[msg_in_ptr]
    ld      hl,msg_stack
    ld      e,a
    ld      d,0
    add     hl,de

    ld      a,[hl]
    and     a,a ; if the next slot is 0, there's free space
    jr      z,.free_space

        ld      b,b ; Panic!
        ret

.free_space:

    ; Add message to the queue

    ld      a,[msg_in_ptr]
    ld      hl,msg_stack
    ld      e,a
    ld      d,0
    add     hl,de

    ld      [hl],c ; (*) save ID to queue

    inc     a
    and     a,MSG_QUEUE_DEPTH-1 ; wrap around
    ld      [msg_in_ptr],a

    ret

;-------------------------------------------------------------------------------

MessageRequestGet:: ; returns a = message ID to show

    ; Check if there are messages left, and return the first one if so

    ld      a,[msg_out_ptr]
    ld      hl,msg_stack
    ld      e,a
    ld      d,0
    add     hl,de

    ld      a,[hl]
    and     a,a
    ret     z ; return 0 if the message is 0

    ; Clear slot

    ld      [hl],0

    ; Increase out pointer

    ld      c,a ; preserve message ID

    ld      a,[msg_out_ptr]
    inc     a
    and     a,MSG_QUEUE_DEPTH-1 ; wrap around
    ld      [msg_out_ptr],a

    ld      a,c ; return message ID

    ret

;-------------------------------------------------------------------------------

MessageRequestGetPointer:: ; a = message ID, returns hl = pointer to message

    ld      e,a
    ld      d,0
    ld      hl,MSG_POINTERS
    add     hl,de
    add     hl,de

    ld      a,[hl+] ; LSB first
    ld      h,[hl]
    ld      l,a

    ret

;###############################################################################