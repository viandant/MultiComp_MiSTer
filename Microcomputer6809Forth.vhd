-- This file is copyright by Grant Searle 2014
-- You are free to use this file in your own projects but must never charge for it nor use it without
-- acknowledgement.
-- Please ask permission from Grant Searle before republishing elsewhere.
-- If you use this file or any part of it, please add an acknowledgement to myself and
-- a link back to my main web site http://searle.hostei.com/grant/    
-- and to the "multicomp" page at http://searle.hostei.com/grant/Multicomp/index.html
--
-- Please check on the above web pages to see if there are any updates before using this file.
-- If for some reason the page is no longer available, please search for "Grant Searle"
-- on the internet to see if I have moved to another web hosting service.
--
-- Grant Searle
-- eMail address available on my main web page link above.

library ieee;
use ieee.std_logic_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

entity Microcomputer6809Forth is
	port(
		N_RESET	   : in std_logic;
		clk			: in std_logic;

		sramData		: inout std_logic_vector(7 downto 0);
		sramAddress	: out std_logic_vector(15 downto 0);
		n_sRamWE		: out std_logic;
		n_sRamCS		: out std_logic;
		n_sRamOE		: out std_logic;
		n_sRamLB		: out std_logic;
		n_sRamUB		: out std_logic;
		
		rxd1			: in std_logic;
		txd1			: out std_logic;
		rts1			: out std_logic;
      cts1			: in  std_logic;

		rxd2			: in std_logic;
		txd2			: out std_logic;
		rts2			: out std_logic;
		
		videoSync	: out std_logic;
		video			: out std_logic;

		R       		: out std_logic_vector(1 downto 0);
		G       		: out std_logic_vector(1 downto 0);
		B       		: out std_logic_vector(1 downto 0);
		HS	         : out std_logic;
		VS 			: out std_logic;
		hBlank		: out std_logic;
		vBlank		: out std_logic;
		cepix  		: out std_logic;

		ps2Clk		: in std_logic;
		ps2Data		: in std_logic;

		sdCS			: out std_logic;
		sdMOSI		: out std_logic;
		sdMISO		: in std_logic;
		sdSCLK		: out std_logic;
		driveLED		: out std_logic :='1';

      DDRAM_CLK	:  in std_logic;
      DDRAM_BUSY	: in std_logic;      
      DDRAM_BURSTCNT: out std_logic_vector(7 downto 0);
      DDRAM_ADDR	: out std_logic_vector(28 downto 0);
      DDRAM_DOUT	: in std_logic_vector(63 downto 0);
      DDRAM_DOUT_READY: in std_logic;
      DDRAM_RD		: out std_logic;
      DDRAM_DIN	: out std_logic_vector(63 downto 0);
      DDRAM_BE		: out std_logic_vector(7 downto 0);
      DDRAM_WE		: out std_logic      
      );
end Microcomputer6809Forth;

