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

`include "define_state.h"

// This is the top module
// It connects the UART, SRAM and VGA together.
// It gives access to the SRAM for UART and VGA
module project1 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_N_I,         // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[19:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable

		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal
);

parameter	no_cols = 16'd320,
				no_rows = 16'd240,
				Q_Matrix = 2'd0;

logic resetn;

top_state_type top_state;

// For Push button
logic [3:0] PB_pushed;

// For SRAM
logic [19:0] SRAM_address;
logic [15:0] SRAM_write_data;
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

// For UART SRAM interface
logic UART_rx_enable;
logic UART_rx_initialize;
logic [19:0] UART_SRAM_address;
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

// For ColourspaceConversion_Downsample (CSCD)
logic [19:0] CSCD_SRAM_address;
logic [15:0] CSCD_SRAM_write_data;
logic CSCD_enable, CSCD_finished, CSCD_SRAM_we_n;

// For (DCT)
logic [19:0] DCT_SRAM_address;
logic [15:0] DCT_SRAM_write_data;
logic DCT_enable, DCT_finished, DCT_SRAM_we_n;

// For the 4 common 32-bit multipliers
logic [63:0] MUL1, MUL2, MUL3, MUL4;
logic signed [31:0] MUL1_OP_A, MUL1_OP_B,
				 MUL2_OP_A, MUL2_OP_B,
				 MUL3_OP_A, MUL3_OP_B,
				 MUL4_OP_A, MUL4_OP_B;
logic signed [31:0] MUL1_CSCD_OP_A, MUL1_CSCD_OP_B,
				 MUL2_CSCD_OP_A, MUL2_CSCD_OP_B,
				 MUL3_CSCD_OP_A, MUL3_CSCD_OP_B,
				 MUL4_CSCD_OP_A, MUL4_CSCD_OP_B;
logic signed [31:0] MUL1_DCT_OP_A, MUL1_DCT_OP_B,
				 MUL2_DCT_OP_A, MUL2_DCT_OP_B,
				 MUL3_DCT_OP_A, MUL3_DCT_OP_B,
				 MUL4_DCT_OP_A, MUL4_DCT_OP_B;
				 
logic [6:0] value_7_segment [7:0];

// For error detection in UART
logic Frame_error;

// For disabling UART transmit
assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

// Instantiate the 4 common 32-bit multipliers
assign MUL1 = MUL1_OP_A * MUL1_OP_B;
assign MUL2 = MUL2_OP_A * MUL2_OP_B;
assign MUL3 = MUL3_OP_A * MUL3_OP_B;
assign MUL4 = MUL4_OP_A * MUL4_OP_B;

// Push Button unit
PB_controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_N_I),
	.PB_pushed(PB_pushed)
);

// UART SRAM interface
UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn),

	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),

	// For accessing SRAM
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

// SRAM unit
SRAM_controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),
	.SRAM_ready(SRAM_ready),

	// To the SRAM pins
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);

// ColourspaceConversion_Downsample (CSCD) Unit
ColourspaceConversion_Downsample #(
		.no_cols(no_cols),
		.no_rows(no_rows)) CSCD_UNIT(
   .Clock(CLOCK_50_I),
   .Resetn(~SWITCH_I[17]),
   .enable(CSCD_enable),
	.finished(CSCD_finished),
   .SRAM_read_data(SRAM_read_data),
	.SRAM_address(CSCD_SRAM_address),
	.SRAM_write_data(CSCD_SRAM_write_data),
	.MUL1_OP_A(MUL1_CSCD_OP_A), 
	.MUL1_OP_B(MUL1_CSCD_OP_B),
   .MUL2_OP_A(MUL2_CSCD_OP_A), 
	.MUL2_OP_B(MUL2_CSCD_OP_B),
   .MUL3_OP_A(MUL3_CSCD_OP_A), 
	.MUL3_OP_B(MUL3_CSCD_OP_B),
   .MUL4_OP_A(MUL4_CSCD_OP_A), 
	.MUL4_OP_B(MUL4_CSCD_OP_B),
	.MUL1(MUL1), 
	.MUL2(MUL2), 
	.MUL3(MUL3),
	.MUL4(MUL4),
	.SRAM_we_n(CSCD_SRAM_we_n)
);

// (DCT) Unit
DCT #(
		.no_cols(no_cols),
		.no_rows(no_rows),
		.Q_Matrix(Q_Matrix))
		DCT_UNIT(
   .Clock(CLOCK_50_I),
   .Resetn(~SWITCH_I[17]),
   .enable(DCT_enable),
	.finished(DCT_finished),
   .SRAM_read_data(SRAM_read_data),
	.SRAM_address(DCT_SRAM_address),
	.SRAM_write_data(DCT_SRAM_write_data),
	.MUL1_OP_A(MUL1_DCT_OP_A), 
	.MUL1_OP_B(MUL1_DCT_OP_B),
   .MUL2_OP_A(MUL2_DCT_OP_A), 
	.MUL2_OP_B(MUL2_DCT_OP_B),
   .MUL3_OP_A(MUL3_DCT_OP_A), 
	.MUL3_OP_B(MUL3_DCT_OP_B),
   .MUL4_OP_A(MUL4_DCT_OP_A), 
	.MUL4_OP_B(MUL4_DCT_OP_B),
	.MUL1(MUL1), 
	.MUL2(MUL2), 
	.MUL3(MUL3),
	.MUL4(MUL4),
	.SRAM_we_n(DCT_SRAM_we_n)
);

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;

		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		
		CSCD_enable <= 1'b0;
		
	end else begin
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;

		// Timer for timeout on UART
		// This counter reset itself every time a new data is received on UART
		if (UART_rx_initialize | ~UART_SRAM_we_n) UART_timer <= 26'd0;
		else UART_timer <= UART_timer + 26'd1;

		case (top_state)
		S_IDLE: begin
			if (~UART_RX_I | PB_pushed[0]) begin
				// UART detected a signal, or PB0 is pressed
				UART_rx_initialize <= 1'b1;
				top_state <= S_ENABLE_UART_RX;
			end
		end
		S_ENABLE_UART_RX: begin
			// Enable the UART receiver
			UART_rx_enable <= 1'b1;
			top_state <= S_WAIT_UART_RX;
		end
		S_WAIT_UART_RX: begin
			if (UART_timer == 26'd49999999) begin
				// Timeout for 1 sec on UART for detecting if file transmission is finished
				UART_rx_initialize <= 1'b1;
				// Begin CSCD 
				CSCD_enable <= 1'b1;
				top_state <= S_CSCD_AWAITE;
			end
		end
		S_CSCD_AWAITE: begin
			CSCD_enable <= 1'b0;
			if (CSCD_finished) begin
				top_state <= S_DCT_AWAITE;
				DCT_enable <= 1'b1;
			end
		end
		S_DCT_AWAITE: begin
			DCT_enable <= 1'b0;
			if (DCT_finished) begin
				top_state <= S_IDLE;
			end
		end
		default: top_state <= S_IDLE;
		endcase
	end
end


// Give access to SRAM for UART and other modules at appropriate time
always_comb begin
	SRAM_address = 20'h0;
	SRAM_write_data = 16'h0;
	SRAM_we_n = 1'b1;
	MUL1_OP_A = 32'h0;
	MUL1_OP_B = 32'h0;
	MUL2_OP_A = 32'h0;
	MUL2_OP_B = 32'h0;
	MUL3_OP_A = 32'h0;
	MUL3_OP_B = 32'h0;
	MUL4_OP_A = 32'h0;
	MUL4_OP_B = 32'h0;
	
	case(top_state)
		S_ENABLE_UART_RX, S_WAIT_UART_RX: begin
			SRAM_address = UART_SRAM_address;
			SRAM_write_data = UART_SRAM_write_data;
			SRAM_we_n = UART_SRAM_we_n;
		end
		S_CSCD_AWAITE: begin
			SRAM_address = CSCD_SRAM_address;
			SRAM_write_data = CSCD_SRAM_write_data;
			SRAM_we_n = CSCD_SRAM_we_n;
			MUL1_OP_A = MUL1_CSCD_OP_A;
			MUL1_OP_B = MUL1_CSCD_OP_B;
			MUL2_OP_A = MUL2_CSCD_OP_A;
			MUL2_OP_B = MUL2_CSCD_OP_B;
			MUL3_OP_A = MUL3_CSCD_OP_A;
			MUL3_OP_B = MUL3_CSCD_OP_B;
			MUL4_OP_A = MUL4_CSCD_OP_A;
			MUL4_OP_B = MUL4_CSCD_OP_B;
		end
		S_DCT_AWAITE: begin
			SRAM_address = DCT_SRAM_address;
			SRAM_write_data = DCT_SRAM_write_data;
			SRAM_we_n = DCT_SRAM_we_n;
			MUL1_OP_A = MUL1_DCT_OP_A;
			MUL1_OP_B = MUL1_DCT_OP_B;
			MUL2_OP_A = MUL2_DCT_OP_A;
			MUL2_OP_B = MUL2_DCT_OP_B;
			MUL3_OP_A = MUL3_DCT_OP_A;
			MUL3_OP_B = MUL3_DCT_OP_B;
			MUL4_OP_A = MUL4_DCT_OP_A;
			MUL4_OP_B = MUL4_DCT_OP_B;
		end
	endcase
	
end

// 7 segment displays
convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_read_data[15:12]),
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_read_data[11:8]),
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_read_data[7:4]),
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_read_data[3:0]),
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value(SRAM_address[19:16]),
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[15:12]),
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[11:8]),
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[7:4]),
	.converted_value(value_7_segment[0])
);

assign
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_GREEN_O = {resetn, ~SRAM_we_n, Frame_error, top_state};

endmodule
