
`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This module reads an RGB image from SRAM, convert colourspace to YUV
// and then does a horizontal downsampling using FIR filter
module ColourspaceConversion_Downsample (
   input  logic        Clock,
   input  logic        Resetn,
   input  logic        enable,
	input  logic [63:0] MUL1, MUL2, MUL3, MUL4,
   input  logic [15:0] SRAM_read_data,
	output logic [19:0] SRAM_address,
	output logic [15:0] SRAM_write_data,
	output logic		  SRAM_we_n,
	output logic [31:0] MUL1_OP_A, MUL1_OP_B,
                       MUL2_OP_A, MUL2_OP_B,
                       MUL3_OP_A, MUL3_OP_B,
                       MUL4_OP_A, MUL4_OP_B,
	output logic		  finished
);

parameter	no_cols = 320,
				no_rows = 240;

// Dynamically calculate the column and row bit width
localparam COL_WIDTH = $clog2(no_cols + 10); // The extra 10 is needed as margin in the FSM
localparam ROW_WIDTH = $clog2(no_rows);
localparam RGB_Segment_Width = $clog2((no_rows * no_cols * 3) / 2);
localparam Y_Segment_Width = RGB_Segment_Width - 1;

// Dynamically calculate the Y, U', V' segments' base addresses (to be connected)
localparam	RGB_base_address = 20'd0,
				Y_base_address = 20'd614400,
				Ud_base_address = Y_base_address + (no_cols * no_rows) / 2,
				Vd_base_address = Ud_base_address + (no_cols * no_rows) / 4;
				
// Define index pointers for memory segments
logic [RGB_Segment_Width-1:0] RGB_pointer;
logic [Y_Segment_Width-1:0] Y_pointer; // Will be also used to access U` and V` by (Y/2)-2

// For buffering SRAM read data
logic [7:0] SRAM_read_data_Buffer;

// For Y, U, V
logic [7:0] Y_val, U_val, V_val; // Wires carrying final accumulation value of Y, U, V
logic [7:0] U, V;
logic [7:0] Y_Buffer [1:0];    // Y values buffer
logic [7:0] U_E_Buffer [2:0];  // U even values buffer
logic [7:0] V_E_Buffer [2:0];	 // V even values buffer
logic [7:0] U_O_Buffer [5:0];  // U odd values buffer
logic [7:0] V_O_Buffer [5:0];  // V odd values buffer
logic Y_Write_EN, UV_Buffer_EN;

// For U`, V`
logic [25:0] UVd_val;			  // Wire carrying final accumulation value of U` or V`
logic [7:0] UVd_val_clamped;    // Wire carrying clamped final accumulation value of U` or V`
logic Ud_Vd_Pair_Ready;         // U`,V` pairs ready
logic begin_Ud_Vd_Write;        // Beginning of writing U`,V` pairs
logic [7:0] Ud_Buffer [1:0];    // U` buffer
logic [7:0] Vd_Buffer [1:0];    // V` buffer

// Define the 4 MAC Units Accumulators
logic [25:0] Accumulator [3:0];

// For keeping track of current pixel location
logic [COL_WIDTH-1:0] pixel_X_pos;
logic [ROW_WIDTH-1:0] pixel_Y_pos;

CSCD_state_type CSCD_state;