architecture struct of Microcomputer6809Forth is

  component ddram is
    port (
      DDRAM_CLK         : in std_logic;
  
      DDRAM_BUSY        : in std_logic;
      DDRAM_BURSTCNT    : out std_logic_vector(7 downto 0);
      DDRAM_ADDR        : out std_logic_vector(28 downto 0);
      DDRAM_DOUT        : in std_logic_vector(63 downto 0);
      DDRAM_DOUT_READY  : in std_logic;
      DDRAM_RD          : out std_logic;
      DDRAM_DIN         : out std_logic_vector(63 downto 0);
      DDRAM_BE          : out std_logic_vector(7 downto 0);
      DDRAM_WE          : out std_logic;

      wraddr            : in std_logic_vector(27 downto 0);      
      din               : in std_logic_vector(7 downto 0);
      we_req            : in std_logic;
      we_ack            : out std_logic;
      
      rdaddr            : in std_logic_vector(27 downto 0);
      dout              : out std_logic_vector(7 downto 0);
      rd_req            : in std_logic;
      rd_rdy            : out std_logic;
      dbg_state         : out std_logic_vector(1 downto 0);
      reset             : in std_logic;

      secd_stopped      : in std_logic;
      din32             : in std_logic_vector(31 downto 0);
      dout32            : out std_logic_vector(31 downto 0);
      addr32            : in std_logic_vector(13 downto 0);
      read32_enable     : in std_logic;
      write32_enable    : in std_logic;
      busy32            : out std_logic
      );
  end component ddram;
  

	signal n_WR							: std_logic;
	signal n_RD							: std_logic;
	signal cpuAddress					: std_logic_vector(15 downto 0);
	signal cpuDataOut					: std_logic_vector(7 downto 0);
	signal cpuDataIn					: std_logic_vector(7 downto 0);
        signal cpuHold                                          : std_logic;
        
	signal basRomData					: std_logic_vector(7 downto 0);
	signal internalRam1DataOut		: std_logic_vector(7 downto 0);
	signal internalRam2DataOut		: std_logic_vector(7 downto 0);
	signal interface1DataOut		: std_logic_vector(7 downto 0);
	signal interface2DataOut		: std_logic_vector(7 downto 0);
	signal sdCardDataOut				: std_logic_vector(7 downto 0);

	signal n_memWR						: std_logic :='1';
	signal n_memRD 					: std_logic :='1';

	signal n_ioWR						: std_logic :='1';
	signal n_ioRD 						: std_logic :='1';
	
	signal n_MREQ						: std_logic :='1';
	signal n_IORQ						: std_logic :='1';	

	signal n_int1						: std_logic :='1';	
	signal n_int2						: std_logic :='1';	
	
	signal n_externalRamCS			: std_logic :='1';
	signal n_internalRam1CS			: std_logic :='1';
	signal n_internalRam2CS			: std_logic :='1';
	signal n_basRomCS             : std_logic :='1';
	signal n_interface1CS			: std_logic :='1';
   signal n_interface2CS			: std_logic :='1';
	signal n_shramStateCS			: std_logic :='1';
	signal n_shramCS					: std_logic :='1';
	signal n_shramControlCS			: std_logic :='1';
	signal n_sdCardCS        		: std_logic :='1';
   signal n_secdControlCS        : std_logic :='1';
  
	signal serialClkCount			: std_logic_vector(15 downto 0);
	signal cpuClkCount				: std_logic_vector(5 downto 0); 
	signal sdClkCount					: std_logic_vector(5 downto 0); 	
	signal cpuClock					: std_logic;
	signal serialClock				: std_logic;
	signal sdClock						: std_logic;

	signal shramData		         : std_logic_vector(7 downto 0);
	signal shramAddress           : std_logic_vector(15 downto 0);
	signal shramAddrHi            : std_logic_vector(15 downto 0) := (others => '0');
	signal shramWeReq             : std_logic;
	signal shramWeAck             : std_logic;
	signal shramRdReq             : std_logic;
	signal shramRdRdy             : std_logic;
	signal shramState             : std_logic_vector(1 downto 0);
   signal shramReset             : std_logic;

   signal din32                  : std_logic_vector(31 downto 0);
   signal dout32                 : std_logic_vector(31 downto 0);
   signal addr32                 : std_logic_vector(13 downto 0);
   signal read32_enable          : std_logic;
   signal write32_enable         : std_logic;
   signal busy32                 : std_logic;
  
   signal secdButton             : std_logic;
   signal secdStop               : std_logic;
   signal secdStopped            : std_logic;
   signal secdState              : std_logic_vector(1 downto 0);
   signal secdReset              : std_logic;
  
begin

-- ____________________________________________________________________________________
-- CPU CHOICE GOES HERE

cpu1 : entity work.cpu09
port map(
	clk => not(cpuClock),
	rst => not N_RESET,
	rw => n_WR,
	addr => cpuAddress,
	data_in => cpuDataIn,
	data_out => cpuDataOut,
	halt => '0',
	hold => cpuHold,
	irq => '0',
	firq => '0',
	nmi => '0'
); 

-- ____________________________________________________________________________________
-- ROM GOES HERE	

rom1 : entity work.M6809_FORTH_ROM -- 16KB Forth
port map(
	address => cpuAddress(13 downto 0),
	clock => clk,
	q => basRomData
);

-- ____________________________________________________________________________________
-- RAM GOES HERE

ram1: entity work.InternalRam64K
port map
(
	address => cpuAddress(15 downto 0),
	clock => clk,
	data => cpuDataOut,
	wren => not(n_memWR or n_internalRam1CS),
	q => internalRam1DataOut
);

-- ____________________________________________________________________________________
-- INPUT/OUTPUT DEVICES GO HERE	

