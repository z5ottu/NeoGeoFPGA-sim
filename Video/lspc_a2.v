`timescale 1ns/1ns

// All pins listed ok. REF, DIVI and DIVO only used on AES for video PLL hack
// Video mode pin is the VIDEO_MODE parameter

module lspc_a2(
	input CLK_24M,
	input nRESET,
	output [15:0] PBUS_OUT,
	inout [23:16] PBUS_IO,
	input [3:1] M68K_ADDR,
	inout [15:0] M68K_DATA,
	input nLSPOE, nLSPWE,
	input DOTA, DOTB,
	output CA4, S2H1,
	output S1H1,
	output LOAD, H, EVEN1, EVEN2,	// For ZMC2
	output IPL0, IPL1,
	output TMS0,						// Also called SCH and CHG
	output LD1, LD2,					// Buffer address load
	output PCK1, PCK2,
	output [3:0] WE,
	output [3:0] CK,
	input SS1, SS2,					// Buffer pair selection for B1
	output nRESETP,
	output SYNC,
	output CHBL,
	output nBNKB,
	output nVCS,						// LO ROM output enable
	output CLK_8M,
	output CLK_4M,
	output [8:0] H_COUNT				// TODO: REMOVE, only used for debug in videout and as a hack in B1
);

	parameter VIDEO_MODE = 1'b0;	// NTSC
	
	wire [8:0] V_COUNT;
	
	// VRAM CPU I/O
	reg CPU_WRITE;									// Latch for VRAM write operation
	reg CPU_WRITE_ACK_PREV;
	wire [14:0] CPU_VRAM_ADDR;
	wire [15:0] CPU_VRAM_WRITE_BUFFER;
	wire [15:0] CPU_VRAM_READ_BUFFER_SCY;	// Are these all the same ?
	wire [15:0] CPU_VRAM_READ_BUFFER_FCY;
	wire [15:0] CPU_VRAM_READ_BUFFER;
	wire [15:0] REG_VRAMMOD;
	
	// Sprites stuff
	reg [3:0] SPR_PIXELCNT;			// Sprite render pixel counter for H-shrink
	wire [11:0] SPR_ATTR_SHRINK;
	wire [2:0] SPR_TILE_NB_AA;		// SPR_ATTR_TILE_NB after auto-animation applied
	wire [1:0] SPR_ATTR_AA;			// Auto-animation config bits
	wire [7:0] AA_SPEED;
	wire [2:0] AA_COUNT;				// Auto-animation tile #
	wire WR_PIXEL;
	wire [8:0] SPR_NB;
	wire [4:0] SPR_TILEIDX;
	wire [1:0] SPR_TILEFLIP;
	wire [19:0] SPR_TILE_NB;
	wire [7:0] SPR_TILE_PAL;
	wire [4:0] SPR_ROM_LINE;
	wire [7:0] SPR_XPOS;
	
	// Fix stuff
	wire [11:0] FIX_TILE_NB;
	wire [5:0] FIX_MAP_COL;			// 0~47
	wire [3:0] FIX_ATTR_PAL;
	
	// Timer stuff
	wire [2:0] TIMER_MODE;
	wire [31:0] TIMER_LOAD;
	wire [15:0] REG_LSPCMODE;
	
	wire [15:0] PBUS_S_ADDR;	// PBUS address for fix ROM
	wire [24:0] PBUS_C_ADDR;	// PBUS address for sprite ROMs
	wire [15:0] L0_ROM_ADDR;
	wire [7:0] L0_ROM_DATA;
	
	reg CA4_Q;
	reg S2H1_Q;
	
	wire K2_1;		// TODO
	wire K8_6;		// TODO
	wire nBFLIP;	// TODO
	wire SELJ5;		// TODO
	wire CLK_12M;	// TODO
	wire nCLK_12M;	// TODO
	wire nLATCH_X;	// TODO
	
	
	assign CLK_24MB = ~CLK_24M;
	assign SYNC = HSYNC ^ nVSYNC;
	
	assign CPU_WRITE_ACK = CPU_WRITE_ACK_SLOW & CPU_WRITE_ACK_FAST;
	assign CPU_WRITE_ACK_PULSE = CPU_WRITE_ACK & ~CPU_WRITE_ACK_PREV;
	
	always @(posedge CLK_24M)	// negedge ?
	begin
		if (CPU_WRITE_REQ)
			CPU_WRITE <= 1'b1;		// Set
		else
		begin
			if (CPU_WRITE_ACK_PULSE)
				CPU_WRITE <= 1'b0;	// Reset
		end
		
		CPU_WRITE_ACK_PREV <= CPU_WRITE_ACK;
	end
	
	// Fix stuff checked OK on DE1 board
	
	assign CA4 = H_COUNT[1];
	assign S2H1 = ~CA4;
	
	// CA4	''''|______|''''
	// PCK1	____|'|_________
	always @(negedge CLK_24M)
		CA4_Q <= CA4;
	assign PCK1 = (CA4_Q & !CA4);

	// 2H1	''''|______|''''
	// PCK2	____|'|_________
	always @(negedge CLK_24M)
		S2H1_Q <= S2H1;
	assign PCK2 = (S2H1_Q & !S2H1);
	
	// P bus values
	assign FIX_A4 = H_COUNT[2];		// Seems good
	assign PBUS_S_ADDR = {FIX_A4, V_COUNT[2:0], FIX_TILE_NB};
	
	

	// Alpha68k stuff:
	// K2
	assign K2_4 = K2_1 ? 1'b1 : nLATCH_X;	// TODO
	assign K2_7 = K2_1 ? nLATCH_X : 1'b1;
	assign K2_9 = K2_1 ? K8_6 : 1'b1;		// TODO
	assign K2_12 = K2_1 ? 1'b1 : K8_6;		// TODO
	
	// Opposite ?
	// K5:C
	assign LD1 = K2_7 & K2_12;
	// K5:?
	assign LD2 = K2_4 & K2_9;		// To check !
	
	// M12
	assign RBA = nBFLIP ? 1'b0 : CLK_RD;
	assign RBB = nBFLIP ? CLK_RD : 1'b0;
	assign CLK_EVEN_B = nBFLIP ? nCLK_12M : CLK_RD;
	assign CLK_EVEN_A = nBFLIP ? CLK_RD : nCLK_12M;
	// J5
	// SELJ5 comes from K5:A
	assign CLK_RD = SELJ5 ? nCLK_12M : 1'bz;	// TODO
	assign nCLEAR_WE = SELJ5 ? nCLK_12M : 1'b1;
	//always @(posedge SNKCLK_26)
	//	BFLIP <= 1'bz;	// TODO
	
	// P6
	assign nODD_WE = ~(DOTB & CLK_12M);
	assign nEVEN_WE = ~(DOTA & CLK_12M);
	// Second half of P6 in B1
	
	// N6 - WSE signals to B1
	assign nWE_ODD_A = nBFLIP ? nODD_WE : nCLEAR_WE;
	assign nWE_ODD_B = nBFLIP ? nCLEAR_WE : nODD_WE;
	assign nWE_EVEN_A = nBFLIP ? nEVEN_WE : nCLEAR_WE;
	assign nWE_EVEN_B = nBFLIP ? nCLEAR_WE : nEVEN_WE;
	
	
	assign IRQ_S3 = VBLANK;		// Timing to check
	
	// CPU VRAM read buffer switch between slow and fast VRAM depending on last access
	// This is probably wrong
	assign CPU_VRAM_READ_BUFFER = CPU_VRAM_ZONE ? CPU_VRAM_READ_BUFFER_FCY : CPU_VRAM_READ_BUFFER_SCY;
	
	// CPU VRAM read
	// Todo: See if M68K_ADDR[3] is used or not (msvtech.txt says no, MAME says yes)
	assign M68K_DATA = (nLSPOE | ~nLSPWE) ? 16'bzzzzzzzzzzzzzzzz :
								(M68K_ADDR[2] == 1'b0) ? CPU_VRAM_READ_BUFFER :		// $3C0000,$3C0002,$3C0008,$3C000A
								(M68K_ADDR[1] == 1'b0) ? REG_VRAMMOD :					// 3C0004/3C000C
								REG_LSPCMODE;													// 3C0006/3C000E
	
	lspc_regs REGS(nRESET, CLK_24M, M68K_ADDR, M68K_DATA, nLSPOE, nLSPWE, PCK1, AA_COUNT, V_COUNT[7:0],
					VIDEO_MODE, REG_LSPCMODE,
					CPU_VRAM_ZONE, CPU_WRITE_REQ, CPU_VRAM_ADDR, CPU_VRAM_WRITE_BUFFER,
					RELOAD_REQ_SLOW, RELOAD_REQ_FAST,
					TIMER_LOAD, TIMER_PAL_STOP, REG_VRAMMOD, TIMER_MODE, TIMER_IRQ_EN,
					AA_SPEED, AA_DISABLE,
					IRQ_S1, IRQ_R1, IRQ_S2, IRQ_R2, IRQ_R3);
	
	lspc_timer TIMER(nRESET, CLK_6M_LSPC, VBLANK, VIDEO_MODE, TIMER_MODE, TIMER_INT_EN, TIMER_LOAD,
							TIMER_PAL_STOP, V_COUNT);
	
	resetp RSTP(CLK_24M, nRESET, nRESETP);
	
	irq IRQ(IRQ_S1, IRQ_R1, IRQ_S2, IRQ_R2, IRQ_S3, IRQ_R3, IPL0, IPL1);		// Probably uses nRESETP
	
	videosync VS(CLK_24M, nRESETP, V_COUNT, H_COUNT, TMS0, VBLANK, nVSYNC, HSYNC, nBNKB, CHBL, FIX_MAP_COL);

	odd_clk ODDCLK(CLK_24M, nRESETP, CLK_8M, CLK_4M, CLK_4MB);
	
	// This needs to be simpler
	slow_cycle SCY(CLK_24M, nRESETP, H_COUNT[1:0], PCK1, PCK2, FIX_MAP_COL, V_COUNT[7:3],
					SPR_NB, SPR_TILEIDX,	SPR_TILE_NB,
					SPR_TILE_PAL, SPR_ATTR_AA, SPR_TILEFLIP, FIX_TILE_NB, FIX_ATTR_PAL,
					REG_VRAMMOD[14:0], RELOAD_REQ_SLOW,
					CPU_VRAM_ADDR, CPU_VRAM_READ_BUFFER_SCY, CPU_VRAM_WRITE_BUFFER,
					CPU_VRAM_ZONE, CPU_WRITE, CPU_WRITE_ACK_SLOW);
	
	// Todo: this needs to give SPR_NB, SPR_TILEIDX, SPR_XPOS, L0_ADDR, SPR_ATTR_SHRINK
	// Todo: this needs L0_DATA (from P bus)
	fast_cycle FCY(CLK_24M, nRESETP,
					REG_VRAMMOD[10:0], RELOAD_REQ_FAST,
					CPU_VRAM_ADDR[10:0], CPU_VRAM_READ_BUFFER_FCY, CPU_VRAM_WRITE_BUFFER,
					CPU_VRAM_ZONE, CPU_WRITE, CPU_WRITE_ACK_FAST);
	
	// This needs SPR_XPOS, L0_ADDR
	p_cycle PCY(nRESET, CLK_24M, PBUS_S_ADDR, FIX_ATTR_PAL, PBUS_C_ADDR, SPR_TILE_PAL, SPR_XPOS, L0_ROM_ADDR,
					S1H1, nVCS, L0_ROM_DATA, {PBUS_IO, PBUS_OUT});
	
	autoanim AA(nRESET, VBLANK, AA_SPEED, SPR_TILE_NB[2:0], AA_DISABLE, SPR_ATTR_AA, SPR_TILE_NB_AA, AA_COUNT);
	
	hshrink HSHRINK(SPR_ATTR_SHRINK[11:8], SPR_PIXELCNT, WR_PIXEL);
	
	// Alpha68k LOAD is CLK_C & SNKCLK_8. 6M & 3M ?
	//assign LOAD = CLK_C & SNKCLK_8;
		
	// One address = 32bit of data = 8 pixels
	// 16,0 17,1 18,2 19,3 ... 31,15
	assign PBUS_C_ADDR = {{SPR_TILE_NB[19:3], SPR_TILE_NB_AA}, SPR_ROM_LINE};
	
endmodule
