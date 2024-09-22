`timescale 1ns/1ps

module TB;

    // Testbench Parameters
    localparam int NUM_STATES = 3;
    localparam int LFSR_BIT_WIDTH = 8;
    localparam int FRACTIONAL_BITS = 3;
    localparam int LFSR_PROJECTION_WIDTH = 20;
    localparam int LFSR_ACTIONS_WIDTH = 20;
    localparam int PROJECTION_CHANNELS = 1024;
    localparam int PROJECTION_ELEMENTS_PER_CLOCK = 128;
    localparam int LFSR_STATE_SIZE = 8;
    localparam int LFSR_ACTIONS = 4;
    localparam int LFSR_CYCLES = 625;
    localparam int LFSR_CHANNEL_SEPARATION = 625;
    localparam int LFSR_SEED = 20'd1;
    localparam int ACTIONS_CHANNELS = 512;
    localparam int ACTIONS_ELEMENTS_PER_CLOCK = 64;
    localparam int ADDR_WIDTH = 11;
    localparam int NUM_COLS = PROJECTION_ELEMENTS_PER_CLOCK / LFSR_STATE_SIZE;

    // Clock and Reset
    logic CLOCK_50_I;
    logic [17:0] SWITCH_I;
    
    // State vectors
    logic signed [LFSR_BIT_WIDTH-1:0] S [NUM_STATES-1:0][LFSR_STATE_SIZE-1:0];
    logic signed [LFSR_BIT_WIDTH+14-1:0] similarity_accumulator [LFSR_ACTIONS-1:0];

    // Instantiate the UUT
    HDC_QLearning #(
        .NUM_STATES(NUM_STATES),
        .LFSR_BIT_WIDTH(LFSR_BIT_WIDTH),
        .FRACTIONAL_BITS(FRACTIONAL_BITS),
        .LFSR_PROJECTION_WIDTH(LFSR_PROJECTION_WIDTH),
        .LFSR_ACTIONS_WIDTH(LFSR_ACTIONS_WIDTH),
        .PROJECTION_CHANNELS(PROJECTION_CHANNELS),
        .PROJECTION_ELEMENTS_PER_CLOCK(PROJECTION_ELEMENTS_PER_CLOCK),
        .LFSR_STATE_SIZE(LFSR_STATE_SIZE),
        .LFSR_ACTIONS(LFSR_ACTIONS),
        .LFSR_CYCLES(LFSR_CYCLES),
        .LFSR_CHANNEL_SEPARATION(LFSR_CHANNEL_SEPARATION),
        .LFSR_SEED(LFSR_SEED),
        .ACTIONS_CHANNELS(ACTIONS_CHANNELS),
        .ACTIONS_ELEMENTS_PER_CLOCK(ACTIONS_ELEMENTS_PER_CLOCK)
    ) UUT (
        .CLOCK_50_I(CLOCK_50_I),
        .SWITCH_I(SWITCH_I),
        .S(S),
        .similarity_accumulator(similarity_accumulator)
    );

    // Clock Generation
    always #10 CLOCK_50_I = ~CLOCK_50_I;

    // Testbench Initialization
    initial begin
        // Initialize clock and reset
        CLOCK_50_I = 0;
        SWITCH_I = 18'h3FFFF; // All switches on, including reset

        // Initialize BRAM with random values
        initialize_bram();

        $display("\n*** BRAM Initialization finished! System is starting.. ***");

        // Initialize state vectors
        S[0][0] = float_to_fixed(0.5);
        S[0][1] = float_to_fixed(-0.75);
        S[0][2] = float_to_fixed(1.25);
        S[0][3] = float_to_fixed(0.125);
        S[0][4] = float_to_fixed(-0.5);
        S[0][5] = float_to_fixed(0.875);
        S[0][6] = float_to_fixed(0.625);
        S[0][7] = float_to_fixed(-1.125);

        S[1][0] = float_to_fixed(-1.5);
        S[1][1] = float_to_fixed(1.75);
        S[1][2] = float_to_fixed(-1.25);
        S[1][3] = float_to_fixed(0.625);
        S[1][4] = float_to_fixed(1.5);
        S[1][5] = float_to_fixed(-0.875);
        S[1][6] = float_to_fixed(-0.625);
        S[1][7] = float_to_fixed(1.125);

        S[2][0] = float_to_fixed(0.25);
        S[2][1] = float_to_fixed(-0.125);
        S[2][2] = float_to_fixed(0.375);
        S[2][3] = float_to_fixed(-0.875);
        S[2][4] = float_to_fixed(0.75);
        S[2][5] = float_to_fixed(-1.0);
        S[2][6] = float_to_fixed(1.375);
        S[2][7] = float_to_fixed(-0.25);

        $display("\n*** Asserting the asynchronous reset ***");
        SWITCH_I[17] = 1'b1;

        #30;
        SWITCH_I[17] = 1'b0;
        $display("*** Deasserting the asynchronous reset ***\n");
        #10;

        // Wait for at least 1000 clock cycles
        repeat (1000) @(posedge CLOCK_50_I);

        // Simulation end
        $display("Simulation completed.");
        $stop;
    end

   // Task to initialize BRAM with random values
    task initialize_bram;
        int i;
        reg [63:0] random_value;
        @(posedge CLOCK_50_I); // Wait for clock edge
        UUT.Q_Embedded_RAM_we_A <= 1'b1; // Enable write
        UUT.Q_Embedded_RAM_we_B <= 1'b1; // Enable write
        for (i = 0; i < (1 << ADDR_WIDTH-1); i++) begin
            UUT.Q_Embedded_RAM_Pointer <= i;
            UUT.Q_Embedded_RAM_Data_A <= {$urandom, $urandom};  // Generate 64-bit random value
            UUT.Q_Embedded_RAM_Data_B <= {$urandom, $urandom};  // Generate 64-bit random value
            @(posedge CLOCK_50_I); // Wait for clock edge
        end
        UUT.Q_Embedded_RAM_we_A <= 1'b0; // Disable write
        UUT.Q_Embedded_RAM_we_B <= 1'b0; // Disable write
        UUT.Q_Embedded_RAM_Pointer <= 0;

    endtask

    // Function to convert a floating-point number to fixed-point representation
    function logic signed [LFSR_BIT_WIDTH-1:0] float_to_fixed(input real value);
        real scaled_value;
        // Scale the floating-point value by the fractional bits
        scaled_value = value * (1 << FRACTIONAL_BITS);
        // Round to the nearest integer and convert to fixed-point
        return $rtoi(scaled_value);
    endfunction

    // Function to convert a fixed-point number to floating-point representation
    function real fixed_to_float(input logic signed [LFSR_BIT_WIDTH-1:0] value);
        real result;
        // If the number is negative, extend the sign bit and then divide by 2^FRACTIONAL_BITS
        if (value[LFSR_BIT_WIDTH-1] == 1'b1) begin
            // Two's complement for the negative number
            result = -($itor(~value + 1) / (1 << FRACTIONAL_BITS));
        end else begin
            result = $itor(value) / (1 << FRACTIONAL_BITS);
        end
        return result;
    endfunction

endmodule
