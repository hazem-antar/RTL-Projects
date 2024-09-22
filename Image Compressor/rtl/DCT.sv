
`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This module reads an RGB image from SRAM, convert colourspace to YUV
// and then does a horizontal downsampling using FIR filter
module DCT (
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

parameter	no_cols = 16'd320,
				no_rows = 16'd240,
				Q_Matrix = 2'd0;

// Dynamically calculate the column and row bit width
localparam COL_WIDTH = $clog2(no_cols + 10); // The extra 10 is needed as margin in the FSM
localparam ROW_WIDTH = $clog2(no_rows);

// Dynamically calculate the Y, U', V' segments' base addresses (to be connected)
localparam  Y_base_address = 20'd614400,
				Ud_base_address = Y_base_address + (no_cols * no_rows) / 2,
				Vd_base_address = Ud_base_address + (no_cols * no_rows) / 4,
				Encoded_Image_base_address = 20'd0;
				

// instantiate S Embedded RAM (Double port)
logic [6:0] S_Embedded_RAM_Address_A, S_Embedded_RAM_Address_B;
logic [31:0] S_Embedded_RAM_Write_Data_A, S_Embedded_RAM_Write_Data_B,
				 S_Embedded_RAM_Read_Data_A, S_Embedded_RAM_Read_Data_B;
logic S_Embedded_RAM_we_A, S_Embedded_RAM_we_B;

// To arbitrate the access through Fetch S and Compute T
logic [6:0] S_Embedded_RAM_Address_A_FS, S_Embedded_RAM_Address_A_CT,
				S_Embedded_RAM_Address_B_FS, S_Embedded_RAM_Address_B_CT;

DP_EmbeddedRAM S_Embedded_RAM (
	.address_a ( S_Embedded_RAM_Address_A ),
	.address_b ( S_Embedded_RAM_Address_B ),
	.clock ( Clock ),
	.data_a ( S_Embedded_RAM_Write_Data_A ),
	.data_b ( S_Embedded_RAM_Write_Data_B ),
	.wren_a ( S_Embedded_RAM_we_A ),
	.wren_b ( S_Embedded_RAM_we_B ),
	.q_a ( S_Embedded_RAM_Read_Data_A ),
	.q_b ( S_Embedded_RAM_Read_Data_B )
	);

// instantiate 2 Embedded RAMs for storing T (Double port)
logic [6:0] T_Embedded_RAM1_Address_A, T_Embedded_RAM1_Address_B;
logic [31:0] T_Embedded_RAM1_Write_Data_A, T_Embedded_RAM1_Write_Data_B,
				 T_Embedded_RAM1_Read_Data_A, T_Embedded_RAM1_Read_Data_B;
logic T_Embedded_RAM1_we_A, T_Embedded_RAM1_we_B;

// To arbitrate the access through Compute T and Compute S'
logic [6:0] T_Embedded_RAM1_Address_A_CT, T_Embedded_RAM1_Address_A_Sd,
				T_Embedded_RAM1_Address_B_CT, T_Embedded_RAM1_Address_B_Sd;
				
DP_EmbeddedRAM T_Embedded_RAM1 (
	.address_a ( T_Embedded_RAM1_Address_A ),
	.address_b ( T_Embedded_RAM1_Address_B ),
	.clock ( Clock ),
	.data_a ( T_Embedded_RAM1_Write_Data_A ),
	.data_b ( T_Embedded_RAM1_Write_Data_B ),
	.wren_a ( T_Embedded_RAM1_we_A ),
	.wren_b ( T_Embedded_RAM1_we_B ),
	.q_a ( T_Embedded_RAM1_Read_Data_A ),
	.q_b ( T_Embedded_RAM1_Read_Data_B )
	);
	
logic [6:0] T_Embedded_RAM2_Address_A, T_Embedded_RAM2_Address_B;
logic [31:0] T_Embedded_RAM2_Write_Data_A, T_Embedded_RAM2_Write_Data_B,
				 T_Embedded_RAM2_Read_Data_A, T_Embedded_RAM2_Read_Data_B;
logic T_Embedded_RAM2_we_A, T_Embedded_RAM2_we_B;

// To arbitrate the access through Compute T and Compute S'
logic [6:0] T_Embedded_RAM2_Address_A_CT, T_Embedded_RAM2_Address_A_Sd,
				T_Embedded_RAM2_Address_B_CT, T_Embedded_RAM2_Address_B_Sd;

DP_EmbeddedRAM T_Embedded_RAM2 (
	.address_a ( T_Embedded_RAM2_Address_A ),
	.address_b ( T_Embedded_RAM2_Address_B ),
	.clock ( Clock ),
	.data_a ( T_Embedded_RAM2_Write_Data_A ),
	.data_b ( T_Embedded_RAM2_Write_Data_B ),
	.wren_a ( T_Embedded_RAM2_we_A ),
	.wren_b ( T_Embedded_RAM2_we_B ),
	.q_a ( T_Embedded_RAM2_Read_Data_A ),
	.q_b ( T_Embedded_RAM2_Read_Data_B )
	);

// instantiate 2 Embedded RAM for storing S' (Double port)
logic [6:0] Sd_Embedded_RAM1_Address_A, Sd_Embedded_RAM1_Address_B;
logic [31:0] Sd_Embedded_RAM1_Write_Data_A, Sd_Embedded_RAM1_Write_Data_B,
				 Sd_Embedded_RAM1_Read_Data_A, Sd_Embedded_RAM1_Read_Data_B;
logic Sd_Embedded_RAM1_we_A, Sd_Embedded_RAM1_we_B;

// To arbitrate the access through Compute S' and Compute Quantize Lossless Encode
logic [6:0] Sd_Embedded_RAM1_Address_A_Sd, Sd_Embedded_RAM_Address_A_QLE,
				Sd_Embedded_RAM1_Address_B_Sd;

DP_EmbeddedRAM Sd_Embedded_RAM1 (
	.address_a ( Sd_Embedded_RAM1_Address_A ),
	.address_b ( Sd_Embedded_RAM1_Address_B ),
	.clock ( Clock ),
	.data_a ( Sd_Embedded_RAM1_Write_Data_A ),
	.data_b ( Sd_Embedded_RAM1_Write_Data_B ),
	.wren_a ( Sd_Embedded_RAM1_we_A ),
	.wren_b ( Sd_Embedded_RAM1_we_B ),
	.q_a ( Sd_Embedded_RAM1_Read_Data_A ),
	.q_b ( Sd_Embedded_RAM1_Read_Data_B )
	);
	
logic [6:0] Sd_Embedded_RAM2_Address_A, Sd_Embedded_RAM2_Address_B;
logic [31:0] Sd_Embedded_RAM2_Write_Data_A, Sd_Embedded_RAM2_Write_Data_B,
				 Sd_Embedded_RAM2_Read_Data_A, Sd_Embedded_RAM2_Read_Data_B;
logic Sd_Embedded_RAM2_we_A, Sd_Embedded_RAM2_we_B;

// To arbitrate the access through Compute S' and Compute Quantize Lossless Encode
logic [6:0] Sd_Embedded_RAM2_Address_A_Sd,
				Sd_Embedded_RAM2_Address_B_Sd;
				
DP_EmbeddedRAM Sd_Embedded_RAM2 (
	.address_a ( Sd_Embedded_RAM2_Address_A ),
	.address_b ( Sd_Embedded_RAM2_Address_B ),
	.clock ( Clock ),
	.data_a ( Sd_Embedded_RAM2_Write_Data_A ),
	.data_b ( Sd_Embedded_RAM2_Write_Data_B ),
	.wren_a ( Sd_Embedded_RAM2_we_A ),
	.wren_b ( Sd_Embedded_RAM2_we_B ),
	.q_a ( Sd_Embedded_RAM2_Read_Data_A ),
	.q_b ( Sd_Embedded_RAM2_Read_Data_B )
	);

	
DCT_Timer_state_type DCT_Timer_state;

logic [7:0] timer;
logic [63:0] MULTs_Buffer;
logic [1:0] last_block_in_channel_buffer;
logic Write_in_Sd_RAM1, last_block_in_channel;
always_ff @ (posedge Clock or negedge Resetn) begin

	if (Resetn == 1'b0) begin
	
		timer <= 8'd0;
		DCT_Timer_state <= S_DCT_Timer_IDLE;
		
		// Timer dependent registers
		MULTs_Buffer <= 64'h0;
		last_block_in_channel_buffer <= 2'd0;
		Write_in_Sd_RAM1 <= 1'b0;
	end
	else begin
		case (DCT_Timer_state)
			S_DCT_Timer_IDLE: begin
				timer <= 8'd0;
				
				// Timer dependent registers
				Write_in_Sd_RAM1 <= 1'b0;
				MULTs_Buffer <= 64'h0;
				last_block_in_channel_buffer <= 2'd0;
				
				// If DCT is enabled, start timer
				if (enable) begin 
					DCT_Timer_state <= S_DCT_Timer_ON;
				end
			end
			S_DCT_Timer_ON: begin
				// Always working
				MULTs_Buffer <= {(MUL1[31:0] + MUL2[31:0]), (MUL3[31:0] + MUL4[31:0])};
				if (timer == 8'd131) begin
					timer <= 8'd0;
					
					// Timer dependent registers
					Write_in_Sd_RAM1 <= ~Write_in_Sd_RAM1;
					last_block_in_channel_buffer[0] <= last_block_in_channel;
					last_block_in_channel_buffer[1] <= last_block_in_channel_buffer[0];
				end
				else begin
					timer <= timer + 8'd1;
				end
			end
		endcase
	end
end

// Fetch S - FSM

logic [19:0] SRAM_Relative_address, SRAM_address_FS;
logic [15:0] Buffer_SRAM;
logic [1:0] SRAM_Fetch_Segment;

logic [2:0] block_relative_row_counter;
logic [1:0] block_relative_col_counter;
logic [$clog2(no_cols/8)-1:0] block_col_start_counter, Segment_Stop_Col;
logic [$clog2(no_cols/2)-1:0] Cols_per_Segment;
logic [19:0] block_row_start_address, Segment_Stop_Row;

DCT_FS_state_type DCT_FS_state;

always_ff @ (posedge Clock or negedge Resetn) begin

	if (Resetn == 1'b0) begin
		// Reset Signals
		block_relative_col_counter <= 2'h0;
		block_relative_row_counter <= 3'h0;
		block_col_start_counter <= 0;
		block_row_start_address <= 20'h0;
		S_Embedded_RAM_we_A <= 1'b0;
		S_Embedded_RAM_we_B <= 1'b0;
		S_Embedded_RAM_Address_A_FS <= 7'h0;
		S_Embedded_RAM_Address_B_FS <= 7'h0;
		Buffer_SRAM <= 16'h0;
		SRAM_Fetch_Segment <= 2'b00;
		last_block_in_channel <= 1'b0;
		DCT_FS_state <= S_DCT_FS_IDLE;
	end 
	else begin
		case (DCT_FS_state)
			S_DCT_FS_IDLE: begin
			// Reset Signals
			block_relative_col_counter <= 2'h0;
			block_relative_row_counter <= 3'h0;
			block_col_start_counter <= 0;
			block_row_start_address <= 20'h0;
			S_Embedded_RAM_we_A <= 1'b0;
			S_Embedded_RAM_we_B <= 1'b0;
			S_Embedded_RAM_Address_A_FS <= 7'h0;
			S_Embedded_RAM_Address_B_FS <= 7'h0;
			Buffer_SRAM <= 16'h0;
			SRAM_Fetch_Segment <= 2'b00;
			// If DCT is enabled, start processing the image
			if (enable) begin 
				DCT_FS_state <= S_DCT_FS_0;
			end
				
			end
			S_DCT_FS_0: begin // Fetch new block
				block_relative_col_counter <= block_relative_col_counter + 2'd1;
				DCT_FS_state <= S_DCT_FS_1;
			end
			S_DCT_FS_1: begin
				block_relative_col_counter <= block_relative_col_counter + 2'd1;
				DCT_FS_state <= S_DCT_FS_COM_0;
			end
			S_DCT_FS_COM_0: begin
				
				DCT_FS_state <= S_DCT_FS_COM_1;

				block_relative_col_counter <= block_relative_col_counter + 2'd1;
				
				S_Embedded_RAM_we_A <= 1'b1;
				Buffer_SRAM <= SRAM_read_data;
			end
			S_DCT_FS_COM_1: begin
			
				DCT_FS_state <= S_DCT_FS_COM_0;

				if (block_relative_col_counter == 2'b11) begin // If end of row
					
					// Reset relative column counter
					block_relative_col_counter <= 2'h0;

					if (block_relative_row_counter == 3'd7) begin // Block finished
						
						// Reset relative row counter
						block_relative_row_counter <= 3'h0;		
						
						DCT_FS_state <= S_DCT_FS_2; // Wait to fetch next block

						if (block_col_start_counter == Segment_Stop_Col) begin // If last block in row
							// Reset block start column counter
							block_col_start_counter <= 0;
							
							if (block_row_start_address == Segment_Stop_Row) begin // If last row
								if (SRAM_Fetch_Segment == 2'b10) begin // If last segment (V)
									DCT_FS_state <= S_DCT_FS_IDLE; // No more fetch
								end
								else begin
									SRAM_Fetch_Segment <= SRAM_Fetch_Segment + 1; // Move to next segment (Y->U->V)
								end
								block_row_start_address <= 0;
								last_block_in_channel <= 1'b1;
							end
							else begin
							// Increase block start row address
							block_row_start_address <= block_row_start_address + (Cols_per_Segment << 3);
							end
						end
						else begin
							block_col_start_counter <= block_col_start_counter + 1;
						end
					end
					else begin
						// Increment block relative row counter
						block_relative_row_counter <= block_relative_row_counter + 3'h1;
					end
					
				end
				else begin
					block_relative_col_counter <= block_relative_col_counter + 2'd1;
				end
				
				S_Embedded_RAM_Address_A_FS <= S_Embedded_RAM_Address_A_FS + 7'd1;
				S_Embedded_RAM_we_A <= 1'b0;
								
			end
			S_DCT_FS_2: begin
				Buffer_SRAM <= SRAM_read_data;
				S_Embedded_RAM_we_A <= 1'b1;
				DCT_FS_state <= S_DCT_FS_3;
			end
			S_DCT_FS_3: begin
				S_Embedded_RAM_we_A <= 1'b0;
				S_Embedded_RAM_Address_A_FS <= 7'd0;
				DCT_FS_state <= S_DCT_FS_HOLD;
			end
			S_DCT_FS_HOLD: begin
				if (timer == 8'd131) begin
					last_block_in_channel <= 1'b0;
					DCT_FS_state <= S_DCT_FS_0;
				end
			end
		endcase
	end
end


always_comb begin
	
	S_Embedded_RAM_Write_Data_A = {Buffer_SRAM, SRAM_read_data};
	
	Segment_Stop_Col = 0;
	Cols_per_Segment = 0;
	Segment_Stop_Row = 0;
	
	case (SRAM_Fetch_Segment)
		2'b10, 2'b01: begin 
			Segment_Stop_Col = (no_cols/16) - 1;
			Cols_per_Segment = no_cols/4;
			Segment_Stop_Row = (no_rows - 8) * (no_cols/4);
		end
		default: begin
			Segment_Stop_Col = (no_cols/8) - 1;
			Cols_per_Segment = no_cols/2;
			Segment_Stop_Row = (no_rows - 8) * (no_cols/2);
		end
	endcase
	
end	

always_comb begin
	
	SRAM_Relative_address = {block_col_start_counter, block_relative_col_counter} + block_row_start_address;

	if (block_relative_row_counter[0] == 1'b1) begin
	SRAM_Relative_address = SRAM_Relative_address + Cols_per_Segment;
	end
	
	if (block_relative_row_counter[1] == 1'b1) begin
	SRAM_Relative_address = SRAM_Relative_address + (Cols_per_Segment << 1);
	end
	
	if (block_relative_row_counter[2] == 1'b1) begin
	SRAM_Relative_address = SRAM_Relative_address + (Cols_per_Segment << 2);
	end
	
	case (SRAM_Fetch_Segment)
		2'b01: begin 
			SRAM_address_FS = SRAM_Relative_address + Ud_base_address;
		end
		2'b10: begin
			SRAM_address_FS = SRAM_Relative_address + Vd_base_address;
		end
		default: begin
			SRAM_address_FS = SRAM_Relative_address + Y_base_address;
		end
	endcase
	
end	

// Compute T - FSM:

logic [2:0] T_i_counter, T_j_counter;
logic [15:0] T_Buffer;
logic [22:0] New_T; // 8 Partial products of size 20 bits
logic Write_in_T_RAM1;
DCT_CT_state_type DCT_CT_state;

always_ff @ (posedge Clock or negedge Resetn) begin

	if (Resetn == 1'b0) begin
		// Reset Signals
		S_Embedded_RAM_Address_A_CT <= 7'h0;
		S_Embedded_RAM_Address_B_CT <= 7'h1;
		T_Embedded_RAM1_we_A <= 1'b0;
		T_Embedded_RAM1_we_B <= 1'b0;
		T_Embedded_RAM2_we_A <= 1'b0;
		T_Embedded_RAM2_we_B <= 1'b0;
		T_Embedded_RAM1_Address_A_CT <= 7'h0;
		T_Embedded_RAM1_Address_B_CT <= 7'h0;
		T_Embedded_RAM2_Address_A_CT <= 7'h0;
		T_Embedded_RAM2_Address_B_CT <= 7'h0;
		T_i_counter <= 3'h0;
		T_j_counter <= 3'h0;
		T_Buffer <= 16'h0;
		Write_in_T_RAM1 <= 1'b1;
		DCT_CT_state <= S_DCT_CT_HOLD;
	end 
	else begin
		case (DCT_CT_state)
			S_DCT_CT_IDLE: begin
				// Reset Signals
				S_Embedded_RAM_Address_A_CT <= 7'h0;
				S_Embedded_RAM_Address_B_CT <= 7'h1;
				T_Embedded_RAM1_we_A <= 1'b0;
				T_Embedded_RAM1_we_B <= 1'b0;
				T_Embedded_RAM2_we_A <= 1'b0;
				T_Embedded_RAM2_we_B <= 1'b0;
				T_Embedded_RAM1_Address_A_CT <= 7'h0;
				T_Embedded_RAM1_Address_B_CT <= 7'h0;
				T_Embedded_RAM2_Address_A_CT <= 7'h0;
				T_Embedded_RAM2_Address_B_CT <= 7'h0;
				T_i_counter <= 3'h0;
				T_j_counter <= 3'h0;
				T_Buffer <= 16'h0;
				Write_in_T_RAM1 <= 1'b0;
			end
			S_DCT_CT_0: begin
				// Fetch next row from S
				S_Embedded_RAM_Address_A_CT <= S_Embedded_RAM_Address_A_CT + 7'h2;
				S_Embedded_RAM_Address_B_CT <= S_Embedded_RAM_Address_B_CT + 7'h2;
				DCT_CT_state <= S_DCT_CT_1;
			end
			S_DCT_CT_1: begin
				// Fetch next row from S
				S_Embedded_RAM_Address_A_CT <= S_Embedded_RAM_Address_A_CT + 7'h2;
				S_Embedded_RAM_Address_B_CT <= S_Embedded_RAM_Address_B_CT + 7'h2;
				T_i_counter <= T_i_counter + 3'd1;
				DCT_CT_state <= S_DCT_CT_COM_0;
			end
			S_DCT_CT_COM_0:begin
				// Data arrives in the background, multiplied, and stored in MULTs_Buffer
				// Data already in MULTs_Buffer is used to finalize compute New_T
		
				DCT_CT_state <= S_DCT_CT_COM_1;
				
				T_Buffer <= New_T;
				
				if (Write_in_T_RAM1 == 1'b1) begin
					T_Embedded_RAM1_we_A <= 1'b1;
				end
				else begin
					T_Embedded_RAM2_we_A <= 1'b1;
				end
				
				// Fetch next row from S
				S_Embedded_RAM_Address_A_CT <= S_Embedded_RAM_Address_A_CT + 7'h2;
				S_Embedded_RAM_Address_B_CT <= S_Embedded_RAM_Address_B_CT + 7'h2;
				if (T_i_counter == 3'd7) begin
					T_i_counter <= 3'd0;
					if (T_j_counter == 3'd7) begin  // If last column
						// Wait until new S is fetched
						T_j_counter <= 3'd0;
						DCT_CT_state <= S_DCT_CT_2;
					end
					else begin
						T_j_counter <= T_j_counter + 3'd1;
					end
				end
				else begin
					T_i_counter <= T_i_counter + 3'd1;
				end
				
			end
			S_DCT_CT_COM_1:begin
				// Data arrives in the background, multiplied, and stored in MULTs_Buffer
				// Data already in MULTs_Buffer is used to finalize compute New_T
				
				Write_in_T_RAM1 <= ~Write_in_T_RAM1;
				T_Embedded_RAM1_we_A <= 1'b0;
				T_Embedded_RAM2_we_A <= 1'b0;
				if (Write_in_T_RAM1 == 1'b1) begin
					T_Embedded_RAM1_Address_A_CT <= T_Embedded_RAM1_Address_A_CT + 7'h1;
				end
				else begin
					T_Embedded_RAM2_Address_A_CT <= T_Embedded_RAM2_Address_A_CT + 7'h1;
				end
				
				DCT_CT_state <= S_DCT_CT_COM_0;
				
				T_i_counter <= T_i_counter + 3'd1;
				if (T_i_counter == 3'd6) begin
					// Reset pointers in S_Embedded_RAM
					S_Embedded_RAM_Address_A_CT <= 7'h0;
					S_Embedded_RAM_Address_B_CT <= 7'h1;
				end
				else begin
					S_Embedded_RAM_Address_A_CT <= S_Embedded_RAM_Address_A_CT + 7'h2;
					S_Embedded_RAM_Address_B_CT <= S_Embedded_RAM_Address_B_CT + 7'h2;
				end
				
			end
			S_DCT_CT_2: begin
				DCT_CT_state <= S_DCT_CT_HOLD;
				T_Embedded_RAM1_we_A <= 1'b0;
				T_Embedded_RAM2_we_A <= 1'b0;
				if (DCT_FS_state == S_DCT_FS_IDLE) begin // If no more S will be fetched
					DCT_CT_state <= S_DCT_CT_IDLE;
				end
			end
			S_DCT_CT_HOLD: begin
				if (timer == 8'd65) begin
					T_Embedded_RAM1_Address_A_CT <= 7'h0;
					T_Embedded_RAM2_Address_A_CT <= 7'h0;
					T_Embedded_RAM1_Address_B_CT <= 7'h1;
					T_Embedded_RAM2_Address_B_CT <= 7'h1;
					S_Embedded_RAM_Address_A_CT <= 7'h0;
					S_Embedded_RAM_Address_B_CT <= 7'h1;
					Write_in_T_RAM1 <= 1'b1;
					DCT_CT_state <= S_DCT_CT_0;
				end
			end
		endcase
	end
end



// Compute S' - FSM:

logic [22:0] New_Sd; // 8 Partial products of size 20 bits
logic [2:0] Sd_i_counter, Sd_j_counter;

logic Start_QLE;

DCT_Sd_state_type DCT_Sd_state;

always_ff @ (posedge Clock or negedge Resetn) begin

	if (Resetn == 1'b0) begin
		// Reset Signals
		T_Embedded_RAM1_Address_A_Sd <= 7'h0;
		T_Embedded_RAM1_Address_B_Sd <= 7'h1;
		T_Embedded_RAM2_Address_A_Sd <= 7'h0;
		T_Embedded_RAM2_Address_B_Sd <= 7'h1;
		Sd_Embedded_RAM1_we_A <= 1'b0;
		Sd_Embedded_RAM1_we_B <= 1'b0;
		Sd_Embedded_RAM2_we_A <= 1'b0;
		Sd_Embedded_RAM2_we_B <= 1'b0;
		Sd_Embedded_RAM1_Address_A_Sd <= 7'h0;
		Sd_Embedded_RAM1_Address_B_Sd <= 7'h0;
		Sd_Embedded_RAM2_Address_A_Sd <= 7'h0;
		Sd_Embedded_RAM2_Address_B_Sd <= 7'h0;
		Start_QLE <= 1'b0;
		Sd_i_counter <= 3'h0;
		Sd_j_counter <= 3'h0;
		DCT_Sd_state <= S_DCT_Sd_HOLD;
	end 
	else begin
		case (DCT_Sd_state)
			S_DCT_Sd_IDLE: begin
				// Reset Signals
				T_Embedded_RAM1_Address_A_Sd <= 7'h0;
				T_Embedded_RAM1_Address_B_Sd <= 7'h1;
				T_Embedded_RAM2_Address_A_Sd <= 7'h0;
				T_Embedded_RAM2_Address_B_Sd <= 7'h1;
				Sd_Embedded_RAM1_we_A <= 1'b0;
				Sd_Embedded_RAM1_we_B <= 1'b0;
				Sd_Embedded_RAM2_we_A <= 1'b0;
				Sd_Embedded_RAM2_we_B <= 1'b0;
				Sd_Embedded_RAM1_Address_A_Sd <= 7'h0;
				Sd_Embedded_RAM1_Address_B_Sd <= 7'h0;
				Sd_Embedded_RAM2_Address_A_Sd <= 7'h0;
				Sd_Embedded_RAM2_Address_B_Sd <= 7'h0;
				Sd_i_counter <= 3'h0;
				Sd_j_counter <= 3'h0;
				Start_QLE <= 1'b0;
			end
			S_DCT_Sd_0: begin
				// Fetch next 8 elements from T
				T_Embedded_RAM1_Address_A_Sd <= T_Embedded_RAM1_Address_A_Sd + 7'h2;
				T_Embedded_RAM1_Address_B_Sd <= T_Embedded_RAM1_Address_B_Sd + 7'h2;
				T_Embedded_RAM2_Address_A_Sd <= T_Embedded_RAM2_Address_A_Sd + 7'h2;
				T_Embedded_RAM2_Address_B_Sd <= T_Embedded_RAM2_Address_B_Sd + 7'h2;
				DCT_Sd_state <= S_DCT_Sd_1;
			end
			S_DCT_Sd_1: begin
				// Fetch next 8 elements from T
				T_Embedded_RAM1_Address_A_Sd <= T_Embedded_RAM1_Address_A_Sd + 7'h2;
				T_Embedded_RAM1_Address_B_Sd <= T_Embedded_RAM1_Address_B_Sd + 7'h2;
				T_Embedded_RAM2_Address_A_Sd <= T_Embedded_RAM2_Address_A_Sd + 7'h2;
				T_Embedded_RAM2_Address_B_Sd <= T_Embedded_RAM2_Address_B_Sd + 7'h2;
				Sd_j_counter <= Sd_j_counter + 3'd1;
				if (Write_in_Sd_RAM1 == 1'b1) begin
					Sd_Embedded_RAM1_we_A <= 1'b1;
				end
				else begin
					Sd_Embedded_RAM2_we_A <= 1'b1;
				end
				DCT_Sd_state <= S_DCT_Sd_COM_0;
			end
			S_DCT_Sd_COM_0:begin
				
				if (Sd_j_counter == 3'd6) begin
					// Reset pointers in T Embedded RAMs
					T_Embedded_RAM1_Address_A_Sd <= 7'h0;
					T_Embedded_RAM1_Address_B_Sd <= 7'h1;
					T_Embedded_RAM2_Address_A_Sd <= 7'h0;
					T_Embedded_RAM2_Address_B_Sd <= 7'h1;
				end
				else begin
					// Fetch next 8 elements from T
					T_Embedded_RAM1_Address_A_Sd <= T_Embedded_RAM1_Address_A_Sd + 7'h2;
					T_Embedded_RAM1_Address_B_Sd <= T_Embedded_RAM1_Address_B_Sd + 7'h2;
					T_Embedded_RAM2_Address_A_Sd <= T_Embedded_RAM2_Address_A_Sd + 7'h2;
					T_Embedded_RAM2_Address_B_Sd <= T_Embedded_RAM2_Address_B_Sd + 7'h2;
				end
				
				if (Write_in_Sd_RAM1 == 1'b1) begin
					Sd_Embedded_RAM1_Address_A_Sd <= Sd_Embedded_RAM1_Address_A_Sd + 7'h1;
				end
				else begin
					Sd_Embedded_RAM2_Address_A_Sd <= Sd_Embedded_RAM2_Address_A_Sd + 7'h1;
				end
				
				if (Sd_j_counter == 3'd7) begin
					Sd_j_counter <= 3'd0;
					if (Sd_i_counter == 3'd7) begin  // If last row
						if (DCT_CT_state == S_DCT_CT_IDLE) begin // If no more T will be computed
							DCT_Sd_state <= S_DCT_Sd_IDLE;
						end
						else begin // Wait until new S is fetched
							Sd_i_counter <= 3'd0;
							DCT_Sd_state <= S_DCT_Sd_2;
						end
					end
					else begin
						Sd_i_counter <= Sd_i_counter + 3'd1;
					end
				end
				else begin
					Sd_j_counter <= Sd_j_counter + 3'd1;
				end
				
			end

			S_DCT_Sd_2: begin
				DCT_Sd_state <= S_DCT_Sd_HOLD;
				Start_QLE <= 1'b1;
				Sd_Embedded_RAM1_we_A <= 1'b0;
				Sd_Embedded_RAM2_we_A <= 1'b0;
			end
			S_DCT_Sd_HOLD: begin
				if (timer == 8'd131) begin
					Sd_Embedded_RAM1_Address_A_Sd <= 7'h0;
					Sd_Embedded_RAM2_Address_A_Sd <= 7'h0;
					T_Embedded_RAM1_Address_A_Sd <= 7'h0;
					T_Embedded_RAM1_Address_B_Sd <= 7'h1;
					T_Embedded_RAM2_Address_A_Sd <= 7'h0;
					T_Embedded_RAM2_Address_B_Sd <= 7'h1;
					DCT_Sd_state <= S_DCT_Sd_0;
				end
			end
		endcase
	end
end


logic [31:0] New_Element_Unrounded;
logic signed [31:0] Element_0, Element_1, Element_2, Element_3,
Element_4, Element_5, Element_6, Element_7;
logic [2:0] C_index;

always_comb begin
	
	if (DCT_CT_state == S_DCT_CT_HOLD || DCT_CT_state == S_DCT_CT_IDLE) begin // If compute S'
		Element_0 = $signed(T_Embedded_RAM1_Read_Data_A[31:16]);
		Element_1 = $signed(T_Embedded_RAM1_Read_Data_A[15:0]);
		Element_2 = $signed(T_Embedded_RAM2_Read_Data_A[31:16]);
		Element_3 = $signed(T_Embedded_RAM2_Read_Data_A[15:0]);
		Element_4 = $signed(T_Embedded_RAM1_Read_Data_B[31:16]);
		Element_5 = $signed(T_Embedded_RAM1_Read_Data_B[15:0]);
		Element_6 = $signed(T_Embedded_RAM2_Read_Data_B[31:16]);
		Element_7 = $signed(T_Embedded_RAM2_Read_Data_B[15:0]);
		C_index = Sd_i_counter;
	end
	else begin   // If compute T
		Element_0 = {24'h0, S_Embedded_RAM_Read_Data_A[31:24]};
		Element_1 = {24'h0, S_Embedded_RAM_Read_Data_A[23:16]};
		Element_2 = {24'h0, S_Embedded_RAM_Read_Data_A[15:8]};
		Element_3 = {24'h0, S_Embedded_RAM_Read_Data_A[7:0]};
		Element_4 = {24'h0, S_Embedded_RAM_Read_Data_B[31:24]};
		Element_5 = {24'h0, S_Embedded_RAM_Read_Data_B[23:16]};
		Element_6 = {24'h0, S_Embedded_RAM_Read_Data_B[15:8]};
		Element_7 = {24'h0, S_Embedded_RAM_Read_Data_B[7:0]};
		C_index = T_j_counter;
	end
	
	if (C_index[0] == 1'b0) begin 
		MUL1_OP_B = Element_0 + Element_7;  // S(i,0) + S(i,7)
		MUL2_OP_B = Element_1 + Element_6;  // S(i,1) + S(i,6)
		MUL3_OP_B = Element_2 + Element_5;  // S(i,2) + S(i,5)
		MUL4_OP_B = Element_3 + Element_4;  // S(i,3) + S(i,4)
	end
	else begin // Odd j's
		MUL1_OP_B = Element_0 - Element_7;  // S(i,0) - S(i,7)
		MUL2_OP_B = Element_1 - Element_6;  // S(i,1) - S(i,6)
		MUL3_OP_B = Element_2 - Element_5;  // S(i,2) - S(i,5)
		MUL4_OP_B = Element_3 - Element_4;  // S(i,3) - S(i,4)
	end
		
	case(C_index)
		3'd0: begin
			MUL1_OP_A = 32'd1448;
			MUL2_OP_A = 32'd1448;
			MUL3_OP_A = 32'd1448;
			MUL4_OP_A = 32'd1448;
		end
		3'd1: begin
			MUL1_OP_A = 32'd2008;
			MUL2_OP_A = 32'd1702;
			MUL3_OP_A = 32'd1137;
			MUL4_OP_A = 32'd399;
		end
		3'd2: begin
			MUL1_OP_A = 32'd1892;
			MUL2_OP_A = 32'd783;
			MUL3_OP_A = -32'd783;
			MUL4_OP_A = -32'd1892;
		end
		3'd3: begin
			MUL1_OP_A = 32'd1702;
			MUL2_OP_A = -32'd399;
			MUL3_OP_A = -32'd2008;
			MUL4_OP_A = -32'd1137;
		end
		3'd4: begin
			MUL1_OP_A = 32'd1448;
			MUL2_OP_A = -32'd1448;
			MUL3_OP_A = -32'd1448;
			MUL4_OP_A = 32'd1448;
		end
		3'd5: begin
			MUL1_OP_A = 32'd1137;
			MUL2_OP_A = -32'd2008;
			MUL3_OP_A = 32'd399;
			MUL4_OP_A = 32'd1702;
		end
		3'd6: begin
			MUL1_OP_A = 32'd783;
			MUL2_OP_A = -32'd1892;
			MUL3_OP_A = 32'd1892;
			MUL4_OP_A = -32'd783;
		end
		3'd7: begin
			MUL1_OP_A = 32'd399;
			MUL2_OP_A = -32'd1137;
			MUL3_OP_A = 32'd1702;
			MUL4_OP_A = -32'd2008;
		end
	endcase
	
	New_Element_Unrounded = MULTs_Buffer[63:32] + MULTs_Buffer[31:0];

	New_T = (New_Element_Unrounded + 32'd128) >>> 8;
	T_Embedded_RAM1_Write_Data_A = {T_Buffer, New_T[15:0]};
	T_Embedded_RAM2_Write_Data_A = {T_Buffer, New_T[15:0]};
	
	New_Sd = (New_Element_Unrounded + 32'd32768) >>> 16;
	Sd_Embedded_RAM1_Write_Data_A = {New_Sd[15:0], 16'd0};
	Sd_Embedded_RAM2_Write_Data_A = {New_Sd[15:0], 16'd0};
	
end


// Quantization and Lossless encoding
logic [19:0] SRAM_address_QLE, SRAM_address_QLE_Buffer;
logic [2:0] QLE_j_counter, QLE_i_counter;
logic polarity;
logic [3:0] diag_index;
logic [2:0] zeros_counter, group_zeros_counter;
logic [25:0] Encoded_Buffer, Encoded_Ready_to_Write;
logic [4:0] pointer;
logic [8:0] Quantized_clipped, buffer_Quantized_clipped;
logic [18:0] Two_Byte_Counter;
logic release_zeros, done_releasing_zeros, Hold_COM_0;
logic UV_Offset_index;
logic [2:0] Header_Offset_index;
logic [15:0] SRAM_write_data_UV_Offset, SRAM_write_data_HEADER;
DCT_QLE_state_type DCT_QLE_state;

always_ff @ (posedge Clock or negedge Resetn) begin

	if (Resetn == 1'b0) begin
		// Reset Signals
		finished <= 1'b0;
		SRAM_we_n <= 1'b1;
		SRAM_write_data <= 16'd0;
		QLE_j_counter <= 3'h0;
		QLE_i_counter <= 3'h0;
		polarity <= 1'b1;
		diag_index <= 4'd0;
		zeros_counter <= 3'd0;
		group_zeros_counter <= 3'd0;
		pointer <= 5'd0;
		Encoded_Buffer <= 26'd0;
		buffer_Quantized_clipped <= 9'd0;
		done_releasing_zeros <= 1'b0;
		Hold_COM_0 <= 1'b0;
		Two_Byte_Counter <= 19'd10;
		UV_Offset_index <= 1'd0;
		Header_Offset_index <= 3'd0;
		SRAM_address_QLE <= 20'h9;
		SRAM_address_QLE_Buffer <= 20'd0;
		DCT_QLE_state <= S_DCT_QLE_IDLE;
	end 
	else begin
	
		case (DCT_QLE_state)
			S_DCT_QLE_IDLE: begin
				// Reset Signals
				SRAM_we_n <= 1'b1;
				SRAM_write_data <= 16'd0;
				QLE_j_counter <= 3'h0;
				QLE_i_counter <= 3'h0;
				polarity <= 1'b1;
				diag_index <= 4'd0;
				Encoded_Buffer <= 26'd0;
				pointer <= 5'd0;
				zeros_counter <= 3'd0;
				group_zeros_counter <= 3'd0;
				buffer_Quantized_clipped <= 9'd0;
				done_releasing_zeros <= 1'b0;
				Two_Byte_Counter <= 19'd10;
				Hold_COM_0 <= 1'b0;
				UV_Offset_index <= 1'd0;
				Header_Offset_index <= 3'd0;
				SRAM_address_QLE <= 20'h9;
				SRAM_address_QLE_Buffer <= 20'd0;
				if (Start_QLE == 1'b1) begin
					DCT_QLE_state <= S_DCT_QLE_HOLD;
				end
			end
			S_DCT_QLE_0: begin
				QLE_j_counter <= 3'h1;
				QLE_i_counter <= 3'h0;
				DCT_QLE_state <= S_DCT_QLE_COM_0;
			end
			
			S_DCT_QLE_COM_0: begin
				// For Lossless Coding:--------------
				done_releasing_zeros <= 1'b0;
				DCT_QLE_state <= S_DCT_QLE_COM_0;
				if (Sd_Embedded_RAM_Address_A_QLE == 6'd63 && release_zeros != 1'b1) begin
					if (Hold_COM_0 == 1'b1) begin
						DCT_QLE_state <= S_DCT_QLE_1;
					end
					else begin
						// Wait for 1 more clock to process the last fetched data
						Hold_COM_0 <= 1'b1;
					end
				end
				
				// If encountered a zero
				if (Quantized_clipped == 9'd0) begin
					// If last element is zero push EOB directly and zero-out the 0 coutners
					if ((Sd_Embedded_RAM_Address_A_QLE == 6'd63) && (Hold_COM_0 == 1'b1)) begin   	
						zeros_counter <= 3'd0;
						group_zeros_counter <= 3'd0;
						for (int i=0; i<24; i++) begin
							Encoded_Buffer[i+2] <= Encoded_Buffer[i];
						end
						Encoded_Buffer[1:0] <= {2'b11};
						if (pointer[4] == 1'b1) begin  // 16 or more
							pointer <= pointer - 5'd14;
						end
						else begin
							pointer <= pointer + 5'd2;
						end
					end
					else begin   // If intermediate zero
						if (zeros_counter == 3'd7) begin
							group_zeros_counter <= group_zeros_counter + 3'd1;
							zeros_counter <= 3'd0;
						end
						else begin
							zeros_counter <= zeros_counter + 3'd1;
						end
						if (pointer[4] == 1'b1) begin  // 16 or more
							pointer <= pointer - 5'd16;
						end
					end
				end
				else begin
					if (release_zeros) begin
						// Store the last quantized value to use after releasing
						buffer_Quantized_clipped <= Quantized_clipped; 
						DCT_QLE_state <= S_DCT_QLE_RELEASE_ZEROS;
					end
					else begin
						if ((|Quantized_clipped[8:2]== 9'd0) || (&Quantized_clipped[8:2]== 9'd1)) begin   // Number representable by 3 bits
							for (int i=0; i<21; i++) begin
								Encoded_Buffer[i+5] <= Encoded_Buffer[i];
							end
							Encoded_Buffer[4:0] <= {2'b10, Quantized_clipped[2:0]};
							if (pointer[4] == 1'b1) begin  // 16 or more
								pointer <= pointer - 5'd11;
							end
							else begin
								pointer <= pointer + 5'd5;
							end
						end
						else begin  // Number representable by 9 bits
							for (int i=0; i<15; i++) begin
								Encoded_Buffer[i+11] <= Encoded_Buffer[i];
							end
							Encoded_Buffer[10:0] <= {2'b01, Quantized_clipped[8:0]};
							if (pointer[4] == 1'b1) begin  // 16 or more
								pointer <= pointer - 5'd5;
							end
							else begin
								pointer <= pointer + 5'd11;
							end
						end
					end
				end
				
				SRAM_we_n <= 1'b1;
				if (pointer[4] == 1'b1) begin  // 16 or more
					SRAM_write_data <= Encoded_Ready_to_Write[15:0];
					SRAM_address_QLE <= SRAM_address_QLE + 20'd1;
					Two_Byte_Counter <= Two_Byte_Counter + 1'd1;
					SRAM_we_n <= 1'b0;
				end
				
				// For Scanning and Quantization:-----------
				if (release_zeros != 1'b1 && Sd_Embedded_RAM_Address_A_QLE != 6'd63) begin  // Move to next element only if not releasing zeros into buffer
					diag_index <= QLE_i_counter + QLE_j_counter;
					if (polarity == 1'b1) begin
						if (QLE_j_counter == 1'b0) begin
							polarity = ~polarity;
							if (QLE_i_counter == 3'h7) begin
								QLE_j_counter <= QLE_j_counter + 3'h1;
							end
							else begin
								QLE_i_counter <= QLE_i_counter + 3'h1;
							end
						end
						else begin
							if (QLE_i_counter == 3'h7) begin
								QLE_j_counter <= QLE_j_counter + 3'h1;
								polarity = ~polarity;
							end
							else begin
								QLE_j_counter <= QLE_j_counter - 3'h1;
								QLE_i_counter <= QLE_i_counter + 3'h1;
							end
						end
					end
					else begin
						if (QLE_i_counter == 1'b0) begin
							polarity = ~polarity;
							QLE_j_counter <= QLE_j_counter + 3'h1;
						end
						else begin
							if (QLE_j_counter == 3'h7) begin
								QLE_i_counter <= QLE_i_counter + 3'h1;
								polarity = ~polarity;
							end
							else begin
								QLE_j_counter <= QLE_j_counter + 3'h1;
								QLE_i_counter <= QLE_i_counter - 3'h1;
							end
						end
					end
				end
			end
			S_DCT_QLE_RELEASE_ZEROS:begin
				if (group_zeros_counter != 0) begin  // Push /00-000 for a group of 8 zeros
					for (int i=0; i<21; i++) begin
						Encoded_Buffer[i+5] <= Encoded_Buffer[i];
					end
					Encoded_Buffer[4:0] <= {2'b00, 3'b000};
					if (pointer[4] == 1'b1) begin  // 16 or more
						pointer <= pointer - 5'd11;
					end
					else begin
						pointer <= pointer + 5'd5;
					end
					group_zeros_counter <= group_zeros_counter - 3'd1;
				end
				else begin	// Push /00-zeros_counter for a group of (n) zeros < 8
					if (zeros_counter != 0) begin
						for (int i=0; i<21; i++) begin
							Encoded_Buffer[i+5] <= Encoded_Buffer[i];
						end
						Encoded_Buffer[4:0] <= {2'b00, zeros_counter};
						if (pointer[4] == 1'b1) begin  // 16 or more
							pointer <= pointer - 5'd11;
						end
						else begin
							pointer <= pointer + 5'd5;
						end
						zeros_counter <= 3'd0;
					end
				end
				
				SRAM_we_n <= 1'b1;
				if (pointer[4] == 1'b1) begin  // 16 or more
					SRAM_write_data <= Encoded_Ready_to_Write[15:0];
					SRAM_address_QLE <= SRAM_address_QLE + 20'd1;
					Two_Byte_Counter <= Two_Byte_Counter + 1'd1;
					SRAM_we_n <= 1'b0;
				end
				
				if (((zeros_counter == 3'd0)&&(group_zeros_counter == 3'd1)) || (group_zeros_counter == 3'd0)) begin
					done_releasing_zeros <= 1'b1;
					DCT_QLE_state <= S_DCT_QLE_COM_0;
				end
			end
			S_DCT_QLE_1: begin
				DCT_QLE_state <= S_DCT_QLE_2;
				if (pointer != 5'd0) begin
					if (pointer[4] == 1'b1) begin  // 16 or more
						SRAM_address_QLE <= SRAM_address_QLE + 20'd1;
						SRAM_we_n <= 1'b0;
						Two_Byte_Counter <= Two_Byte_Counter + 1'd1;
						pointer <= pointer - 5'd16;
						SRAM_write_data <= Encoded_Ready_to_Write[15:0];
						DCT_QLE_state <= S_DCT_QLE_1;
					end
					else begin 
						if (last_block_in_channel_buffer[1] == 1'b1) begin
							// Pad last 16 bits, only if last block in last channel
							if (DCT_Sd_state == S_DCT_Sd_IDLE) begin
								SRAM_address_QLE <= SRAM_address_QLE + 20'd1;
								SRAM_we_n <= 1'b0;
								SRAM_write_data <= Encoded_Buffer[15:0] << (5'd16-pointer);
								pointer <= 5'd0;
								Encoded_Buffer <= 26'd0;
							end
						end
					end
				end
				
				if (last_block_in_channel_buffer[1] == 1'b1) begin
					// Write the offset of U or V the segment in the stream
					DCT_QLE_state <= S_DCT_QLE_WRITE_OFFSET_UV;
					if (DCT_Sd_state == S_DCT_Sd_IDLE) begin
						// Write the rest of the header
						DCT_QLE_state <= S_DCT_QLE_WRITE_Rest_Of_Header;
					end
				end

			end
			S_DCT_QLE_WRITE_OFFSET_UV: begin
				
				UV_Offset_index <= UV_Offset_index + 1'd1;
				
				if (UV_Offset_index == 1'd0) begin
					SRAM_address_QLE_Buffer <= SRAM_address_QLE;
				end
				else begin
					DCT_QLE_state <= S_DCT_QLE_2;
				end
				
				if (SRAM_Fetch_Segment == 2'd1) begin  // Y ended, Store U Offset
					SRAM_address_QLE <= (UV_Offset_index == 0)? 20'd6 : 20'd7;
				end
				else begin
					if (SRAM_Fetch_Segment == 2'd2) begin // U ended, Store V Offset
						SRAM_address_QLE <= (UV_Offset_index == 0)? 20'd8 : 20'd9;
					end
				end
				SRAM_we_n <= 1'b0;
				SRAM_write_data <= SRAM_write_data_UV_Offset;
			end

			S_DCT_QLE_WRITE_Rest_Of_Header: begin
				SRAM_address_QLE <= {17'd0, Header_Offset_index};
				SRAM_write_data <= SRAM_write_data_HEADER;
				SRAM_we_n <= 1'b0;
				Header_Offset_index <= Header_Offset_index + 3'd1;
				if (Header_Offset_index == 3'd5) begin
					DCT_QLE_state <= S_DCT_QLE_2;
				end
			end
			S_DCT_QLE_2: begin
				SRAM_we_n <= 1'b1;
				polarity <= 1'b1;
				Hold_COM_0 <= 1'b0;
				QLE_j_counter <= 3'h0;
				QLE_i_counter <= 3'h0;
				diag_index <= 4'd0;
				DCT_QLE_state <= S_DCT_QLE_HOLD;
				if (last_block_in_channel_buffer[1] == 1'b1) begin
					if (DCT_Sd_state == S_DCT_Sd_IDLE) begin
						DCT_QLE_state <= S_DCT_QLE_IDLE;
						SRAM_address_QLE <= 20'h0;
						finished <= 1'b1;
					end
					else begin
						SRAM_address_QLE <= SRAM_address_QLE_Buffer;
					end
				end
			end
			S_DCT_QLE_HOLD: begin
				if (timer == 8'd33) begin
					DCT_QLE_state <= S_DCT_QLE_0;
				end
			end
		endcase
	end
end

logic signed [15:0] Quantized, Sd_Read;
logic [2:0] Q_factor;
always_comb begin
	
	Sd_Embedded_RAM_Address_A_QLE = {QLE_i_counter, QLE_j_counter};
	
	Sd_Read = 16'd0;
	if (Write_in_Sd_RAM1 == 1'b1) begin
		Sd_Read = Sd_Embedded_RAM2_Read_Data_A[31:16];
	end
	else begin
		Sd_Read = Sd_Embedded_RAM1_Read_Data_A[31:16];
	end
	
	Q_factor = 3'd0;
	case(Q_Matrix)
		2'd0: begin   // Q0
			case(diag_index)
				3'd0:	Q_factor = 3'd3;   // /8
				3'd1: Q_factor = 3'd2;   // /4
				3'd2: Q_factor = 3'd3;   // /8
				3'd3: Q_factor = 3'd3;   // /8
				3'd4: Q_factor = 3'd4;   // /16
				3'd5: Q_factor = 3'd4;   // /16
				3'd6: Q_factor = 3'd5;   // /32
				3'd7: Q_factor = 3'd5;   // /32
				default: Q_factor = 3'd6; // /64
			endcase
		end
		2'd1: begin   // Q1
			case(diag_index)
				3'd0:	Q_factor = 3'd3;   // /8
				3'd1: Q_factor = 3'd2;   // /4
				3'd2: Q_factor = 3'd2;   // /4
				3'd3: Q_factor = 3'd2;   // /4
				3'd4: Q_factor = 3'd3;   // /8
				3'd5: Q_factor = 3'd3;   // /8
				3'd6: Q_factor = 3'd4;   // /16
				3'd7: Q_factor = 3'd4;   // /16
				default: Q_factor = 3'd5;// /32
			endcase
		end
		2'd2: begin   // Q2
			case(diag_index)
				3'd0:	Q_factor = 3'd3;   // /8
				3'd1: Q_factor = 3'd1;   // /2
				3'd2: Q_factor = 3'd1;   // /2
				3'd3: Q_factor = 3'd1;   // /2
				3'd4: Q_factor = 3'd2;   // /4
				3'd5: Q_factor = 3'd2;   // /4
				3'd6: Q_factor = 3'd3;   // /8
				3'd7: Q_factor = 3'd3;   // /8
				default: Q_factor = 3'd4;// /16
			endcase
		end
	endcase
	
	Quantized = 16'd0;
	case(Q_factor)
		3'd1: Quantized = (Sd_Read + 1) >>> 1;
		3'd2: Quantized = (Sd_Read + 2) >>> 2;  
		3'd3: Quantized = (Sd_Read + 4) >>> 3;
		3'd4: Quantized = (Sd_Read + 8) >>> 4;
		3'd5: Quantized = (Sd_Read + 16) >>> 5;
		3'd6: Quantized = (Sd_Read + 32) >>> 6;
	endcase
	

	Quantized_clipped = Quantized[8:0];
	
	if (done_releasing_zeros == 1'b1) begin
		Quantized_clipped = buffer_Quantized_clipped;
	end
	else begin
		if (Quantized < -256) begin
			Quantized_clipped = -9'd256;
		end
		else begin
			if (Quantized > 255) begin
				Quantized_clipped = 9'd255;
			end
		end
	end
	
	release_zeros = 1'b0;
	if ((Quantized_clipped != 9'd0) && ((zeros_counter != 3'd0)||(group_zeros_counter != 3'd0))) begin
		release_zeros = 1'b1;
	end			
	
	Encoded_Ready_to_Write = (Encoded_Buffer >> (pointer-5'd16));
	
	SRAM_write_data_UV_Offset = 0;
	case (UV_Offset_index)
		0: SRAM_write_data_UV_Offset <= {4'd0, Two_Byte_Counter[18:7]};
		1: SRAM_write_data_UV_Offset <= {Two_Byte_Counter[6:0], pointer[3], 5'd0, pointer[2:0]};
	endcase
	
	SRAM_write_data_HEADER = 0;
	case (Header_Offset_index) 
		0: SRAM_write_data_HEADER <= 16'hECE7;
		1: SRAM_write_data_HEADER <= {8'h44, 6'h0, Q_Matrix};
		2: SRAM_write_data_HEADER <= no_rows;
		3: SRAM_write_data_HEADER <= no_cols;
		4: SRAM_write_data_HEADER <= 16'd0;
		5: SRAM_write_data_HEADER <= {8'd20, 8'd0};
	endcase
	
end

assign SRAM_address = (DCT_FS_state == S_DCT_FS_HOLD || DCT_FS_state == S_DCT_FS_IDLE)? (SRAM_address_QLE+Encoded_Image_base_address) : SRAM_address_FS;

assign S_Embedded_RAM_Address_A = (DCT_FS_state == S_DCT_FS_HOLD || DCT_FS_state == S_DCT_FS_IDLE)? S_Embedded_RAM_Address_A_CT : S_Embedded_RAM_Address_A_FS;
assign S_Embedded_RAM_Address_B = (DCT_FS_state == S_DCT_FS_HOLD || DCT_FS_state == S_DCT_FS_IDLE)? S_Embedded_RAM_Address_B_CT : S_Embedded_RAM_Address_B_FS;

assign T_Embedded_RAM1_Address_A = (DCT_CT_state == S_DCT_CT_HOLD || DCT_CT_state == S_DCT_CT_IDLE)? T_Embedded_RAM1_Address_A_Sd : T_Embedded_RAM1_Address_A_CT;
assign T_Embedded_RAM1_Address_B = (DCT_CT_state == S_DCT_CT_HOLD || DCT_CT_state == S_DCT_CT_IDLE)? T_Embedded_RAM1_Address_B_Sd : T_Embedded_RAM1_Address_B_CT;

assign T_Embedded_RAM2_Address_A = (DCT_CT_state == S_DCT_CT_HOLD || DCT_CT_state == S_DCT_CT_IDLE)? T_Embedded_RAM2_Address_A_Sd : T_Embedded_RAM2_Address_A_CT;
assign T_Embedded_RAM2_Address_B = (DCT_CT_state == S_DCT_CT_HOLD || DCT_CT_state == S_DCT_CT_IDLE)? T_Embedded_RAM2_Address_B_Sd : T_Embedded_RAM2_Address_B_CT;

assign Sd_Embedded_RAM1_Address_A = (Write_in_Sd_RAM1 == 1'b1)? Sd_Embedded_RAM1_Address_A_Sd : Sd_Embedded_RAM_Address_A_QLE;
assign Sd_Embedded_RAM1_Address_B = (Write_in_Sd_RAM1 == 1'b1)? Sd_Embedded_RAM1_Address_B_Sd : 0;

assign Sd_Embedded_RAM2_Address_A = (Write_in_Sd_RAM1 == 1'b1)? Sd_Embedded_RAM_Address_A_QLE : Sd_Embedded_RAM2_Address_A_Sd;
assign Sd_Embedded_RAM2_Address_B = (Write_in_Sd_RAM1 == 1'b1)? 0 : Sd_Embedded_RAM2_Address_B_Sd;


endmodule