io1 : entity work.SBCTextDisplayRGB
port map (
	n_reset => N_RESET,
	clk => clk,

	-- RGB video signals
	hSync => HS,
	vSync => VS,
   videoR0 => R(1),
   videoR1 => R(0),
   videoG0 => G(1),
   videoG1 => G(0),
   videoB0 => B(1),
   videoB1 => B(0),
	hBlank => hBlank,
	vBlank => vBlank,
	cepix => cepix,

	-- Monochrome video signals (when using TV timings only)
	sync => videoSync,
	video => video,

	n_wr => n_interface1CS or cpuClock or n_WR,
	n_rd => n_interface1CS or cpuClock or (not n_WR),
	n_int => n_int1,
	regSel => cpuAddress(0),
	dataIn => cpuDataOut,
	dataOut => interface1DataOut,
	ps2Clk => ps2Clk,
	ps2Data => ps2Data
);

io2 : entity work.bufferedUART
port map(
	clk => clk,
	n_wr => n_interface2CS or cpuClock or n_WR,
	n_rd => n_interface2CS or cpuClock or (not n_WR),
	n_int => n_int1,
	regSel => cpuAddress(0),
	dataIn => cpuDataOut,
	dataOut => interface2DataOut,
	rxClock => serialClock,
	txClock => serialClock,
	rxd => rxd1,
	txd => txd1,
	n_cts => cts1,
	n_dcd => '0',
	n_rts => rts1
);

sd1 : entity work.sd_controller
port map(
	sdCS => sdCS,
	sdMOSI => sdMOSI,
	sdMISO => sdMISO,
	sdSCLK => sdSCLK,
	n_wr => n_sdCardCS or cpuClock or n_WR,
	n_rd => n_sdCardCS or cpuClock or (not n_WR),
	n_reset => n_reset,
	dataIn => cpuDataOut,
	dataOut => sdCardDataOut,
	regAddr => cpuAddress(2 downto 0),
	driveLED => driveLED,
	clk => sdClock -- twice the spi clk
);


-- Shared RAM for communication with HPS and other 'computers'
shram: ddram
  port map(
    DDRAM_CLK => DDRAM_CLK,
    DDRAM_BUSY => DDRAM_BUSY,
    DDRAM_BURSTCNT => DDRAM_BURSTCNT,
    DDRAM_ADDR => DDRAM_ADDR,
    DDRAM_DOUT => DDRAM_DOUT,
    DDRAM_DOUT_READY => DDRAM_DOUT_READY,
    DDRAM_RD => DDRAM_RD,
    DDRAM_DIN => DDRAM_DIN,
    DDRAM_BE  => DDRAM_BE,
    DDRAM_WE  => DDRAM_WE,

    wraddr    => B"0000" & shramAddrHi & cpuAddress(7 downto 0),
    din       => cpuDataOut,
    we_req    => shramWeReq,
    we_ack    => shramWeAck,

    rdaddr    => B"0000" & shramAddrHi & cpuAddress(7 downto 0),
    dout      => shramData ,
    rd_req    => shramRdReq,
    rd_rdy    => shramRdRdy,
    dbg_state => shramState,
    reset     => shramReset or not N_RESET,

    secd_stopped => secdStopped,
    din32 => din32,
    dout32 => dout32,
    addr32 => addr32,
    read32_enable => read32_enable,
    write32_enable => write32_enable,
    busy32 => busy32
    );


-- ____________________________________________________________________________________
-- Slave Systems
secd : entity work.secd_system port map (
  clk         => clk,
  reset       => not N_RESET or secdReset,
  button      => secdButton,
  ram_read    => read32_enable,
  ram_in      => dout32,
  ram_write   => write32_enable,
  ram_out     => din32,
  ram_a       => addr32,
  ram_busy    => busy32,
  stop_input  => secdStop,
  stopped     => secdStopped,
  state       => secdState
  );

-- ____________________________________________________________________________________
-- Shared RAM/SECD Control
cpuHold <= '1' when (shramRdRdy = '0') else '0';
shram_ioReq : process(clk)
begin
  if rising_edge(clk) then
    if (shramWeAck = shramWeReq ) and (n_shramCS = '0') and (n_WR = '0') then
      shramWeReq <=  not shramWeReq;
    end if;   
    shramRdReq <= (not n_shramCS and cpuClock) and n_WR;
  end if;
end process;

