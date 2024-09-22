module LFSR_PhaseShifter #(
    parameter int WIDTH = 20,
    parameter int CHANNELS = 1536, 
    parameter int BIT_WIDTH = 8,
    parameter int ELEMENTS_PER_CLOCK = 192, 
    parameter int CYCLES = 625,
    parameter int CHANNEL_SEPARATION = 625, 
    parameter logic [WIDTH-1:0] SEED = 1 
)(
    input logic clk,
    input logic rst_n,
    input logic initiate,
    output logic signed [BIT_WIDTH-1:0] data_stream [ELEMENTS_PER_CLOCK-1:0],
    output logic done
);

    // Internal signals
    logic [WIDTH-1:0] lfsr;
    logic [CHANNELS-1:0] channels;
    logic [9:0] cycle_count;
    logic state;

    // LFSR logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= SEED; // Initialize LFSR to seed value
            cycle_count <= 0;
            done <= 0;
            state <= 0;
        end else begin
            if(state == 0) begin
					lfsr <= SEED; // Initialize LFSR to seed value
					cycle_count <= 0;
					done <= 0;
					state <= 0;
               if (initiate) begin
                  state <= 1;
               end
            end else begin
                lfsr <= {lfsr[0] ^ lfsr[2] ^ lfsr[19], lfsr[WIDTH-1:1]};
                if (cycle_count < CYCLES) begin
                    cycle_count <= cycle_count + 1;
                end else begin
                    done <= 1;
						  state <= 0;
                end
            end
        end
    end
		
	 logic [WIDTH-1:0] shifted_state [CHANNELS-1:0];

    // Combinational Phase Shifter logic
    always_comb begin
        for (int i = 0; i < CHANNELS; i++) begin
				if (i == 0) begin
					shifted_state[i][0] = lfsr[0];
					shifted_state[i][1] = lfsr[1];
					shifted_state[i][2] = lfsr[2];
					shifted_state[i][3] = lfsr[3];
					shifted_state[i][4] = lfsr[4];
					shifted_state[i][5] = lfsr[5];
					shifted_state[i][6] = lfsr[6];
					shifted_state[i][7] = lfsr[7];
					shifted_state[i][8] = lfsr[8];
					shifted_state[i][9] = lfsr[9];
					shifted_state[i][10] = lfsr[10];
					shifted_state[i][11] = lfsr[11];
					shifted_state[i][12] = lfsr[12];
					shifted_state[i][13] = lfsr[13];
					shifted_state[i][14] = lfsr[14];
					shifted_state[i][15] = lfsr[15];
					shifted_state[i][16] = lfsr[16];
					shifted_state[i][17] = lfsr[17];
					shifted_state[i][18] = lfsr[18];
					shifted_state[i][19] = lfsr[19];
				end
				else begin // Applying the transformation matrix to shift the current lfsr state one channel width forward.
					shifted_state[i][0] = shifted_state[i-1][0] ^ shifted_state[i-1][2] ^ shifted_state[i-1][5] ^ shifted_state[i-1][6] ^ shifted_state[i-1][7]  ^ shifted_state[i-1][9]  ^ shifted_state[i-1][13] ^ shifted_state[i-1][16]  ^ shifted_state[i-1][17];
					shifted_state[i][1] = shifted_state[i-1][0] ^ shifted_state[i-1][1] ^ shifted_state[i-1][2] ^ shifted_state[i-1][4] ^ shifted_state[i-1][5]  ^ shifted_state[i-1][6]  ^ shifted_state[i-1][8] ^ shifted_state[i-1][12]  ^ shifted_state[i-1][15] ^ shifted_state[i-1][16] ^ shifted_state[i-1][19];
					shifted_state[i][2] = shifted_state[i-1][0] ^ shifted_state[i-1][1] ^ shifted_state[i-1][3] ^ shifted_state[i-1][4] ^ shifted_state[i-1][5]  ^ shifted_state[i-1][7]  ^ shifted_state[i-1][11] ^ shifted_state[i-1][14]  ^ shifted_state[i-1][15] ^ shifted_state[i-1][18];
					shifted_state[i][3] = shifted_state[i-1][0] ^ shifted_state[i-1][3] ^ shifted_state[i-1][4] ^ shifted_state[i-1][6] ^ shifted_state[i-1][10]  ^ shifted_state[i-1][13]  ^ shifted_state[i-1][14] ^ shifted_state[i-1][17]  ^ shifted_state[i-1][19];
					shifted_state[i][4] = shifted_state[i-1][3] ^ shifted_state[i-1][5] ^ shifted_state[i-1][9] ^ shifted_state[i-1][12] ^ shifted_state[i-1][13]  ^ shifted_state[i-1][16]  ^ shifted_state[i-1][18] ^ shifted_state[i-1][19];
					shifted_state[i][5] = shifted_state[i-1][2] ^ shifted_state[i-1][4] ^ shifted_state[i-1][8] ^ shifted_state[i-1][11] ^ shifted_state[i-1][12]  ^ shifted_state[i-1][15]  ^ shifted_state[i-1][17] ^ shifted_state[i-1][18];
					shifted_state[i][6] = shifted_state[i-1][1] ^ shifted_state[i-1][3] ^ shifted_state[i-1][7] ^ shifted_state[i-1][10] ^ shifted_state[i-1][11]  ^ shifted_state[i-1][14]  ^ shifted_state[i-1][16] ^ shifted_state[i-1][17];
					shifted_state[i][7] = shifted_state[i-1][0] ^ shifted_state[i-1][2] ^ shifted_state[i-1][6] ^ shifted_state[i-1][9] ^ shifted_state[i-1][10]  ^ shifted_state[i-1][13]  ^ shifted_state[i-1][15]  ^ shifted_state[i-1][16];
					shifted_state[i][8] = shifted_state[i-1][1] ^ shifted_state[i-1][2] ^ shifted_state[i-1][5] ^ shifted_state[i-1][8] ^ shifted_state[i-1][9]  ^ shifted_state[i-1][12]  ^ shifted_state[i-1][14]  ^ shifted_state[i-1][15] ^ shifted_state[i-1][19];
					shifted_state[i][9] = shifted_state[i-1][0] ^ shifted_state[i-1][1] ^ shifted_state[i-1][4] ^ shifted_state[i-1][7] ^ shifted_state[i-1][8]  ^ shifted_state[i-1][11]  ^ shifted_state[i-1][13]  ^ shifted_state[i-1][14] ^ shifted_state[i-1][18];
					shifted_state[i][10] = shifted_state[i-1][0] ^ shifted_state[i-1][2] ^ shifted_state[i-1][3] ^ shifted_state[i-1][6] ^ shifted_state[i-1][7]  ^ shifted_state[i-1][10]  ^ shifted_state[i-1][12]  ^ shifted_state[i-1][13] ^ shifted_state[i-1][17] ^ shifted_state[i-1][19];
					shifted_state[i][11] = shifted_state[i-1][1] ^ shifted_state[i-1][5] ^ shifted_state[i-1][6] ^ shifted_state[i-1][9] ^ shifted_state[i-1][11]  ^ shifted_state[i-1][12]  ^ shifted_state[i-1][16]  ^ shifted_state[i-1][18] ^ shifted_state[i-1][19];
					shifted_state[i][12] = shifted_state[i-1][0] ^ shifted_state[i-1][4] ^ shifted_state[i-1][5] ^ shifted_state[i-1][8] ^ shifted_state[i-1][10]  ^ shifted_state[i-1][11]  ^ shifted_state[i-1][15]  ^ shifted_state[i-1][17] ^ shifted_state[i-1][18];
					shifted_state[i][13] = shifted_state[i-1][2] ^ shifted_state[i-1][3] ^ shifted_state[i-1][4] ^ shifted_state[i-1][7] ^ shifted_state[i-1][9]  ^ shifted_state[i-1][10]  ^ shifted_state[i-1][14]  ^ shifted_state[i-1][16] ^ shifted_state[i-1][17] ^ shifted_state[i-1][19];
					shifted_state[i][14] = shifted_state[i-1][1] ^ shifted_state[i-1][2] ^ shifted_state[i-1][3] ^ shifted_state[i-1][6] ^ shifted_state[i-1][8]  ^ shifted_state[i-1][9]  ^ shifted_state[i-1][13]  ^ shifted_state[i-1][15] ^ shifted_state[i-1][16] ^ shifted_state[i-1][18];
					shifted_state[i][15] = shifted_state[i-1][0] ^ shifted_state[i-1][1] ^ shifted_state[i-1][2] ^ shifted_state[i-1][5] ^ shifted_state[i-1][7]  ^ shifted_state[i-1][8]  ^ shifted_state[i-1][12]  ^ shifted_state[i-1][14] ^ shifted_state[i-1][15] ^ shifted_state[i-1][17];
					shifted_state[i][16] = shifted_state[i-1][0] ^ shifted_state[i-1][1] ^ shifted_state[i-1][2] ^ shifted_state[i-1][4] ^ shifted_state[i-1][6]  ^ shifted_state[i-1][7]  ^ shifted_state[i-1][11]  ^ shifted_state[i-1][13] ^ shifted_state[i-1][14] ^ shifted_state[i-1][16] ^ shifted_state[i-1][19];
					shifted_state[i][17] = shifted_state[i-1][0] ^ shifted_state[i-1][1] ^ shifted_state[i-1][2] ^ shifted_state[i-1][3] ^ shifted_state[i-1][5]  ^ shifted_state[i-1][6]  ^ shifted_state[i-1][10]  ^ shifted_state[i-1][12] ^ shifted_state[i-1][13] ^ shifted_state[i-1][15] ^ shifted_state[i-1][18] ^ shifted_state[i-1][19];
					shifted_state[i][18] = shifted_state[i-1][0] ^ shifted_state[i-1][1] ^ shifted_state[i-1][4] ^ shifted_state[i-1][5] ^ shifted_state[i-1][9]  ^ shifted_state[i-1][11]  ^ shifted_state[i-1][12]  ^ shifted_state[i-1][14] ^ shifted_state[i-1][17] ^ shifted_state[i-1][18] ^ shifted_state[i-1][19];
					shifted_state[i][19] = shifted_state[i-1][0] ^ shifted_state[i-1][2] ^ shifted_state[i-1][3] ^ shifted_state[i-1][4] ^ shifted_state[i-1][8]  ^ shifted_state[i-1][10]  ^ shifted_state[i-1][11]  ^ shifted_state[i-1][13] ^ shifted_state[i-1][16] ^ shifted_state[i-1][17] ^ shifted_state[i-1][18] ^ shifted_state[i-1][19];
				end
				channels[i] = shifted_state[i][0];
        end
    end

    // Assemble the integers directly into the data_stream wires
    always_comb begin
        for (int k = 0; k < ELEMENTS_PER_CLOCK; k++) begin
            data_stream[k] = channels[k * BIT_WIDTH +: BIT_WIDTH];
        end
    end

endmodule
