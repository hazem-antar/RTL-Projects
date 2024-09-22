module HDC_QLearning #(
    parameter int NUM_STATES = 3,                    // Number of states
    parameter int LFSR_BIT_WIDTH = 8,                // Bit width of the data stream and states
    parameter int FRACTIONAL_BITS = 3,               // Number of fractional bits
    parameter int LFSR_PROJECTION_WIDTH = 20,        // LFSR width
	 parameter int LFSR_ACTIONS_WIDTH = 20,           // LFSR width
    parameter int PROJECTION_CHANNELS = 1024,        // Number of LFSR channels for the ProjectionMatrix
    parameter int PROJECTION_ELEMENTS_PER_CLOCK = 128, // Number of elements generated per clock for the ProjectionMatrix
    parameter int LFSR_STATE_SIZE = 8,               // Number of elements in each state
    parameter int LFSR_ACTIONS = 4,                  // Number of actions
    parameter int LFSR_CYCLES = 625,                 // Number of cycles
    parameter int LFSR_CHANNEL_SEPARATION = 625,     // Channel separation
    parameter int LFSR_SEED = 20'd1,                 // LFSR seed
    parameter int ACTIONS_CHANNELS = 512,            // Number of LFSR channels for the ActionsMatrix
    parameter int ACTIONS_ELEMENTS_PER_CLOCK = 64    // Number of elements generated per clock for the ActionsMatrix
) (
    /////// Board clocks ////////////
    input logic CLOCK_50_I,                          // 50 MHz clock

    /////// Pushbuttons/switches ////////////
    input logic [17:0] SWITCH_I,                     // toggle switches
    
    // State vectors from the testbench
    input logic signed [LFSR_BIT_WIDTH-1:0] S [NUM_STATES-1:0][LFSR_STATE_SIZE-1:0],
    
    // Signals for data streaming
	 output logic signed [LFSR_BIT_WIDTH+14-1:0] similarity_accumulator [LFSR_ACTIONS-1:0]
);	
	 // Import the cos_lookup package
	 import cosine_pkg::*;

    localparam int NUM_COLS = PROJECTION_ELEMENTS_PER_CLOCK / LFSR_STATE_SIZE; // Number of columns generated per clock
    localparam int Q_HV_WIDTH = 8;
    localparam int ADDR_WIDTH = 11; // 11-bit address for the BRAM
    
    logic Resetn, initiate_LFSR_PROJECTION_GENERATOR, initiate_LFSR_ACTIONS_GENERATOR;
    logic signed [LFSR_BIT_WIDTH-1:0] projection_stream [PROJECTION_ELEMENTS_PER_CLOCK-1:0];
    logic signed [LFSR_BIT_WIDTH-1:0] actions_stream [ACTIONS_ELEMENTS_PER_CLOCK-1:0];
    logic signed [LFSR_BIT_WIDTH-1:0] sum_permu_states [LFSR_STATE_SIZE-1:0]; // Sum of permuted states
    logic signed [LFSR_BIT_WIDTH-1:0] Stack_StateHV [NUM_COLS-1:0]; // Stacked States Hypervector wire
	 logic signed [LFSR_BIT_WIDTH-1:0] Stack_StateHV_buffered [NUM_COLS-1:0]; // Stacked States Hypervector reg
	 logic signed [LFSR_BIT_WIDTH-1:0] ReferenceHV [NUM_COLS-1:0]; // Buffer carrying the reference Hypervector
    logic signed [LFSR_BIT_WIDTH-1:0] state_actionsHVs [LFSR_ACTIONS-1:0][NUM_COLS-1:0]; 
	 logic signed [LFSR_BIT_WIDTH-1:0] Q_S_A_HVs [LFSR_ACTIONS-1:0][NUM_COLS-1:0]; 
	 logic signed [LFSR_BIT_WIDTH-1:0] Q_S_A_HVs_buffered [LFSR_ACTIONS-1:0][NUM_COLS-1:0]; // Buffer carrying all Q(s,a) 
	 logic signed [LFSR_BIT_WIDTH-1:0] diff_angles [LFSR_ACTIONS-1:0][NUM_COLS-1:0]; 
	 logic signed [LFSR_BIT_WIDTH-1:0] cos_similarities [LFSR_ACTIONS-1:0][NUM_COLS-1:0]; 
	 logic signed [LFSR_BIT_WIDTH-1:0] cos_similarities_buffered [LFSR_ACTIONS-1:0][NUM_COLS-1:0];  // Buffer carrying all cos similarities
	 logic signed [LFSR_BIT_WIDTH+4-1:0] partial_similarity [LFSR_ACTIONS-1:0]; 
	 

    // Embedded RAM wires
    logic [63:0] Q_Embedded_RAM_Read_Data_A, Q_Embedded_RAM_Read_Data_B;
    logic [63:0] Q_Embedded_RAM_Data_A, Q_Embedded_RAM_Data_B;
    logic [ADDR_WIDTH-1:0] Q_Embedded_RAM_Address_A, Q_Embedded_RAM_Address_B;
	 logic [ADDR_WIDTH-2:0] Q_Embedded_RAM_Pointer;
	 logic Q_Embedded_RAM_we_A, Q_Embedded_RAM_we_B;

    // Q_HV logic of size 16x8
    logic signed [LFSR_BIT_WIDTH-1:0] Q_HV [NUM_COLS-1:0];
    
	 logic resetn;
	 
	 logic LFSR_PROJECTION_done, LFSR_ACTIONS_GENERATOR_done;
	 
    assign resetn = ~SWITCH_I[17];

    // Instantiate the LFSR_PhaseShifter module for the projection matrix
    LFSR_PhaseShifter #(
        .WIDTH(LFSR_PROJECTION_WIDTH),
        .CHANNELS(PROJECTION_CHANNELS), 
        .BIT_WIDTH(LFSR_BIT_WIDTH),
        .ELEMENTS_PER_CLOCK(PROJECTION_ELEMENTS_PER_CLOCK),
        .CYCLES(LFSR_CYCLES),
        .CHANNEL_SEPARATION(LFSR_CHANNEL_SEPARATION),
        .SEED(LFSR_SEED) 
    ) LFSR_PROJECTION_GENERATOR (
        .clk(CLOCK_50_I),
        .rst_n(resetn),
        .initiate(initiate_LFSR_PROJECTION_GENERATOR), // Initiate signal
        .data_stream(projection_stream),
        .done(LFSR_PROJECTION_done)
    );
	 
	 // Instantiate the LFSR_PhaseShifter module for the actions HV matrix
    LFSR_PhaseShifter #(
        .WIDTH(LFSR_ACTIONS_WIDTH),
        .CHANNELS(ACTIONS_CHANNELS),
        .BIT_WIDTH(LFSR_BIT_WIDTH),
        .ELEMENTS_PER_CLOCK(ACTIONS_ELEMENTS_PER_CLOCK),
        .CYCLES(LFSR_CYCLES),
        .CHANNEL_SEPARATION(LFSR_CHANNEL_SEPARATION),
        .SEED(LFSR_SEED) 
    ) LFSR_ACTIONS_GENERATOR (
        .clk(CLOCK_50_I),
        .rst_n(resetn),
        .initiate(initiate_LFSR_ACTIONS_GENERATOR), // Initiate signal
        .data_stream(actions_stream),
        .done(LFSR_ACTIONS_GENERATOR_done)
    );

	
	 Q_BRAM	Q_BRAM_1  (
		.address_a ( Q_Embedded_RAM_Address_A ),
		.address_b ( Q_Embedded_RAM_Address_B ),
		.clock ( CLOCK_50_I ),
		.data_a ( Q_Embedded_RAM_Data_A ),
		.data_b ( Q_Embedded_RAM_Data_B ),
		.wren_a ( Q_Embedded_RAM_we_A ),
		.wren_b ( Q_Embedded_RAM_we_B ),
		.q_a ( Q_Embedded_RAM_Read_Data_A ),
		.q_b ( Q_Embedded_RAM_Read_Data_B )
		);


	 logic [2:0] state;
    // Initialize address and initiate signal on reset
    always_ff @ (posedge CLOCK_50_I or negedge resetn) begin

		if (resetn == 1'b0) begin
			// Reset Signals
			initiate_LFSR_PROJECTION_GENERATOR <= 0;
			initiate_LFSR_ACTIONS_GENERATOR <= 0;
			state <= 0;
			for (int a = 0; a < LFSR_ACTIONS; a++) begin
					similarity_accumulator[a] <= 22'd0;
			end
			for (int i = 0; i < NUM_COLS; i++) begin
				Stack_StateHV_buffered[i] <= 0;
				for (int a = 0; a < LFSR_ACTIONS; a++) begin
					cos_similarities_buffered[a][i] <= 0;
				end
			end
		end
		else begin
			if (state == 3'd0) begin
			   Q_Embedded_RAM_we_A <= 1'b0;
				Q_Embedded_RAM_we_B <= 1'b0;
				Q_Embedded_RAM_Data_A <= 64'h0;
				Q_Embedded_RAM_Data_B <= 64'h0;
				state <= 3'd1;
				Q_Embedded_RAM_Pointer <= 0;
				initiate_LFSR_PROJECTION_GENERATOR <= 0;
				initiate_LFSR_ACTIONS_GENERATOR <= 0;
				for (int a = 0; a < LFSR_ACTIONS; a++) begin
					similarity_accumulator[a] <= 22'd0;
				end
				for (int i = 0; i < NUM_COLS; i++) begin
					Stack_StateHV_buffered[i] <= 0;
					for (int a = 0; a < LFSR_ACTIONS; a++) begin
						cos_similarities_buffered[a][i] <= 0;
					end
				end
			end
			else begin
				if (state == 3'd1) begin 
					initiate_LFSR_PROJECTION_GENERATOR <= 1;
					state <= 3'd2;
				end
				else begin
					if (state == 3'd2) begin 
						state <= 3'd3;
						Q_Embedded_RAM_Pointer <= Q_Embedded_RAM_Pointer + 1;
						initiate_LFSR_ACTIONS_GENERATOR <= 1;
					end
					else begin
						if (state == 3'd3) begin 
							state <= 3'd4;
							// Buffer the stacked state for the next stage
							for (int i = 0; i < NUM_COLS; i++) begin
								Stack_StateHV_buffered[i] <= Stack_StateHV[i];
							end
						end
						else begin
							if (state == 3'd4) begin 
								 state <= 3'd5;
								 // Buffer all Q(s,a) and a action 0 as a refrence
								 for (int i = 0; i < NUM_COLS; i++) begin
									 for (int a = 0; a < LFSR_ACTIONS; a++) begin
										 Q_S_A_HVs_buffered[a][i] <= Q_S_A_HVs[a][i];
									 end
									 ReferenceHV[i] <=  actions_stream[i * LFSR_ACTIONS];
								 end
							end
							else begin
								if (state == 3'd5) begin
									state <= 3'd6;
									// Buffer all cos similarites
									for (int i = 0; i < NUM_COLS; i++) begin
										for (int a = 0; a < LFSR_ACTIONS; a++) begin
											cos_similarities_buffered[a][i] <= cos_similarities[a][i];
										end
									end
								end
								else begin
									// Accumulate the partial sums of similarities
									for (int a = 0; a < LFSR_ACTIONS; a++) begin
										similarity_accumulator[a] <= similarity_accumulator[a] + partial_similarity[a];
									end
								end
							end
						end
					end
				end
			end
		end
    end

	 // Generate BRAM Address_A and Address_B from the pointer
	 assign Q_Embedded_RAM_Address_A = {Q_Embedded_RAM_Pointer, 1'b0};
	 assign Q_Embedded_RAM_Address_B = {Q_Embedded_RAM_Pointer, 1'b1};
	 
	 
	  // Prepare the Q Hypervector
	 always_comb begin
		 // Fill Q_HV with the data read from RAM
        for (int i = 0; i < 8; i++) begin
				Q_HV[i] = Q_Embedded_RAM_Read_Data_A[8*i +: 8];
				Q_HV[i+8] = Q_Embedded_RAM_Read_Data_B[8*i +: 8];
        end
	 end
	 
	 
	// Prepare Stacked States Hypervector
	always_comb begin

		// Compute the summation of permuted states
		for (int j = 0; j < LFSR_STATE_SIZE; j++) begin
			sum_permu_states[j] = $signed(S[0][j]);
			for (int n = 1; n < NUM_STATES; n++) begin
				 // Vector of sums of state elements after applying permutation
				 // ex: [(s00+s11+s22), ..., (s07+s10+s21)]
				 sum_permu_states[j] += $signed(S[n][(j + n) % LFSR_STATE_SIZE]);
			end
		end
		  

		// Compute Stacked States Hypervector
		for (int i = 0; i < NUM_COLS; i++) begin
		
			for (int j = 0; j < LFSR_STATE_SIZE; j++) begin
			
				 logic signed [LFSR_BIT_WIDTH-1:0] Stack_StateHV_element [NUM_COLS-1:0];
				 
				 // compute partial value of each element in the stack, 
				 // ex: E0 = (s00+s11+s22)A00 + ... + (s07+s10+s21)A70
				 // where A is the Upprojection matrix
				 Stack_StateHV_element[i] = (sum_permu_states[j] * projection_stream[i * LFSR_STATE_SIZE + j]) >>> FRACTIONAL_BITS;
				 
				 // Truncate and accumulate the element letting it overflow for simulating modulo
				 if (j == 0) begin
					Stack_StateHV[i] = Stack_StateHV_element[i][LFSR_BIT_WIDTH-1:0];
				 end
				 else begin
					Stack_StateHV[i] += Stack_StateHV_element[i][LFSR_BIT_WIDTH-1:0];
				 end
				 
			end
		end
		
	end
	 
    // Compute the state_action bounds and unbind from Q
    always_comb begin
		  
        // Compute Stack_StateHV
        for (int i = 0; i < NUM_COLS; i++) begin
				
            // Bind stacked states with all actions
            for (int a = 0; a < LFSR_ACTIONS; a++) begin
					 
					 // Compute all state_action bound
                state_actionsHVs[a][i] = Stack_StateHV_buffered[i] + actions_stream[i * LFSR_ACTIONS + a];
					 
					 // Compute all Q(s,a)
					 Q_S_A_HVs[a][i] = Q_HV[i] - state_actionsHVs[a][i];
					 
				end
        end

    end
	
	// Calculate the similarity.
    always_comb begin
		  
        // Compute Stack_StateHV
        for (int i = 0; i < NUM_COLS; i++) begin
				
            // Bind stacked states with all actions
            for (int a = 0; a < LFSR_ACTIONS; a++) begin
					 
					 // Compute the partial similarities for all Q(s,a) from the reference vector
					 diff_angles[a][i] = Q_S_A_HVs_buffered[a][i] - ReferenceHV[i];  //  Action (0) from all the Q(s,a)
					 
					 // Compute the cos similarities
					 cos_similarities[a][i] = cos_lookup(diff_angles[a][i]);
				end
        end

    end
	 
	 // Calculate the similarity.
    always_comb begin
		  
        // Compute Stack_StateHV
        for (int i = 0; i < NUM_COLS; i++) begin
				
            // Bind stacked states with all actions
            for (int a = 0; a < LFSR_ACTIONS; a++) begin
					
					 // Compute the partial similarities for all Q(s,a)
					 if (i == 0) begin
						partial_similarity[a] = cos_similarities_buffered[a][i];
					 end
					 else begin
						partial_similarity[a] += cos_similarities_buffered[a][i];
					 end
					 
				end
        end

    end
	 
endmodule
