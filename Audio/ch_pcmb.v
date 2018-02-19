// NeoGeo logic definition (simulation only)
// Copyright (C) 2018 Sean Gonsalves
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

module ch_pcmb(
	input CLK,
	input TICK_144,
	input CLK_SAMP,
	input nRESET,
	input FLAGMASK,
	output reg END_FLAG,
	input START, RESET, REPEAT,
	
	input [7:0] VOL,
	input [1:0] PAN,
	input [15:0] PCMB_DELTA,
	
	input [15:0] ADDR_START,
	input [15:0] ADDR_STOP,
	
	output [21:0] ROM_ADDR,
	input [7:0] ROM_DATA,
	output reg [15:0] SAMPLE_OUT,
	output reg ACCESS
);

	reg [1:0] ROM_BANK;
	reg [19:0] ADDR_CNT;
	reg NIBBLE;
	reg signed [15:0] ADPCM_ACC;
	reg [3:0] DATA;
	reg [9:0] ADPCM_STEP;
	
	reg SET_FLAG;
	reg PREV_FLAGMASK;
	
	reg DELTA_OVF;
	reg [15:0] DELTA_CNT;
	
	reg RUN;
	reg [19:0] SR_1;
	reg [19:0] RESULT_B1;
	
	wire [3:0] TABLE_B1_ADDR;
	wire signed [4:0] TABLE_B1_OUT;
	reg signed [4:0] TABLE_OUT;
	wire [2:0] TABLE_B2_ADDR;		// 3:0 but 2x repeat
	wire signed [7:0] TABLE_B2_OUT;
	
	assign ROM_ADDR = { ROM_BANK, ADDR_CNT };
	
	pcmb_tables u1(DATA, TABLE_B1_OUT, DATA[2:0], TABLE_B2_OUT);
	
	always @(posedge CLK)
	begin
		if (!nRESET)
		begin
			SET_FLAG <= 0;			// ?
			PREV_FLAGMASK <= 0;	// ?
			RUN <= 0;
			ACCESS <= 0;			// ?
		end
		else
		begin
		
			// MUL-1
			// Multiplier = smaller
			// Init SR_1 with Acc (sign extend !), clear RESULT_B1
			// Acc min/max: -32768/32767 (16bit signed)
			// TABLE_OUT min/max: -15/15 (5bit signed)
			// RESULT_B1: 16+5-1 = 20 bits
			if (TABLE_B1_OUT[0])
				RESULT_B1 <= RESULT_B1 + SR_1;
			TABLE_OUT <= TABLE_OUT >>> 1;		// ASR
			// Cap isn't needed ?
			SR_1 <= { SR_1[18:0], 1'b0 };	// LSL
			
			// MUL-2
			// Multiplier = smaller
			// Init SR and MULTIPLIER, clear RESULT
			// Acc min/max: 24/24576 (16bit unsigned)
			// MULTIPLIER min/max: 57/153 (8bit unsigned)
			/*
			if (MULTIPLIER[0])
				RESULT <= RESULT + SR;
			MULTIPLIER <= { 1'b0, MULTIPLIER[3:1] };	// Shift right
			SR <= { SR[2:0], 1'b0 };	// Shift left
			*/
		
			if (RESET)
			begin
				// ???
			end
			
			if (START)
			begin
				ADDR_CNT <= { ADDR_START[11:0], 8'h0 };
				ROM_BANK <= ADDR_START[13:12];	// Should be 4 bits in real YM2610 (16M ROMs max., not 4M)
				ADPCM_STEP <= 0;
				ADPCM_ACC <= 0;
				NIBBLE <= 0;		// ?
				DELTA_OVF <= 0;
				DELTA_CNT <= 0;
				END_FLAG <= 0;
				RUN <= 1;
				ACCESS <= 0;		// ?
			end
			
			if (RUN & TICK_144)
			begin
				{ DELTA_OVF, DELTA_CNT } <= DELTA_CNT + PCMB_DELTA;
				if (DELTA_OVF)
				begin
					DELTA_CNT <= 0;
					DELTA_OVF <= 0;
					ACCESS <= 1;			// Probably simpler
				end
			end
			
			// Get one sample:
			if (RUN && CLK_SAMP)
			begin
				ACCESS <= 0;				// Probably simpler
				
				// Edge detect, clear flag
				if ((FLAGMASK == 1) && (PREV_FLAGMASK == 0))
					END_FLAG <= 0;
				
				PREV_FLAGMASK <= FLAGMASK;
				
				if (ADDR_CNT[19:8] == ADDR_STOP[11:0])
				begin
					if (REPEAT)
					begin
						ADDR_CNT <= { ADDR_START[11:0], 8'h0 };
						ROM_BANK <= ADDR_START[13:12];	// Should be 4 bits in real YM2610 (16M ROMs max., not 4M)
						ADPCM_STEP <= 0;
						ADPCM_ACC <= 0;
						NIBBLE <= 0;		// ?
					end
					else
					begin
						// Edge detect, set flag if not masked
						if (SET_FLAG == 0)
						begin
							SET_FLAG <= 1;
							END_FLAG <= ~FLAGMASK;
						end
					end
				end
				else
				begin
					SET_FLAG <= 0;
				
					if (NIBBLE)
					begin
						DATA <= ROM_DATA[3:0];
						ADDR_CNT <= ADDR_CNT + 1'b1;
					end
					else
						DATA <= ROM_DATA[7:4];
					
					ADPCM_ACC <= ADPCM_ACC + RESULT_B1;
					//ADPCM_DELTA <= ADPCM_DELTA + MUL2_OUT;
					
					case (DATA[2:0])
						0, 1, 2, 3 :
						begin
							if (ADPCM_STEP >= 16)
								ADPCM_STEP <= ADPCM_STEP - 10'd16;
							else
								ADPCM_STEP <= 0;
						end
						4 :
						begin
							if (ADPCM_STEP <= (768 - 32))
								ADPCM_STEP <= ADPCM_STEP + 10'd32;
							else
								ADPCM_STEP <= 768;
						end
						5 :
						begin
							if (ADPCM_STEP <= (768 - 80))
								ADPCM_STEP <= ADPCM_STEP + 10'd80;
							else
								ADPCM_STEP <= 768;
						end
						6 :
						begin
							if (ADPCM_STEP <= (768 - 112))
								ADPCM_STEP <= ADPCM_STEP + 10'd112;
							else
								ADPCM_STEP <= 768;
						end
						7 :
						begin
							if (ADPCM_STEP <= (768 - 144))
								ADPCM_STEP <= ADPCM_STEP + 10'd144;
							else
								ADPCM_STEP <= 768;
						end
					endcase
					
					// Sign-extend 12 to 16
					SAMPLE_OUT <= ADPCM_ACC[11] ? { 4'b1111, ADPCM_ACC } : { 4'b0000, ADPCM_ACC };
					
					NIBBLE <= ~NIBBLE;
				end
			end
		end
	end

endmodule
