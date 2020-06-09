( This file can be run on gforth on a PC
as well a  on the 6809 Forth Microcomputer.
On PC memory dump files from the SECD machine can be inspected.
On the 6809 the memory shared with the SECD machine is accessed
directly. )

forth definitions
0 value gforthp
0 value maisforthp

s" ENVIRONMENT?" get-current search-wordlist
[IF]
	 s" gforth" environment?
	 [IF]
		  ." This seems to be gforth version "
		  type cr
		  true to gforthp
		  false to maisforthp
	 [ELSE]
		  ." Unknown system. We can't guarantee anything"
	 [THEN]
[ELSE]
	 drop
	 ." This is probably running on Maisforth."
	 false to gforthp
	 true to maisforthp
[THEN]

HEX

( Add case control structure not existing in Maisforth )
maisforthp [IF]
: case
  postpone ahead
  postpone begin
  postpone ahead
  2 cs-roll postpone then \ CS: begin ahead
; immediate

: when
  postpone if \ CS: begin ahead if
; immediate

: of
	 postpone over postpone = postpone if
	 postpone drop
; immediate
          
: endof
  2 cs-pick \ CS: begin ahead if begin
  postpone again \ begin ahead if
  postpone then \ begin ahead
; immediate

: endcase
  postpone drop
  1 cs-roll \ CS: ahead begin 
  postpone again \ ahead
  postpone then \ -
; immediate

[THEN]

0 constant cons-tag
2 constant symbol-tag
3 constant fixnum-tag

0 constant nil-tag
1 constant true-tag
2 constant false-tag

0 value sz
0 value code-start

( On PC use this function to read the memory dump.
  Expects the address and size of the file name on stack )
gforthp [IF]
: readbin ( c-addr u -- )
	 slurp-file
	 to sz
	 to code-start
;
[THEN]

maisforthp [if]
: shram_cell@ ( sexp-addr - sexp )
	 dup 8 rshift B141 !
	 FF and B200 + @ byteswap
;
[then]


: shram@
	 [ cell 8 = ] [if]
		  ul@
	 [else]
		  dup shram_cell@ swap cell + shram_cell@
	 [then]
;

( Fetch an s-expression cell from the memory dump or
  the shared memory addressing bytes )
: 8@ ( addr -- sexp )
	 code-start +
	 shram@
;

( Fetch an s-expression cell from the memory dump or
  the shared memory addressing 32-bit cells )
: 32@ ( sexp-addr -- sexp )
	 4 * 8@
;


: 2rshift_small
	 2dup
	 rshift
	 -ROT 10 SWAP - LSHIFT
;	 

( rshift over two cells )
: 2rshift ( w1 w2 u - w1' w2' )
	 DUP 10 < IF
		  SWAP OVER 2rshift_small
		  2SWAP
		  RSHIFT OR
		  SWAP
	 ELSE
		  10 - RSHIFT
		  NIP 0
	 THEN
;

( A sexp requires 2 cells on 8 bit Maisforth, but only 1 cell
on 64 bit gforth.
So we define some ...-sexp words as a compatibility layer. )
: rshift-sexp ( sexp u - w )
	 CELL 8 = IF
		  postpone rshift
	 ELSE
		  postpone 2rshift postpone DROP
	 THEN
; immediate
	 
( Macros providing a compatibility layer between
8 bit machines requiring 2 cells for S-expressions
and 64 bit machines needing only one cell )
: over-sexp ( w sexp -- w sexp w )
	 cell 8 = if
		  postpone over
	 else
		  2 postpone literal postpone pick
	 then
; immediate

: dup-sexp ( sexp -- sexp sexp )
	 cell 8 = if
		  postpone dup
	 else
		  postpone 2dup
	 then
; immediate

: swap-sexp-cell ( sexp w -- w sexp )
	 cell 8 = if
		  postpone swap
	 else
		  postpone -rot
	 then
; immediate

: swap-cell-sexp ( w sexp -- sexp w )
	 cell 8 = if
		  postpone swap
	 else
		  postpone rot
	 then
; immediate

: sexp-drop ( sexp -- )
	 cell 8 = if
		  postpone drop
	 else
		  postpone 2drop
	 then
; immediate

\ ..xx .... .... .... .... .... .... ....
: ctype ( sexp -- w )
	 1C rshift-sexp 
	 3 AND
;

\ .... xxxx xxxx xxxx xx.. .... .... ....
: car ( sexp -- sexp-addr )
	 E rshift-sexp
	 3FFF and
;

: car@ ( sexp -- sexp )
	 car 32@
;

\ .... .... .... .... ..xx xxxx xxxx xxxx
: cdr ( sexp -- sexp-addr )
	 0 rshift-sexp
	 3FFF and
;

: cdr@ ( sexp -- sexp )
	 cdr 32@
;

: symbolp ( sexp -- boolean )
	 ctype 2 =
;

: numberp ( sexp -- boolean ) 
	 ctype 3 =
;

: consp ( sexp -- boolean ) 
	 ctype 0 =
;

( The last memory cell is initialised with a list
pointing to the problem and a list of the remaining
unused "free" cells)
: problem-free
	 sz 4 - 8@
;

: problem
	 problem-free car@
;

: free
	 problem-free cdr@
;

: result
	 problem-free cdr@
;

: program
	 problem car@
;

: arg
	 problem cdr@
;

: open-list
	 if
		  s" (" type
	 then
;

: close-list
	 if
		  s" )" type
	 then
;

: continue-list
	 if
		  s"  " type
	 else
		  s" . " type
	 then
;

( print* expects a boolean cdr? on stack. If cdr? is true,
sexp is printed as a  list in the cdr position of an enclosing list.
This means, that
- a cons is not bracketed;
- an atom different from nil is preceded by a dot;
- nil is not printed. )

: print* ( cdr? sexp -- )
	 dup-sexp ctype \ cdr? c ctype
	 case
		  cons-tag of \ cdr? c
				over-sexp open-list
				dup-sexp car@ true swap-sexp-cell recurse \ cdr? c
				false swap-sexp-cell cdr@ recurse \ cdr?
				close-list
		  endof
		  fixnum-tag of \ cdr? c
				swap-cell-sexp continue-list  \ c
				cdr . \
		  endof
		  symbol-tag of \ cdr? c
				cdr case  
					 nil-tag of \ cdr?
						  if \
								s" nil" type
						  then
					 endof
					 true-tag of \ cdr?
						  continue-list \
						  s" true" type \
					 endof
					 false-tag of \ cdr?
						  continue-list \ 
						  s" false" type \
					 endof
					 swap continue-list
					 s" symbol: " type dup .					 
				endcase
		  endof
		  swap continue-list
		  s" type: " type dup .
		  drop
	 endcase
;

: print ( sexp -- )
	 true swap-sexp-cell print*
;

