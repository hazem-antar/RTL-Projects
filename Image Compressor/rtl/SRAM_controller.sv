/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

// This module generates the protocol signals to communicate
// with the external SRAM (using a 2 clock cycle latency)
module SRAM_controller (
		input logic Clock_50,
		input logic Resetn,

		input logic [19:0] SRAM_address,
		input logic [15:0] SRAM_write_data,
		input logic SRAM_we_n,
		output logic [15:0] SRAM_read_data,

		output logic SRAM_ready,

		// To the SRAM pins
		inout wire [15:0] SRAM_DATA_IO,
		output logic[19:0] SRAM_ADDRESS_O,
		output logic SRAM_UB_N_O,
		output logic SRAM_LB_N_O,
		output logic SRAM_WE_N_O,
		output logic SRAM_CE_N_O,
		output logic SRAM_OE_N_O
);

logic Clock_100;
logic Clock_100_locked;

logic [15:0] SRAM_write_data_buf;

`ifdef SIMULATION
	// Generate the 100 MHz clock
	initial begin
		@ (posedge Clock_50);
		@ (negedge Clock_50);
		// This makes sure the clocks are in-phase
		Clock_100 = 1'b1;
		Clock_100_locked = 1'b1;
		forever begin
			#5;
			Clock_100 = ~Clock_100;
		end
	end
`else
	// Use PLL for synthesis
	Clock_100_PLL	Clock_100_PLL_inst (
		.areset ( ~Resetn ),
		.inclk0 ( Clock_50 ),
		.c0 ( Clock_100 ),
		.locked ( Clock_100_locked )
	);
`endif

assign SRAM_ready = Resetn && Clock_100_locked;

always_ff @ (negedge Clock_100 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		SRAM_UB_N_O <= 1'b0;
		SRAM_LB_N_O <= 1'b0;
	end else begin
		SRAM_UB_N_O <= ~Clock_50;
		SRAM_LB_N_O <= ~Clock_50;
	end
end

// Buffering the signals before driving the external pins
always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		SRAM_CE_N_O <= 1'b1;
		SRAM_OE_N_O <= 1'b1;
		SRAM_ADDRESS_O <= 18'd0;
		SRAM_read_data <= 16'd0;
		SRAM_WE_N_O <= 1'b1;
		SRAM_write_data_buf <= 16'd0;
	end else begin
		SRAM_CE_N_O <= 1'b0;
		SRAM_OE_N_O <= 1'b0;
		SRAM_ADDRESS_O <= SRAM_address;
		SRAM_WE_N_O <= SRAM_we_n;
		SRAM_read_data <= SRAM_DATA_IO;
		SRAM_write_data_buf <= SRAM_write_data;
	end
end

assign SRAM_DATA_IO = (SRAM_WE_N_O == 1'b0) ? SRAM_write_data_buf : 16'hzzzz;

endmodule
