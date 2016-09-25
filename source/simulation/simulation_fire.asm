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

    INCLUDE "room_game.inc"
    INCLUDE "tileset_info.inc"

;###############################################################################

    SECTION "Fire Helper Variables",HRAM

;-------------------------------------------------------------------------------

; For a map created by a sane person this should reasonably be 1-16 (?) but it
; can actually go over 255, so the count saturates to 255.
initial_number_fire_stations: DS 1

;###############################################################################

    SECTION "Simulation Fire Functions",ROMX

;-------------------------------------------------------------------------------

Simulation_FireExpand: ; e = x, d = y, hl = address

    ; Up

    xor     a,a
    cp      a,d
    jr      z,.skip_up
        push    hl
        push    de

        ld      de,-CITY_MAP_WIDTH
        add     hl,de

        ; Returns: - Tile -> Register DE
        call    CityMapGetTileAtAddress ; hl = address. Preserves BC and HL

        push    hl
        call    CityTileFireProbability ; de = tile, returns d = probability
        pop     hl

        ld      a,BANK_SCRATCH_RAM
        ld      [rSVBK],a

        ld      a,d
        add     a,[hl]
        jr      nc,.not_overflowed_up
        ld      a,255
.not_overflowed_up:
        ld      [hl],a

        pop     de
        pop     hl
.skip_up:

    ; Down

    ld      a,CITY_MAP_HEIGHT-1
    cp      a,d
    jr      z,.skip_down
        push    hl
        push    de

        ld      de,+CITY_MAP_WIDTH
        add     hl,de

        ; Returns: - Tile -> Register DE
        call    CityMapGetTileAtAddress ; hl = address. Preserves BC and HL

        push    hl
        call    CityTileFireProbability ; de = tile, returns d = probability
        pop     hl

        ld      a,BANK_SCRATCH_RAM
        ld      [rSVBK],a

        ld      a,d
        add     a,[hl]
        jr      nc,.not_overflowed_down
        ld      a,255
.not_overflowed_down:
        ld      [hl],a

        pop     de
        pop     hl
.skip_down:

    ; Left

    xor     a,a
    cp      a,e
    jr      z,.skip_left
        push    hl
        push    de

        dec     hl

        ; Returns: - Tile -> Register DE
        call    CityMapGetTileAtAddress ; hl = address. Preserves BC and HL

        push    hl
        call    CityTileFireProbability ; de = tile, returns d = probability
        pop     hl

        ld      a,BANK_SCRATCH_RAM
        ld      [rSVBK],a

        ld      a,d
        add     a,[hl]
        jr      nc,.not_overflowed_left
        ld      a,255
.not_overflowed_left:
        ld      [hl],a

        pop     de
        pop     hl
.skip_left:

    ; Right

    ld      a,CITY_MAP_WIDTH-1
    cp      a,e
    jr      z,.skip_right
        push    hl
        push    de

        inc     hl

        ; Returns: - Tile -> Register DE
        call    CityMapGetTileAtAddress ; hl = address. Preserves BC and HL

        push    hl
        call    CityTileFireProbability ; de = tile, returns d = probability
        pop     hl

        ld      a,BANK_SCRATCH_RAM
        ld      [rSVBK],a

        ld      a,d
        add     a,[hl]
        jr      nc,.not_overflowed_right
        ld      a,255
.not_overflowed_right:
        ld      [hl],a

        pop     de
        pop     hl
.skip_right:

    ; End

    ret

;-------------------------------------------------------------------------------

; Output data to WRAMX bank BANK_SCRATCH_RAM
Simulation_Fire::

    ; This should only be called during disaster mode!

    ; Clear
    ; -----

    ; Each tile can receive fire from the 4 neighbours. In this bank the code
    ; adds the probabilities of the tile to catch fire as many times as needed
    ; (e.g. 2 neighbours with fire, 2 x probabilities). Afterwards, a random
    ; number is generated for each tile and if it is lower the tile catches
    ; fire or not.

    ld      a,BANK_SCRATCH_RAM
    ld      [rSVBK],a

    call    ClearWRAMX

    ; For each tile check if it is type TYPE_FIRE and flag to expand fire
    ; -------------------------------------------------------------------

    ld      a,BANK_CITY_MAP_TYPE
    ld      [rSVBK],a

    ld      hl,CITY_MAP_TYPE ; Map base

    ld      d,0 ; y
.loopy:
        ld      e,0 ; x
.loopx:

        ld      a,[hl]
        cp      a,TYPE_FIRE
        jr      nz,.skip_tile

        push    de
        push    hl

            call    Simulation_FireExpand ; e = x, d = y, hl = address

        pop     hl
        pop     de

        ld      a,BANK_CITY_MAP_TYPE
        ld      [rSVBK],a

.skip_tile:
        inc     hl

        inc     e
        ld      a,CITY_MAP_WIDTH
        cp      a,e
        jr      nz,.loopx

    inc     d
    ld      a,CITY_MAP_HEIGHT
    cp      a,d
    jr      nz,.loopy

    ; Remove fire
    ; -----------

    ld      bc,CITY_MAP_TILES ; Map base

    ld      a,BANK_CITY_MAP_TYPE
    ld      [rSVBK],a

