`timescale 1ns/1ns

module FS3(
	input CK,
	input [3:0] P,
	input SD, nL,
	output reg [3:0] Q = 4'd0
);

	always @(posedge CK or posedge ~nL)
	begin
		if (!nL)
			Q <= P;					// Load
		else
			Q <= {Q[2:0], SD};	// Shift
	end

endmodule
