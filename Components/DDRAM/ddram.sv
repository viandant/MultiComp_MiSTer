//
// ddram.v
// Copyright (c) 2017 Sorgelig
//
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// ------------------------------------------
//

// 8-bit version
//
// Adapted to Multicomp by (c) 2020 Viandant

module ddram
(
        input         DDRAM_CLK,

        input         DDRAM_BUSY,
        output [7:0]  DDRAM_BURSTCNT,
        output [28:0] DDRAM_ADDR,
        input [63:0]  DDRAM_DOUT,
        input         DDRAM_DOUT_READY,
        output        DDRAM_RD,
        output [63:0] DDRAM_DIN,
        output [7:0]  DDRAM_BE,
        output        DDRAM_WE,

        input [27:0]  wraddr,
        input [7:0]   din,
        input         we_req,
        output reg    we_ack = 0,

        input [27:0]  rdaddr,
        output [7:0]  dout,
        input         rd_req,
        output reg    rd_rdy = 1,

        output [1:0]  dbg_state,
        input         reset
);

assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = (8'd1<<{ram_address[2:0]}) | {8{ram_read}};
assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_data;
assign DDRAM_WE       = ram_write;

assign dout = ram_q[{rdaddr[2:0], 3'b000} +:8];
assign dbg_state = state;

reg  [7:0] ram_burst;
reg [63:0] ram_q, next_q;
reg [63:0] ram_data;
reg [27:0] ram_address, cache_address;
// If cache_valid[1] == 1 then next_q reflects the memory content 
// at cache_address + 8 at some time in the past after
// the last reset; otherwise we don't know.
// The same holds for cache_valid[0] and ram_q.
// Use reset in case the cache content might have become too old.
reg [1:0]  cache_valid = 2'b00;
reg        ram_read    = 0;
reg        ram_write   = 0;
reg [1:0]  state       = 0;

always @(posedge DDRAM_CLK) begin
reg old_rd;
   if (reset) begin
      rd_rdy 	    <= 1;
      old_rd 	    <= 0;      
      state 	    <= 0;
      ram_read 	    <= 0;
      ram_write     <= 0;
      ram_address   <= 0;
      cache_address <= 0;
      ram_q 	    <= 0;
      next_q 	    <= 0;      
      cache_valid   <= 2'b00;      
      we_ack 	    <= we_req;
   end
   else begin
      old_rd         <= rd_req;
      if (~old_rd & rd_req) rd_rdy <= 0;
      
      if(!DDRAM_BUSY)
        ram_write <= 0;
         
      case(state)
        default:
          // Moved !DDRAM_BUSY condition inside default case,
          // because it made state 2 miss the data from DDRAM occasionally.
          if (!DDRAM_BUSY)
            if(we_ack != we_req) begin
               ram_data    <= {8{din}};
               ram_address <= wraddr;
               ram_write   <= 1;
               ram_burst   <= 1;
               state 	   <= 1;
            end
            else if(~rd_rdy) begin
               if( (cache_address[27:3] == rdaddr[27:3]) & (cache_valid[0] == 1'b1)) rd_rdy <= 1;
               else if((cache_address[27:3]+1'd1 == rdaddr[27:3]) & (cache_valid[1] == 1'b1)) begin
                  rd_rdy 	<= 1;
                  ram_q 	<= next_q;
                  ram_address 	<= {rdaddr[27:3]+1'd1,3'b000};
		  cache_address <= {rdaddr[27:3],3'b000};
                  cache_valid 	<= 2'b01;		  
                  ram_read 	<= 1;
                  ram_burst 	<= 1;
                  state 	<= 3;
               end
               else begin
                  ram_address <= {rdaddr[27:3],3'b000};
		  cache_valid <= 2'b00;		  
                  ram_read    <= 1;
                  ram_burst   <= 2;
                  state       <= 2;
               end 
            end // if (~rd_rdy)
        1: begin
           we_ack <= we_req;
           state  <= 0;
        end
           
        2: if(DDRAM_DOUT_READY) begin
           ram_read 	  <= 0;
           ram_q 	  <= DDRAM_DOUT;
           rd_rdy 	  <= 1;
	   cache_address  <= ram_address;	   
	   cache_valid[0] <= 1'b1;	   
           state 	  <= 3;	   
        end           
        3: if(DDRAM_DOUT_READY) begin
           ram_read 	  <= 0;
           next_q 	  <= DDRAM_DOUT;
	   cache_valid[1] <= 1'b1;
           state 	  <= 0;	   
        end
      endcase
   end // else: !if(reset)   
end

endmodule
