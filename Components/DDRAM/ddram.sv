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

// Combined 8-bit and 32-bit version
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
        input         reset,
  // Internal interface to SECD (16k x 32)
        input         secd_stopped,
        input [31:0]  din32, 
        output [31:0] dout32,
        input [13:0]  addr32,
        input         read32_enable,
        input         write32_enable,
        output reg    busy32
);

//assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BURSTCNT = 1;
assign DDRAM_BE       = address_sel == 1 ? 8'b11111111 | {8{ram_read}} :
                        (8'd1<<{ram_address[2:0]}) | {8{ram_read}} ;
assign DDRAM_ADDR     = address_sel == 1 ? {14'b01100000000000, ram_address32[13:0]} :
                        {3'b011, ram_address[27:3]};
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_data;
assign DDRAM_WE       = ram_write;

assign dout = ram_q;
assign dbg_state = state;
assign dout32 = ram_q32;

reg [63:0] ram_cache32, ram_cache;
reg [7:0]  ram_q;
reg [63:0] ram_q32;
reg [63:0] ram_data;
reg [27:0] ram_address, cache_address;

reg [13:0] ram_address32;
reg        half32;
reg        rd32_rdy, wr32_rdy;

// If cache_valid[1] == 1 then next_q reflects the memory content 
// at cache_address + 8 at some time in the past after
// the last reset; otherwise we don't know.
// The same holds for cache_valid[0] and ram_q.
// Use reset in case the cache content might have become too old.
reg [1:0]  cache_valid   = 2'b00;
reg [1:0]  cache_valid32 = 2'b00;
reg        ram_read      = 0;
reg        ram_write     = 0;
reg [1:0]  state         = 0;
reg [2:0]  state32       = 0;
reg [2:0]  rd_wait       = 0;

reg [1:0]  state2        = 0;
reg [7:0]  cached        = 0;
reg [7:0]  cached8       = 0;
reg        address_sel   = 0;

reg  [63:0] acache_data_wr;
wire [63:0] acache_data_rd;
reg         acache_wr;
wire        acache_valid;
wire  [13:0] acache_addr;
reg   [13:0] acache_wr_addr;

assign acache_addr = acache_wr ? acache_wr_addr : addr32;

Cache #(.DEPTH(12), .WIDTH(64), .ADDRESS_WIDTH(14))
 acache(
	.clk(DDRAM_CLK),
   .address(acache_addr),
   .data_wr(acache_data_wr),
   .data_rd(acache_data_rd),
   .wr_enable(acache_wr),
   .data_valid(acache_valid),
	.reset(reset)
	);


always @(posedge DDRAM_CLK) begin
reg old_rd, old_we, old_rd32, old_wr32;
   if (reset) begin
      rd_rdy          <= 1;
      old_rd          <= 0;
      old_we          <= 0;
      old_rd32        <= 0;
      old_wr32        <= 0;      
      state           <= 0;
      ram_read        <= 0;      
      ram_write       <= 0;
      ram_address     <= 0;
      ram_address32   <= 0;      
      cache_address   <= 0;
      ram_q           <= 0;
      ram_q32         <= 32;     
      cache_valid     <= 2'b00;      
      cache_valid32   <= 2'b00;     
      we_ack          <= we_req;

      state2          <= 0;
      cached          <= 0;
   end

   else begin
		acache_wr  <= 0;			 
      old_rd <= rd_req;
      if (~old_rd && rd_req)
        rd_rdy <= 0;
      
      if(!DDRAM_BUSY)
       begin
          ram_write <= 0;
          ram_read  <= 0;
          if(state2[0] == 1) begin
             if(DDRAM_DOUT_READY) begin
                cached 			 <= 8'h00;
                state2[0] 		 <= 0;
                busy32 			 <= 0;
                ram_q32 		 <= DDRAM_DOUT;
                ram_cache32 	 <= DDRAM_DOUT;

					 acache_data_wr <= DDRAM_DOUT;
					 acache_wr 		 <= 1;
					 acache_wr_addr <= addr32;
             end
          end
          else if (state2[1] == 1) begin
             if(DDRAM_DOUT_READY) begin
                ram_q     <= DDRAM_DOUT[{ram_address[2:0], 3'b000} +:8];
                ram_cache <= DDRAM_DOUT;
                rd_rdy    <= 1;
                state2[1] <= 0;
                cached8   <= 8'hff;
             end   
          end
          else begin
             old_rd32    <= read32_enable;
             old_we      <= write32_enable;
             busy32      <= 0;
             
             if(~old_we && write32_enable) begin
                ram_cache32 	 <= {8'd0,{din32}};
                ram_data 		 <= {8'd0,{din32}};
                ram_address32  <= addr32;
                busy32 			 <= 1;
                ram_write 		 <= 1;
                cached 			 <= 1;
                address_sel 	 <= 1;

					 acache_wr 		 <= 1;
					 acache_data_wr <= din32;
					 acache_wr_addr <= addr32;
             end 
             
             if(~old_rd32 && read32_enable) begin
                if ( (ram_address32[13:0] == addr32[13:0]) && cached ) begin
                   ram_q32 <= ram_cache32;
                end
                else if(acache_valid) begin
					    ram_q32 <= acache_data_rd;
					 end 
					 else begin
                   ram_address32 <= addr32;
                   address_sel   <= 1;
                   ram_read      <= 1;
                   state2[0]     <= 1;
                   cached        <= 0;
                   busy32        <= 1;
                end
             end // if (~old_rd32 && read32_enable)

             if(old_we || ~write32_enable || old_rd32 || ~read32_enable) begin
                
                if (we_ack != we_req) begin
                   ram_cache[{wraddr[2:0], 3'b000} +:8] <= din;
                   ram_data                            <= {8{din}};
                   ram_address                         <= wraddr;
                   address_sel                         <= 0;
                   ram_write                           <= 1;
                   cached8                             <= ((ram_address[27:3] == wraddr[27:3]) ? cached : 8'h00) | (8'd1<<wraddr[2:0]);
                   we_ack                              <= we_req;
                end
                
                if(~rd_rdy) begin
                   if((ram_address[27:3] == rdaddr[27:3]) && (cached8 & (8'd1<<rdaddr[2:0]))) begin
                      ram_q  <= ram_cache[{rdaddr[2:0], 3'b000} +:8];
                      rd_rdy <= 1;
                   end
                   else begin
                      ram_address <= rdaddr;
                      address_sel <= 0;
                      rd_rdy      <= 0;
                      ram_read    <= 1;
                      state2[1]   <= 1;
                      cached8     <= 0;
                   end
                end // if (~old_rd32 && read32_enable)
             end
          end
       end
   end // else: !if(reset) 
end // always @ (posedge DDRAM_CLK)

endmodule