always_ff @ (posedge Clock or negedge Resetn) begin

	if (Resetn == 1'b0) begin
	
		// Reset Signals
		CSCD_state <= S_CSCD_IDLE;
		RGB_pointer <= RGB_Segment_Width'('h0); 
		Y_pointer <= {{Y_Segment_Width-2{1'b1}}, 2'b10};     // Start at -2
		SRAM_write_data <= 16'd0;
		SRAM_we_n <= 1'b1;
		Ud_Vd_Pair_Ready <= 1'b0;  
		begin_Ud_Vd_Write <= 1'b0;
		Y_Write_EN <= 1'b0;
		UV_Buffer_EN <= 1'b1;
		pixel_X_pos <= COL_WIDTH'('d0);
		pixel_Y_pos <= ROW_WIDTH'('d0);
		U <= 8'h0;
		V <= 8'h0;
		
		// Zero-out Buffers
		SRAM_read_data_Buffer <= 8'h0;
		for (int i = 0; i < 2; i++) begin
			Y_Buffer[i] <= 8'h0;
			Ud_Buffer[i] <= 8'h0;
			Vd_Buffer[i] <= 8'h0;
		end
		for (int i = 0; i < 3; i++) begin
			U_E_Buffer[i] <= 8'h0;
			V_E_Buffer[i] <= 8'h0;
		end
		for (int i = 0; i < 6; i++) begin
			U_O_Buffer[i] <= 8'h0;
			V_O_Buffer[i] <= 8'h0;
		end
		
		// Zero-out Accumulators
		for (int i = 0; i < 4; i++) begin
			Accumulator[i] <= 26'h0;
		end
	end 
	else begin
	
		// Always buffer LSB of SRAM read data
		SRAM_read_data_Buffer <= SRAM_read_data[7:0];
		
		case (CSCD_state)
			S_CSCD_IDLE: begin
			
				// Reset Signals
				RGB_pointer <= RGB_Segment_Width'('h0);
				Y_pointer <= {{Y_Segment_Width-2{1'b1}}, 2'b10};     // Start at -2
				SRAM_write_data <= 16'd0;
				finished <= 1'b0;
				SRAM_we_n <= 1'b1;
				Ud_Vd_Pair_Ready <= 1'b0;  
				begin_Ud_Vd_Write <= 1'b0;
				Y_Write_EN <= 1'b0;
				UV_Buffer_EN <= 1'b1;
				pixel_X_pos <= COL_WIDTH'('d0);
				pixel_Y_pos <= ROW_WIDTH'('d0);
				U <= 8'h0;
				V <= 8'h0;
				
				// Zero-out Buffers
				SRAM_read_data_Buffer <= 8'h0;
				for (int i = 0; i < 2; i++) begin
					Y_Buffer[i] <= 8'h0;
					Ud_Buffer[i] <= 8'h0;
					Vd_Buffer[i] <= 8'h0;
				end
				for (int i = 0; i < 3; i++) begin
					U_E_Buffer[i] <= 8'h0;
					V_E_Buffer[i] <= 8'h0;
				end
				for (int i = 0; i < 6; i++) begin
					U_O_Buffer[i] <= 8'h0;
					V_O_Buffer[i] <= 8'h0;
				end
				
				// Zero-out Accumulators
				for (int i = 0; i < 4; i++) begin
					Accumulator[i] <= 26'h0;
				end
				
				// If CSCD is enabled, start processing the image
				if (enable) begin 
					CSCD_state <= S_CSCD_NEW_PIXEL_ROW;
				end
			end
			S_CSCD_NEW_PIXEL_ROW: begin  // S(0)
				CSCD_state <= S_CSCD_1;
				if (pixel_Y_pos == no_rows) begin  // All rows have been read
					finished <= 1'b1;
					CSCD_state <= S_CSCD_IDLE;
				end
				else begin
					if (pixel_Y_pos == COL_WIDTH'('d0)) begin  // First row in the image
						RGB_pointer <= RGB_Segment_Width'('h0);
					end
					else begin
						RGB_pointer <= RGB_pointer - RGB_Segment_Width'('d13);  // re-synchronize RGB reads
						Y_pointer <= Y_pointer - Y_Segment_Width'('d4);         // re-synchronize Y, U', V' writes
					end
				end
			end
			
			S_CSCD_1: begin
				CSCD_state <= S_CSCD_2;
			end
			
			S_CSCD_2: begin 
				// Increment the RGB_pointer
				RGB_pointer <= RGB_pointer + RGB_Segment_Width'('d1);
				CSCD_state <= S_CSCD_COM_0;
			end
			S_CSCD_COM_0: begin
			
				// Update the accumulators
				Accumulator[0] <= Accumulator[0] + MUL1;  // + FY(R)
				Accumulator[1] <= Accumulator[1] + MUL2;  // - FU(R)
				Accumulator[2] <= Accumulator[2] + MUL3;  // + FV(R)
				Accumulator[3] <= Accumulator[3] + MUL4 + (U_E_Buffer[2] << 8);  // + FU`(U[2j],U[2j-5],U[2j+5])
				
				// Write Y value pair only when the flag is set 
				if (Y_Write_EN) begin
					SRAM_write_data <= {Y_Buffer[1], Y_Buffer[0]};
					SRAM_we_n <= 1'b0;
				end
				
				// Increment the Y pointer
				Y_pointer <= Y_pointer + Y_Segment_Width'('d1);

				// Raise flag to start writing Y value pairs from
				// the second iteration of the common states
				if (pixel_X_pos == COL_WIDTH'('0)) begin 
					Y_Write_EN <= 1'b1;
				end
				
				// Starting from this pixel_X_pos value, raise flag to stop writing Y value pairs
			   //	and to stop putting new values in the U and V odd buffers (repeat last value)
				if (pixel_X_pos == no_cols) begin
					Y_Write_EN <= 1'b0;
					UV_Buffer_EN <= 1'b0;
				end

				CSCD_state <= S_CSCD_COM_1;
			end
			S_CSCD_COM_1: begin
			
				// Unset SRAM write-enable (in case it was set)
				SRAM_we_n <= 1'b1;
				
				// Increment the RGB_pointer
				RGB_pointer <= RGB_pointer + RGB_Segment_Width'('d1);
				
				// Update the accumulators
				Accumulator[0] <= Accumulator[0] + MUL1;  // + FY(G)
				Accumulator[1] <= Accumulator[1] + MUL2;  // - FU(G)
				Accumulator[2] <= Accumulator[2] + MUL3;  // - FV(G)
				Accumulator[3] <= Accumulator[3] + MUL4;  // - FU`(U[2j-3],U[2j+3])
				
				CSCD_state <= S_CSCD_COM_2;
			end
			S_CSCD_COM_2: begin
			
				// Zero-out Accumulators
				for (int i = 0; i < 4; i++) begin
					Accumulator[i] <= 26'h0;
				end
				
				// Append new Y value to the Y pair buffer
				Y_Buffer[1] <= Y_Buffer[0]; Y_Buffer[0] <= Y_val;
				
				// Store new U, V values
				U <= U_val;  
				V <= V_val;   
				
				// Append new U` value to the U` pair buffer
				Ud_Buffer[1] <= Ud_Buffer[0]; Ud_Buffer[0] <= UVd_val_clamped;   
				
				// If this is the first iteration, push the U and V 3 times in the odd buffer
				if (pixel_X_pos == COL_WIDTH'('0)) begin
					for (int i = 0; i < 3; i++) begin
						U_O_Buffer[i] <= U_val;
						V_O_Buffer[i] <= V_val;
					end
				end
				
				// If pairs of U` and V` are ready, write U` first to SRAM
				if (Ud_Vd_Pair_Ready) begin
					SRAM_write_data <= {Ud_Buffer[1], Ud_Buffer[0]};
					SRAM_we_n <= 1'b0;
				end
				
				CSCD_state <= S_CSCD_COM_3;
			end
			S_CSCD_COM_3: begin
			
				// Unset SRAM write-enable (in case it was set)
				SRAM_we_n <= 1'b1;
				
				// Increment the RGB_pointer
				RGB_pointer <= RGB_pointer + RGB_Segment_Width'('d1);
				
				// Update the accumulators
				Accumulator[0] <= Accumulator[0] + MUL1;  // + FY(R)
				Accumulator[1] <= Accumulator[1] + MUL2;  // - FU(R)
				Accumulator[2] <= Accumulator[2] + MUL3;  // + FV(R)
				Accumulator[3] <= Accumulator[3] + MUL4 + (V_E_Buffer[2] << 8);  // + FV`(V[2j],V[2j-5],V[2j+5])
				
				CSCD_state <= S_CSCD_COM_4;
			end
			S_CSCD_COM_4: begin
			
				// Update the accumulators
				Accumulator[0] <= Accumulator[0] + MUL1;  // + FY(G)
				Accumulator[1] <= Accumulator[1] + MUL2;  // - FU(G)
				Accumulator[2] <= Accumulator[2] + MUL3;  // - FV(G)
				Accumulator[3] <= Accumulator[3] + MUL4;  // - FV`(V[2j-3],V[2j+3])
				
				// Append the last calculated U and V to the even buffers
				U_E_Buffer[0] <= U;
				V_E_Buffer[0] <= V;
				for (int i = 0; i < 2; i++) begin
					U_E_Buffer[i+1] <= U_E_Buffer[i];
					V_E_Buffer[i+1] <= V_E_Buffer[i];
				end
				
				// If pairs of U` and V` are ready, write V` second to SRAM
				if (Ud_Vd_Pair_Ready) begin
					SRAM_write_data <= {Vd_Buffer[1], Vd_Buffer[0]};
					SRAM_we_n <= 1'b0;
				end
				
				CSCD_state <= S_CSCD_COM_5;
			end
			S_CSCD_COM_5: begin
				
				// Increment pixel_X_pos by 2 since 2 pixels were processed
				pixel_X_pos <= pixel_X_pos + COL_WIDTH'('d2);
	
				// Unset SRAM write-enable (in case it was set)
				SRAM_we_n <= 1'b1;
				
				// Increment the RGB_pointer
				RGB_pointer <= RGB_pointer + RGB_Segment_Width'('d1);
				
				// Zero-out Accumulators
				for (int i = 0; i < 4; i++) begin
					Accumulator[i] <= 26'h0;
				end
				
				// Append new Y value to the Y pair buffer
				Y_Buffer[1] <= Y_Buffer[0]; Y_Buffer[0] <= Y_val; 
				
				// Store new U, V values
				U <= U_val;
				V <= V_val;
				
				// Append new V` value to the V` pair buffer
				Vd_Buffer[1] <= Vd_Buffer[0]; 
				Vd_Buffer[0] <= UVd_val_clamped;
				
				// If the flag is set, append the new U, V to the odd buffer
				if (UV_Buffer_EN) begin
					U_O_Buffer[0] <= U_val;
					V_O_Buffer[0] <= V_val;
				end
				else begin // else, use the last appended values again
					U_O_Buffer[0] <= U_O_Buffer[0];
					V_O_Buffer[0] <= V_O_Buffer[0];
				end
				
				// Shift the buffer after appending
				for (int i = 0; i < 5; i++) begin
					U_O_Buffer[i+1] <= U_O_Buffer[i];
					V_O_Buffer[i+1] <= V_O_Buffer[i];
				end
				
				// Begin writing U` and V` pairs to SRAM
				if (pixel_X_pos == COL_WIDTH'('d8)) begin
					Ud_Vd_Pair_Ready <= 1'b1;
					begin_Ud_Vd_Write <= 1'b1;
				end
				
				// Alternate the pairs of U` and V` are ready flag
				// in every iteration of the common case states
				if (begin_Ud_Vd_Write) begin
					Ud_Vd_Pair_Ready <= ~Ud_Vd_Pair_Ready;
				end
				
				CSCD_state <= S_CSCD_COM_0;
				
				// End of row
				if (pixel_X_pos == no_cols + 6) begin
					UV_Buffer_EN <= 1'b1;
					begin_Ud_Vd_Write <= 1'b0;
					pixel_X_pos <= COL_WIDTH'('d0);
					pixel_Y_pos <= pixel_Y_pos + ROW_WIDTH'('d1);
					CSCD_state <= S_CSCD_NEW_PIXEL_ROW;
				end
			end
		endcase
	end