shram_control : process(clk)
begin
  if rising_edge(clk) then
    if n_WR = '0' and n_shramControlCS = '0' then
      case cpuAddress(2 downto 0) is
        when B"000" =>
          secdStop   <= cpuDataOut(0);
          secdButton <= cpuDataOut(1);
        when B"001" =>
          shramAddrHi(15 downto 8) <= cpuDataOut;
        when B"010" =>
          shramAddrHi(7 downto 0) <= cpuDataOut;
        when B"100" =>
          shramReset <= '1';
          secdReset <= '1';
        when others => 
          null;
      end case;
    else
      secdButton <= '0';
      shramReset <= '0';
      secdReset <= '0';
    end if;
  end if;
end process;

-- ____________________________________________________________________________________
-- MEMORY READ/WRITE LOGIC GOES HERE

n_memRD <= not(cpuClock) nand n_WR;
n_memWR <= not(cpuClock) nand (not n_WR);

-- ____________________________________________________________________________________
-- CHIP SELECTS GO HERE


n_basRomCS       <= '0' when cpuAddress(15 downto 14) = "11"               else '1'; --16K at top of memory
n_interface1CS   <= '0' when cpuAddress(15 downto 1)  = "101100000000000"  else '1'; -- 2 bytes B000-B001 (Display+KBD)
n_interface2CS   <= '0' when cpuAddress(15 downto 1)  = "101100000000001"  else '1'; -- 2 bytes B002-B003 (Serial to HPS)
n_shramCS        <= '0' when cpuAddress(15 downto 8)  = "10110010"         else '1'; -- B200-B2FF SHRAM memory page
n_shramStateCS   <= '0' when cpuAddress(15 downto 0)  = "1011000101000011" else '1'; -- B143 SHRAM State for Debugging
n_shramControlCS <= '0' when cpuAddress(15 downto 3)  = "1011000101000"    else '1'; -- B14X SHRAM Control
n_sdCardCS       <= '1'; -- 8 bytes No SD-Card yet
n_internalRam1CS <= not n_basRomCS or not n_shramCS ; -- Full Internal RAM - 64 K

-- ____________________________________________________________________________________
-- BUS ISOLATION GOES HERE

cpuDataIn <=
interface1DataOut when n_interface1CS = '0' else
interface2DataOut when n_interface2CS = '0' else
sdCardDataOut when n_sdCardCS = '0' else
basRomData when n_basRomCS = '0' else
"000000" & shramState when n_shramStateCS = '0' else
shramAddrHi(15 downto 8) when n_shramControlCS = '0' and cpuAddress(2 downto 0) = B"001" else
shramAddrHi(7 downto 0) when n_shramControlCS = '0' and cpuAddress(2 downto 0) = B"010" else
"00000" & secdStopped & secdState when n_shramControlCS = '0' and cpuAddress(2 downto 0) = B"000" else
shramData when n_shramCS = '0' else  
internalRam1DataOut when n_internalRam1CS= '0' else
sramData when n_externalRamCS= '0' else
x"FF";

-- ____________________________________________________________________________________
-- SYSTEM CLOCKS GO HERE


-- SUB-CIRCUIT CLOCK SIGNALS

serialClock <= serialClkCount(15);
process (clk)
begin
	if rising_edge(clk) then

		if cpuClkCount < 4 then -- 4 = 10MHz, 3 = 12.5MHz, 2=16.6MHz, 1=25MHz
			cpuClkCount <= cpuClkCount + 1;
		else
			cpuClkCount <= (others=>'0');
		end if;
		if cpuClkCount < 2 then -- 2 when 10MHz, 2 when 12.5MHz, 2 when 16.6MHz, 1 when 25MHz
			cpuClock <= '0';
		else
			cpuClock <= '1';
		end if; 

		if sdClkCount < 49 then -- 1MHz
			sdClkCount <= sdClkCount + 1;
		else
			sdClkCount <= (others=>'0');
		end if;

		if sdClkCount < 25 then
			sdClock <= '0';
		else
			sdClock <= '1';
		end if;

		-- Serial clock DDS
		-- 50MHz master input clock:
		-- Baud Increment
		-- 115200 2416
		-- 38400 805
		-- 19200 403
		-- 9600 201
		-- 4800 101
		-- 2400 50
		serialClkCount <= serialClkCount + 2416;
	end if;
end process;

end;