.loop_remove:

        ld      a,[bc] ; Get type

        cp      a,TYPE_FIRE
        jr      nz,.loop_remove_not_fire

            ld      a,[initial_number_fire_stations]
            ld      d,a

            call    GetRandom ; bc and de preserved
            cp      a,d ; cy = 1 if d > a | d = threshold
            jr      nc,.loop_remove_not_fire

                push    bc

                LD_HL_BC
                ld      bc,T_DEMOLISHED
                call    CityMapDrawTerrainTileAddress ; bc = tile, hl = address

                ld      a,BANK_CITY_MAP_TYPE
                ld      [rSVBK],a

                pop     bc

.loop_remove_not_fire:

    inc     bc

    bit     5,b ; Up to E000
    jr      z,.loop_remove

    ; Place fire wherever it was flagged in the previoys loop
    ; -------------------------------------------------------

    ld      a,BANK_SCRATCH_RAM
    ld      [rSVBK],a

    ld      bc,CITY_MAP_TILES ; Map base

.loop_add:

        ld      a,[bc]
        and     a,a
        jr      z,.not_flagged

            ld      d,a
            call    GetRandom ; bc and de preserved
            cp      a,d ; cy = 1 if d > a | d = threshold
            jr      nc,.over_threshold

                LD_HL_BC

                ; TODO : Destroy whatever is here and fill it with fire!

                ld      a,BANK_CITY_MAP_TILES
                ld      [rSVBK],a
                ld      [hl],T_FIRE_1&$FF

                ld      a,BANK_CITY_MAP_ATTR
                ld      [rSVBK],a
                ld      [hl],T_FIRE_1>>8 | 5 | (1<<3)

                ld      a,BANK_CITY_MAP_TYPE
                ld      [rSVBK],a
                ld      [hl],TYPE_FIRE

                ld      a,BANK_SCRATCH_RAM
                ld      [rSVBK],a

.over_threshold:

.not_flagged:

    inc     bc

    bit     5,b ; Up to E000
    jr      z,.loop_add

    ; Done
    ; ----

    ret

;-------------------------------------------------------------------------------

Simulation_FireAnimate:: ; This doesn't refresh tile map!

    ld      hl,CITY_MAP_TILES ; Map base

    ld      a,BANK_CITY_MAP_TYPE
    ld      [rSVBK],a

.loop:

        ld      a,[hl] ; Get type

        cp      a,TYPE_FIRE
        jr      nz,.not_fire

            ld      a,BANK_CITY_MAP_TILES
            ld      [rSVBK],a

; Actually, this could check if T_FIRE_1 is greater than 255 or T_FIRE_2 is
; lower than 256.
IF ( (T_FIRE_1 % 2) != 0 ) || ( (T_FIRE_1 + 1) != T_FIRE_2 ) || (T_FIRE_1 < 256)
    FAIL "Invalid tile number for fire tiles."
ENDC

            ld      a,1 ; T_FIRE_1 must be even, T_FIRE_2 must be odd.
            xor     a,[hl] ; They must use the same palette
            ld      [hl],a

            ld      a,BANK_CITY_MAP_TYPE
            ld      [rSVBK],a

.not_fire:

    inc     hl

    bit     5,h ; Up to E000
    jr      z,.loop

    ret

;-------------------------------------------------------------------------------

Simulation_FireTryStart::

    ld      a,[simulation_disaster_mode]
    and     a,a
    ret     nz ; Don't start a fire if there is already a fire

    ret ; TODO: Remove

    ; Check if a fire has to start or not
    ; -----------------------------------

    ; TODO

    ; If so, start it!
    ; ----------------

    ; TODO

    ld      hl,$D000+32*64+33
    ld      a,BANK_CITY_MAP_TILES
    ld      [rSVBK],a
    ld      [hl],T_FIRE_1&$FF
    ld      a,BANK_CITY_MAP_ATTR
    ld      [rSVBK],a
    ld      [hl],T_FIRE_1>>8 | 5 | 8
    ld      a,BANK_CITY_MAP_TYPE
    ld      [rSVBK],a
    ld      [hl],TYPE_FIRE

    ;call    bg_reload_main ; refresh bg and set correct scroll

    ; Count number of fire stations and save it
    ; -----------------------------------------

    ld      hl,CITY_MAP_TILES ; Map base

    ld      a,BANK_CITY_MAP_TILES
    ld      [rSVBK],a

.loop_count:

        ld      a,[hl] ; Get LSB of tile
        cp      a,T_FIRE_DEPT & $FF
        jr      nz,.skip_count

            ld      a,BANK_CITY_MAP_ATTR
            ld      [rSVBK],a

            ld      a,[hl] ; Get attrs of tile (MSB)
            bit     3,a ; MSB of tile number
IF T_FIRE_DEPT > 255
            jr      z,.skip_count_restore
ELSE
            jr      nz,.skip_count_restore
ENDC

                ld      a,[initial_number_fire_stations]
                cp      a,255 ; saturate top 255
                jr      z,.skip_count_restore
                    inc     a
                    ld      [initial_number_fire_stations],a

.skip_count_restore:

        ld      a,BANK_CITY_MAP_TILES
        ld      [rSVBK],a

.skip_count:

    inc     hl

    bit     5,h ; Up to E000
    jr      z,.loop_count

    ; Remove all traffic tiles from the map, as well as other animations
    ; ------------------------------------------------------------------

    LONG_CALL   Simulation_TrafficRemoveAnimationTiles

    ; TODO : Remove trains, planes, etc

    ; Enable disaster mode
    ; --------------------

    ld      a,1
    ld      [simulation_disaster_mode],a

    ret

;###############################################################################