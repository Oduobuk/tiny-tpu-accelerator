`timescale 1ns / 1ps
// =============================================================================
// Module: tiny_tpu_top
// Architecture: Complete Neural Matrix Multiply Engine
// Features:
//   - Integrated input activation skewer
//   - 4x4 Systolic Array core (Weight-Stationary)
//   - Output deskewer aligning staggered column results into parallel rows
//   - Fully automated FSM with calibrated latency strobe
// =============================================================================

module tiny_tpu_top #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                                                 clk,
    input  wire                                                 rst_n,

    // Control Signals
    input  wire                                                 load_weights,
    input  wire                                                 start_compute,
    output reg                                                  busy,
    output reg                                                  valid_out,

    // Weight Matrix Input (Flattened ARRAY_SIZE x ARRAY_SIZE)
    input  wire signed [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0]   weights,

    // Parallel Unskewed Activations Input (1 row of A per cycle)
    input  wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]              act_row_in,

    // Aligned Output Matrix Row (1 row of C per cycle)
    output wire signed [ARRAY_SIZE*ACC_WIDTH-1:0]               result_row_out
);

    // Internal skewed activation wires
    wire signed [ARRAY_SIZE*DATA_WIDTH-1:0] skewed_act;

    // Systolic array raw output (staggered by column)
    wire signed [ARRAY_SIZE*ACC_WIDTH-1:0]  raw_sum_out;

    // 1. Input Skewer
    data_skewer #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_in_skewer (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (start_compute | busy),
        .data_in (act_row_in),
        .data_out(skewed_act)
    );

    // 2. Systolic Array Core
    systolic_array #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .load_weight(load_weights),
        .en         (start_compute | busy),
        .act_in     (skewed_act),
        .weight_in  (weights),
        .sum_in     ('0), // Zero bias initialization
        .act_out    (),   // Unused East boundary
        .sum_out    (raw_sum_out)
    );

    // 3. Output Deskewer (Aligns staggered column results into synchronized rows)
    genvar c;
    generate
        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : gen_deskewer_col
            localparam DELAY = ARRAY_SIZE - 1 - c;

            if (DELAY == 0) begin : gen_zero_delay
                assign result_row_out[(c+1)*ACC_WIDTH-1 : c*ACC_WIDTH] = 
                    raw_sum_out[(c+1)*ACC_WIDTH-1 : c*ACC_WIDTH];
            end else begin : gen_delay_pipe
                reg signed [ACC_WIDTH-1:0] deskew_pipe [0:DELAY-1];

                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (int k = 0; k < DELAY; k = k + 1) begin
                            deskew_pipe[k] <= '0;
                        end
                    end else begin
                        deskew_pipe[0] <= raw_sum_out[(c+1)*ACC_WIDTH-1 : c*ACC_WIDTH];
                        for (int k = 1; k < DELAY; k = k + 1) begin
                            deskew_pipe[k] <= deskew_pipe[k-1];
                        end
                    end
                end

                assign result_row_out[(c+1)*ACC_WIDTH-1 : c*ACC_WIDTH] = deskew_pipe[DELAY-1];
            end
        end
    endgenerate

    // 4. Calibrated Latency & Output Handshake
    // Latency from activation input row 0 to deskewed output row 0 is (2 * ARRAY_SIZE - 2)
    localparam START_VALID = 2 * ARRAY_SIZE - 2;
    localparam END_VALID   = START_VALID + ARRAY_SIZE;
    localparam TOTAL_STEPS = END_VALID + 2;
    
    reg [7:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy        <= 1'b0;
            valid_out   <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            if (start_compute && !busy) begin
                busy        <= 1'b1;
                cycle_count <= 8'd0;
                valid_out   <= 1'b0;
            end else if (busy) begin
                cycle_count <= cycle_count + 1'b1;
                
                // Assert valid_out exactly when deskewed rows emerge
                if (cycle_count >= (START_VALID - 1) && cycle_count < (END_VALID - 1)) begin
                    valid_out <= 1'b1;
                end else begin
                    valid_out <= 1'b0;
                end

                if (cycle_count >= TOTAL_STEPS) begin
                    busy        <= 1'b0;
                    cycle_count <= 8'd0;
                end
            end
        end
    end

endmodule
