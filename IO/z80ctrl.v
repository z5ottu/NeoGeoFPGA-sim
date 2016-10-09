`timescale 1ns/1ns

module z80ctrl(
	input [4:2] SDA_L,			// Ok, used for port decode
	input [15:11] SDA_U,			// Ok, used for memory zone decode
	input nSDRD, nSDWR,			// Ok
	input nMREQ, nIORQ,			// Ok
	input nSDW,						// Ok, signal from NEO-C1
	input nRESET,
	output reg nZ80NMI,			// Ok
	output nSDZ80R, nSDZ80W,	// Ok
	output nSDZ80CLR,				// Ok, signal to NEO-C1
	output nSDROM,					// Ok
	output nSDMRD, nSDMWR,		// Ok
	output SDRD0, SDRD1,			// What is SDRD1 ?
	output n2610CS,				// Ok
	output n2610RD, n2610WR,	// Ok
	output nZRAMCS					// Ok
);

	reg nNMI_EN;
	
	// $0000~$F7FF: ROM 00000000 00000000 ~ 11110111 11111111
	// $F800~$FFFF: RAM 11111000 00000000 ~ 11111111 11111111
	assign nSDROM = &{SDA_U};	// Called "SROM" on schematics
	assign nZRAMCS = ~nSDROM;	// Called "SROMB" on schematics, so guessing this is right

	assign nSDMRD = nMREQ | nSDRD;
	assign nSDMWR = nMREQ | nSDWR;
	
	assign n2610RD = nIORQ | nSDRD;
	assign n2610WR = nIORQ | nSDWR;

	assign nTRIGNMI = nNMI_EN | nSDW;
	
	// Port $x0, $x1, $x2, $x3 read
	assign nSDZ80R = (~nSDWR | nIORQ | SDA_L[3] | SDA_L[2]);
	// Set/ack NMI
	always @(negedge nRESET or negedge nSDZ80R or negedge nTRIGNMI)
	begin
		if (!nRESET)
		begin
			nZ80NMI <= 1'b1;	// ?
		end
		else
		begin
			if (!nSDZ80R)
				nZ80NMI <= 1'b1;
			else
				nZ80NMI <= 1'b0;
		end
	end
	
	// Port $x0, $x1, $x2, $x3 write
	assign nSDZ80CLR = (nSDWR | nIORQ | SDA_L[3] | SDA_L[2]);
	
	// Port $x4, $x5, $x6, $x7 any access
	// TODO: Check this on real hw, why is a /CS needed for the YM2610 ? Avoids reset or power off glitches ?
	assign n2610CS = 1'b0;
	//assign n2610CS = (nIORQ | SDA_L[3] | ~SDA_L[2]);
	
	// Port $xC, $xD, $xE, $xF write
	assign nSDZ80W = (nSDWR | nIORQ | ~(SDA_L[3] & SDA_L[2]));
	
	// Port $x8, $x9, $xA, $xB read
	assign nSDRD0 = (~nSDWR | nIORQ | ~SDA_L[3] | SDA_L[2]);
	// What is nSDRD1 ? Ports $xC, $xD, $xE, $xF read ?
	
	// Port $x8, $x9, $xA, $xB write
	always @(negedge nRESET or negedge nSDWR)
	begin
		if (!nRESET)
		begin
			nNMI_EN <= 1'b1;	// ?
		end
		else
		begin
			if ((!nIORQ) && (SDA_L[3:2] == 2'b10)) nNMI_EN <= SDA_L[4];	// NMI enable/disable
		end
	end
	
endmodule
