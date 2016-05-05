`timescale 1ns/1ns

module ym_ssg(
	input PHI_S,
	output [5:0] ANA,
	
	input [11:0] SSG_FREQ_A, SSG_FREQ_B, SSG_FREQ_C,
	input [4:0] SSG_NOISE,
	input [5:0] SSG_EN,
	input [4:0] SSG_VOL_A, SSG_VOL_B, SSG_VOL_C,
	input [15:0] SSG_ENV_FREQ,
	input [3:0] SSG_ENV
);

	reg [11:0] CNT_A, CNT_B, CNT_C;
	reg [4:0] CNT_NOISE;
	reg [17:0] LFSR;
	reg [15:0] CNT_ENV;
	
	reg ENV_RUN;
	reg [3:0] ENV_STEP;
	reg [3:0] ENV_ATTACK;
	reg OSC_A, OSC_B, OSC_C;
	reg NOISE;
	
	wire [3:0] OUT_A, OUT_B, OUT_C;
	wire [3:0] LEVEL_A, LEVEL_B, LEVEL_C;
	wire [3:0] ENV_VOL;
	
	assign ENV_VOL = ENV_STEP ^ ENV_ATTACK;
	
	assign LEVEL_A = SSG_VOL_A[4] ? ENV_VOL : SSG_VOL_A[3:0];
	assign LEVEL_B = SSG_VOL_B[4] ? ENV_VOL : SSG_VOL_B[3:0];
	assign LEVEL_C = SSG_VOL_C[4] ? ENV_VOL : SSG_VOL_C[3:0];
	// Gate: (OSC | nOSCEN) & (NOISE | nNOISEEN)
	assign OUT_A = ((OSC_A | SSG_EN[0]) & (NOISE | SSG_EN[3])) ? LEVEL_A : 4'b0000;
	assign OUT_B = ((OSC_B | SSG_EN[1]) & (NOISE | SSG_EN[4])) ? LEVEL_B : 4'b0000;
	assign OUT_C = ((OSC_C | SSG_EN[2]) & (NOISE | SSG_EN[5])) ? LEVEL_C : 4'b0000;
	
	assign ANA = OUT_A + OUT_B + OUT_C;

	always @(posedge PHI_S)		// ?
	begin
		if (CNT_A)
			CNT_A <= CNT_A - 1;
		else
		begin
			CNT_A <= SSG_FREQ_A;
			OSC_A <= ~OSC_A;
		end
		
		if (CNT_B)
			CNT_B <= CNT_B - 1;
		else
		begin
			CNT_B <= SSG_FREQ_B;
			OSC_B <= ~OSC_B;
		end
		
		if (CNT_C)
			CNT_C <= CNT_C - 1;
		else
		begin
			CNT_C <= SSG_FREQ_C;
			OSC_C <= ~OSC_C;
		end
		
		if (CNT_NOISE)
			CNT_NOISE <= CNT_NOISE - 1;
		else
		begin		
			CNT_NOISE <= SSG_NOISE;
			if (LFSR[0] ^ LFSR[1]) NOISE <= ~NOISE;
			if (LFSR[0])
			begin
				LFSR[17] <= ~LFSR[17];
				LFSR[14] <= ~LFSR[14];
			end
			LFSR <= {1'b0, LFSR[17:1]};
		end
		
		// Todo: Set ENV_ATTACK to 0000 or 1111 according to SSG_ENV[2] when write
		if (ENV_RUN)
		begin
			if (CNT_ENV)
				CNT_ENV <= CNT_ENV - 1;
			else
			begin
				CNT_ENV <= SSG_ENV_FREQ;
				if (ENV_STEP)
					ENV_STEP <= ENV_STEP - 1;
				else
				begin
					if (SSG_ENV[0])	// Hold
					begin
						if (SSG_ENV[1]) ENV_ATTACK <= ~ENV_ATTACK;	// Alt
						ENV_RUN <= 0;
					end
					else
					begin
						if (SSG_ENV[1]) ENV_ATTACK <= ~ENV_ATTACK;	// Alt
						// Todo: wrong and missing things here
					end
				end
			end
		end
	end
	
endmodule
