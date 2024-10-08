/*
Copyright by Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

// This module emulates the external SRAM device during simulation
module tb_SRAM_Emulator (
	input logic Clock_50,
	input logic Resetn,

	inout wire [15:0] SRAM_data_io,
	input logic [19:0] SRAM_address,
	input logic SRAM_UB_N,
	input logic SRAM_LB_N,
	input logic SRAM_WE_N,
	input logic SRAM_CE_N,
	input logic SRAM_OE_N
);

// we use ALL 20 address lines for the project
parameter SRAM_SIZE = 1048576; // 2^20

logic Clock_100;

// 2 MB SRAM
logic [15:0] SRAM_data [SRAM_SIZE-1:0];
logic [15:0] SRAM_read_data;

// Generate the 100 MHz clock
initial begin
	@ (posedge Clock_50);
	@ (negedge Clock_50);
	// This makes sure the clocks are in-phase
	Clock_100 = 1'b1;
	forever begin
		#5;
		Clock_100 = ~Clock_100;
	end
end

// For writing into the SRAM
always_ff @ (posedge Clock_100 or negedge Resetn) begin : SRAM
	integer i;

	if (Resetn == 1'b0) begin
		for (i = 0; i < SRAM_SIZE; i++)
			SRAM_data[i] <= 16'd0;
	end else begin
		if (SRAM_OE_N == 1'b0 && SRAM_CE_N == 1'b0) begin
			if (SRAM_UB_N == 1'b0) begin
				if (SRAM_WE_N == 1'b0) begin
					SRAM_data[SRAM_address] <= SRAM_data_io;
				end
			end
		end
	end
end

// For reading the SRAM
always_ff @ (negedge Clock_100 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		SRAM_read_data <= 16'd0;
	end else begin
		if (SRAM_OE_N == 1'b0 && SRAM_CE_N == 1'b0) begin
			if (SRAM_UB_N == 1'b0) begin
				if (SRAM_WE_N == 1'b1) begin
					SRAM_read_data <= SRAM_data[SRAM_address];
				end
			end
		end
	end
end

// The bidirectional pin
assign SRAM_data_io = (SRAM_OE_N == 1'b0 && SRAM_CE_N == 1'b0 && SRAM_WE_N == 1'b0) ? 16'hzzzz : SRAM_read_data;

endmodule
