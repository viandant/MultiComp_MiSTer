//============================================================================
//  Grant’s multi computer
// 
//  Port to MiSTer.
//
//  Based on Grant’s multi computer
//  http://searle.hostei.com/grant/
//  http://searle.hostei.com/grant/Multicomp/index.html
//	 and WiSo's collector blog (MiST port)
//	 https://ws0.org/building-your-own-custom-computer-with-the-mist-fpga-board-part-1/
//	 https://ws0.org/building-your-own-custom-computer-with-the-mist-fpga-board-part-2/
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

       //UART
       output UART_DTR,
       input  UART_DSR,
       input  UART_CTS,
       output UART_RTS,
       input  UART_RXD,
       output UART_TXD,

       //	input 	     cd,          // rs232 Carrier Detect
       //	input 	     ri,          // rs232 Ring Indicator


        // ignored parameters
	inout   [3:0] ADC_BUS,
	output  [1:0] BUTTONS,

	input [6:0]   USER_IN,
	output [6:0]  USER_OUT,

	output        VGA_F1,
	output  [1:0] VGA_SL,

	input 	      OSD_STATUS
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign DDRAM_CLK = clk_100;

reg sig_led_user;

assign LED_USER  = 1;
assign LED_DISK  = ~driveLED;


assign LED_POWER = 0;

assign VIDEO_ARX = 4;
assign VIDEO_ARY = 3;

assign UART_DTR = 1;

`include "build_id.v"
localparam CONF_STR = {
	"MultiComp;;",
	"-;",
	"O78,CPU-ROM,6809-Forth,Z80-CP/M,6502-Basic,6809-Basic;",
	"-;",
	"V,v1.1.",`BUILD_DATE
};


wire 		      clk_100;

     
pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_100)
  );



//////////////////   HPS I/O   ///////////////////
wire  [1:0] buttons;
wire [31:0] status;

wire PS2_CLK;
wire PS2_DAT;

wire forced_scandoubler;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_ack_conf;

hps_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(2000)) hps_io
(
	.clk_sys(CLK_50M),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ps2_kbd_clk_out(PS2_CLK),
	.ps2_kbd_data_out(PS2_DAT)
);

/////////////////  RESET  /////////////////////////

wire reset = RESET | status[0] | buttons[1];

///////////////////////////////////////////////////

assign CLK_VIDEO = clk_100;

typedef enum {cpuZ80CPM='b01, cpu6502Basic='b10, cpu6809Basic='b11, cpu6809Forth='b00} cpu_type_enum;
wire [1:0] cpu_type = status[8:7];

wire hblank, vblank;
wire hs, vs;
wire [1:0] r,g,b;
wire driveLED;

wire [3:0] _hblank, _vblank;
wire [3:0] _hs, _vs;
wire [1:0] _r[3:0], _g[3:0], _b[3:0];
wire [3:0] _CE_PIXEL;
wire [3:0] _SD_CS;
wire [3:0] _SD_MOSI;
wire [3:0] _SD_SCK;
wire [3:0] _driveLED;
wire [3:0] _uart_dtr;
wire [3:0] _uart_rts;
wire [3:0] _uart_txd;
	   
always_comb 
begin
       	hblank   <= _hblank[cpu_type];
       	vblank   <= _vblank[cpu_type];
       	hs 	 <= _hs[cpu_type];
       	vs 	 <= _vs[cpu_type];
       	r 	 <= _r[cpu_type][1:0];
       	g 	 <= _g[cpu_type][1:0];
       	b 	 <= _b[cpu_type][1:0];
       	CE_PIXEL <= _CE_PIXEL[cpu_type];
       	SD_CS    <= _SD_CS[cpu_type];
       	SD_MOSI  <= _SD_MOSI[cpu_type];
       	SD_SCK   <= _SD_SCK[cpu_type];
       	driveLED <= _driveLED[cpu_type];
        //UART_DTR <= _uart_dtr[cpu_type]; //Currently not used
       	UART_RTS <= _uart_rts[cpu_type];
       	UART_TXD <= _uart_txd[cpu_type];
end

MicrocomputerZ80CPM MicrocomputerZ80CPM
(
	.N_RESET(~reset & cpu_type == cpuZ80CPM),
	.clk(cpu_type == cpuZ80CPM ? CLK_50M : 0),
	.R(_r[cpuZ80CPM][1:0]),
	.G(_g[cpuZ80CPM][1:0]),
	.B(_b[cpuZ80CPM][1:0]),
	.HS(_hs[cpuZ80CPM]),
	.VS(_vs[cpuZ80CPM]),
	.hBlank(_hblank[cpuZ80CPM]),
	.vBlank(_vblank[cpuZ80CPM]),
	.cepix(_CE_PIXEL[cpuZ80CPM]),
	.ps2Clk(PS2_CLK),
	.ps2Data(PS2_DAT),
	.sdCS(_SD_CS[cpuZ80CPM]),
	.sdMOSI(_SD_MOSI[cpuZ80CPM]),
	.sdMISO(SD_MISO),
	.sdSCLK(_SD_SCK[cpuZ80CPM]),
	.driveLED(_driveLED[cpuZ80CPM]),

	.cts1(UART_CTS),
	.rts1(_uart_rts[cpuZ80CPM]),
	.rxd1(UART_RXD),
	.txd1(_uart_txd[cpuZ80CPM])

);

