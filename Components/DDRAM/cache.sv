module Cache
  #( 
  parameter integer DEPTH = 4,
  parameter integer WIDTH = 32,
  parameter integer ADDRESS_WIDTH = 8				      
		    )
(
  input 								clk,
  input 								reset,
  input [ADDRESS_WIDTH - 1:0] address,
  input [WIDTH - 1:0] 			data_wr, 
  output [WIDTH - 1:0] 			data_rd,
  input 								wr_enable,
  output 							data_valid
  );

genvar i;
  
function integer bitsize(input integer v);
  // Unfortunately, Quarkus fails to handle recursion, like this:
  // if (v <= 1)
  //   bitsize = 0;
  // else
  //   bitsize = bitsize(v >> 1) + 1;
integer j;
   bitsize = 0;
   for( j = v - 1; j > 1; j = j >> 1)
     bitsize = bitsize + 1;
endfunction

parameter integer DEPTH_SZ = bitsize(DEPTH);

reg [ADDRESS_WIDTH - 1:0]      key [DEPTH - 1:0];
reg [WIDTH - 1:0]      val [DEPTH - 1:0];
reg [DEPTH - 1:0]      cell_valid;
wire [ADDRESS_WIDTH - 1:0]     ckey;
wire [DEPTH_SZ:0]     sel;
wire [DEPTH_SZ:0]     sel_aux[DEPTH:0];
wire [DEPTH_SZ:0]     free;
wire [DEPTH_SZ:0]     free_aux[DEPTH:0];
wor            valid;

reg [31:0] 		psdrandom 		 = 314156;
reg [31:0] 		psdrandom_state = 314156;
wire [31:0]    rnd1, rnd2, rnd3;


// Let's generate some pseudo random numbers.
// We use them for deciding which cell to overwrite.
// This is G. Marsaglia's Xorshift
assign rnd1 = psdrandom_state ^ ( psdrandom_state << 13);
assign rnd2 = rnd1 ^ ( rnd1 >> 17);
assign rnd3 = rnd2 ^ ( rnd2 << 5);

always @ (posedge(clk)) begin
   psdrandom_state <= rnd3;
end


generate
   for (i = 0; i < DEPTH; i = i + 1)
     begin: assigns
		  assign sel_aux[i] = (ckey == key[i]) ? i : sel_aux[i + 1];
		  assign valid = ckey == key[i] && cell_valid[i];
		  assign free_aux[i] = ({1'b0,count[i]} < ({1'b0,count[free_aux[i + 1]]} + psdrandom[i])) ? i : free_aux[i + 1];
     end
endgenerate

assign sel_aux[DEPTH] = 2'd0;
assign sel = sel_aux[0];
assign free_aux[DEPTH] = DEPTH - 1;
assign free = free_aux[0];
assign data_rd = val[sel];
assign ckey = address;
assign data_valid = valid;

generate
   for (i = 0; i < DEPTH; i = i + 1)
     begin: initarrays
		  initial begin
			  key[i] 	 <= 0;
			  val[i] 	 <= 0;
			  cell_valid <= 0;
			  count[i] 	 <= 0;
		  end
     end   
endgenerate

task reset_main_arrays();
	integer i;
	for (i = 0; i < DEPTH; i = i + 1)
	  begin
		  key[i] 	 <= 0;
		  val[i] 	 <= 0;
		  cell_valid <= 0;
	  end
endtask

reg wr_enable0;

always @(posedge clk) begin
	wr_enable0 <= wr_enable;
	if (reset) begin
		reset_main_arrays();
	end else begin
		if ((wr_enable == 0) && (wr_enable0 == 1)) begin
			psdrandom <= psdrandom_state;
			if (! valid) begin
				key[free] 		  <= ckey;
				val[free] 		  <= data_wr;
				cell_valid[free] <= 1;
			end else begin
				val[sel] <= data_wr;
			end
		end
   end
end

reg [ADDRESS_WIDTH - 1:0] 	 old_key = 0;
reg [3:0] 						 count [DEPTH - 1:0];
reg [2:0] 						 subcount = 0;

always @(posedge clk) begin
   old_key  <= ckey;
   subcount <= subcount + 1;
end

generate
   for (i = 0; i < DEPTH; i = i + 1)
     begin: counting
		  always @(posedge clk) begin
			  if (reset)
				 count[i] <= 0;
			  else if ( wr_enable == 0 && wr_enable0 == 1) begin
				  if (! valid) begin
					  if (i == free)
						 count[i] <= 4'd15;
				  end else begin
					  if (i == sel)
						 count[i] <= 4'd15;
				  end	      
			  end else   
				 if ( (old_key != ckey) && valid ) begin
					 if ( sel != i ) begin
						 if ( subcount == 0 && count[i] != 4'd0 )
							count[i] <= count[i] - 4'd1;
					 end else if ( count[i] != 4'd15 )
						count[i] <= count[i] + 4'd1;
				 end
		  end // always @ (posedge clk)
     end // block: counting
endgenerate


endmodule
  