end
		
always_comb begin
	
	// Initialize the external multiplier operand wires
	MUL1_OP_A = 32'h0;
	MUL1_OP_B = 32'h0;
	MUL2_OP_A = 32'h0;
	MUL2_OP_B = 32'h0;
	MUL3_OP_A = 32'h0;
	MUL3_OP_B = 32'h0;
	MUL4_OP_A = 32'h0;
	MUL4_OP_B = 32'h0; 
	
	// By default, the SRAM address points to current location in RGB segment
	SRAM_address = RGB_pointer + RGB_base_address;
	
	// The last calculaion step of Y, U, V
	Y_val = (((Accumulator[0] + MUL1) + 16'd32768) >>> 16) + 8'd16;   // FY(B) = Y
	U_val = (((Accumulator[1] + MUL2) + 16'd32768) >>> 16) + 8'd128;  // FU(B) = U
	V_val = (((Accumulator[2] + MUL3) + 16'd32768) >>> 16) + 8'd128;  // FV(B) = V
	
	// The last calculaion step of U`, V` (before shifting and clamping)
	UVd_val = (Accumulator[3] + MUL4 + 9'd256);
	
	// Clamping U' and V'
	UVd_val_clamped = UVd_val[16:9]; // Default value, same as divide by 512
	 // if < 0
	if (UVd_val[25] == 1'b1) begin  
		UVd_val_clamped = 8'd0;
	end
	else begin // else if > 255
		if (UVd_val[17] == 1'b1) begin 
			UVd_val_clamped = 8'd255;
		end
	end
	
	// Switch case for assigning the multipliers operands and SRAM address
	case (CSCD_state)
		S_CSCD_COM_0 : begin 
			// Multipliers (1-3) operands, SRAM_read_data[15:8] holds Red value
			MUL1_OP_A = 32'd16843;
			MUL1_OP_B = SRAM_read_data[15:8];
			MUL2_OP_A = -32'd9699;
			MUL2_OP_B = SRAM_read_data[15:8];
			MUL3_OP_A = 32'd28770;
			MUL3_OP_B = SRAM_read_data[15:8];
			
			// Multiplier (4) operands
			MUL4_OP_A = 32'd22;
			MUL4_OP_B = U_O_Buffer[5] + U_O_Buffer[0]; 
		end
		S_CSCD_COM_1 : begin
			// SRAM address points current location in the Y segment
			SRAM_address = Y_pointer + Y_base_address;
			
			// Multipliers (1-3) operands, SRAM_read_data_Buffer holds green value
			MUL1_OP_A = 32'd33030;
			MUL1_OP_B = SRAM_read_data_Buffer;
			MUL2_OP_A = -32'd19071;
			MUL2_OP_B = SRAM_read_data_Buffer;
			MUL3_OP_A = -32'd24117;
			MUL3_OP_B = SRAM_read_data_Buffer;
			MUL4_OP_A = -32'd52;
			
			// Multiplier (4) operands
			MUL4_OP_B = U_O_Buffer[4] + U_O_Buffer[1]; 
		end
		S_CSCD_COM_2: begin		
			// Multipliers (1-3) operands, SRAM_read_data[15:8] holds blue value
			MUL1_OP_A = 32'd6423;
			MUL1_OP_B = SRAM_read_data[15:8];
			MUL2_OP_A = 32'd28770;
			MUL2_OP_B = SRAM_read_data[15:8];
			MUL3_OP_A = -32'd4653;
			MUL3_OP_B = SRAM_read_data[15:8];
			
			// Multiplier (4) operands
			MUL4_OP_A = 32'd159;
			MUL4_OP_B = U_O_Buffer[3] + U_O_Buffer[2]; 
		end
		S_CSCD_COM_3: begin
			// SRAM address points current location in the U segment
			SRAM_address = Y_pointer[Y_Segment_Width-1:1] - 2 + Ud_base_address;
			
			// Multipliers (1-3) operands, SRAM_read_data_Buffer holds red value
			MUL1_OP_A = 32'd16843;
			MUL1_OP_B = SRAM_read_data_Buffer;
			MUL2_OP_A = -32'd9699;
			MUL2_OP_B = SRAM_read_data_Buffer;
			MUL3_OP_A = 32'd28770;
			MUL3_OP_B = SRAM_read_data_Buffer;
			
			// Multipliers (4) operands
			MUL4_OP_A = 32'd22;
			MUL4_OP_B = V_O_Buffer[5] + V_O_Buffer[0]; 
		end
		S_CSCD_COM_4: begin
			// Multipliers (1-3) operands, SRAM_read_data[15:8] holds green value
			MUL1_OP_A = 32'd33030;
			MUL1_OP_B = SRAM_read_data[15:8];
			MUL2_OP_A = -32'd19071;
			MUL2_OP_B = SRAM_read_data[15:8];
			MUL3_OP_A = -32'd24117;
			MUL3_OP_B = SRAM_read_data[15:8];
			
			// Multiplier (4) operands
			MUL4_OP_A = -32'd52;
			MUL4_OP_B = V_O_Buffer[4] + V_O_Buffer[1]; 
		end
		S_CSCD_COM_5: begin
		   // SRAM address points current location in the V segment
			SRAM_address = Y_pointer[Y_Segment_Width-1:1] - 2 + Vd_base_address;
			
			// Multipliers (1-3) operands, SRAM_read_data_Buffer holds blue value
			MUL1_OP_A = 32'd6423;
			MUL1_OP_B = SRAM_read_data_Buffer;
			MUL2_OP_A = 32'd28770;
			MUL2_OP_B = SRAM_read_data_Buffer;
			MUL3_OP_A = -32'd4653;
			MUL3_OP_B = SRAM_read_data_Buffer;
			
			// Multiplier (4) operands
			MUL4_OP_A = 32'd159;
			MUL4_OP_B = V_O_Buffer[3] + V_O_Buffer[2]; 
		end
	endcase
	
end	
endmodule