Microcomputer6502Basic Microcomputer6502Basic
(
	.N_RESET(~reset & cpu_type == cpu6502Basic),
	.clk(cpu_type == cpu6502Basic ? CLK_50M : 0),
	.R(_r[cpu6502Basic][1:0]),
	.G(_g[cpu6502Basic][1:0]),
	.B(_b[cpu6502Basic][1:0]),
	.HS(_hs[cpu6502Basic]),
	.VS(_vs[cpu6502Basic]),
	.hBlank(_hblank[cpu6502Basic]),
	.vBlank(_vblank[cpu6502Basic]),
	.cepix(_CE_PIXEL[cpu6502Basic]),
	.ps2Clk(PS2_CLK),
	.ps2Data(PS2_DAT),
	.sdCS(_SD_CS[cpu6502Basic]),
	.sdMOSI(_SD_MOSI[cpu6502Basic]),
	.sdMISO(SD_MISO),
	.sdSCLK(_SD_SCK[cpu6502Basic]),
	.driveLED(_driveLED[cpu6502Basic])
);

//Reset is not working (even on the original Grant's 6809)
Microcomputer6809Basic Microcomputer6809Basic
(
	.N_RESET(~reset & cpu_type == cpu6809Basic),
	.clk(cpu_type == cpu6809Basic ? CLK_50M : 0),
	.R(_r[cpu6809Basic][1:0]),
	.G(_g[cpu6809Basic][1:0]),
	.B(_b[cpu6809Basic][1:0]),
	.HS(_hs[cpu6809Basic]),
	.VS(_vs[cpu6809Basic]),
	.hBlank(_hblank[cpu6809Basic]),
	.vBlank(_vblank[cpu6809Basic]),
	.cepix(_CE_PIXEL[cpu6809Basic]),
	.ps2Clk(PS2_CLK),
	.ps2Data(PS2_DAT),
	.sdCS(_SD_CS[cpu6809Basic]),
	.sdMOSI(_SD_MOSI[cpu6809Basic]),
	.sdMISO(SD_MISO),
	.sdSCLK(_SD_SCK[cpu6809Basic]),
	.driveLED(_driveLED[cpu6809Basic])
);


Microcomputer6809Forth Microcomputer6809Forth
(
	.N_RESET(~reset & cpu_type == cpu6809Forth),
	.clk(cpu_type == cpu6809Forth ? CLK_50M : 0),
	.R(_r[cpu6809Forth][1:0]),
	.G(_g[cpu6809Forth][1:0]),
	.B(_b[cpu6809Forth][1:0]),
	.HS(_hs[cpu6809Forth]),
	.VS(_vs[cpu6809Forth]),
	.hBlank(_hblank[cpu6809Forth]),
	.vBlank(_vblank[cpu6809Forth]),
	.cepix(_CE_PIXEL[cpu6809Forth]),
	.ps2Clk(PS2_CLK),
	.ps2Data(PS2_DAT),
	.sdCS(_SD_CS[cpu6809Forth]),
	.sdMOSI(_SD_MOSI[cpu6809Forth]),
	.sdMISO(SD_MISO),
	.sdSCLK(_SD_SCK[cpu6809Forth]),
	.driveLED(_driveLED[cpu6809Forth]),
	.cts1(UART_CTS),
	.rts1(_uart_rts[cpu6809Forth]),
	.rxd1(UART_RXD),
	.txd1(_uart_txd[cpu6809Forth]),

        .DDRAM_CLK(DDRAM_CLK),
  	.DDRAM_BUSY(DDRAM_BUSY),
  	.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
  	.DDRAM_ADDR(DDRAM_ADDR),
  	.DDRAM_DOUT(DDRAM_DOUT),
  	.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
  	.DDRAM_RD(DDRAM_RD),
  	.DDRAM_DIN(DDRAM_DIN),
  	.DDRAM_BE(DDRAM_BE),
  	.DDRAM_WE(DDRAM_WE)
);

video_cleaner video_cleaner
(
	.clk_vid(CLK_VIDEO),
	.ce_pix(CE_PIXEL),

	.R({4{r}}),
	.G({4{g}}),
	.B({4{b}}),
	.HSync(hs),
	.VSync(vs),
	.HBlank(hblank),
	.VBlank(vblank),

	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE)
);


endmodule
