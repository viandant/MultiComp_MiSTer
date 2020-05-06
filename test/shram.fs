HEX
: WRT
    80 0 ?DO
        I DUP 2 * B200 + !
    LOOP
;

: RD
    80 0 ?DO
        I 2 * B200 + @ .
        HOR 80 > IF CR THEN
    LOOP
;



