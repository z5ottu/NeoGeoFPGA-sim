`timescale 1ns/1ns

module FDRCell(
	input CK,
	input [3:0] D,
	input nCL,
	output reg [3:0] Q = 4'd0
);

	always @(posedge CK or posedge ~nCL)
	begin
		if (!nCL)
			Q <= 4'd0;
		else
			Q <= D;
	end

endmodule
