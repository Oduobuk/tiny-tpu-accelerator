`timescale 1ns / 1ps
// =============================================================================
// Module: pe (Processing Element)
// Architecture: Weight-Stationary Multiply-Accumulate (MAC) Unit
// Description:
//   - Stores stationary 8-bit signed weight.
//   - Receives 8-bit signed activation from west, forwards to east on next cycle.
//   - Receives 32-bit signed partial sum from north, accumulates product,
//     and forwards result to south on next cycle.
// =============================================================================

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   load_weight,
    input  wire                   en,
    
    // Inputs (from West and North)
    input  wire signed [DATA_WIDTH-1:0] act_in,
    input  wire signed [DATA_WIDTH-1:0] weight_in,
    input  wire signed [ACC_WIDTH-1:0]  sum_in,

    // Outputs (to East and South)
    output reg  signed [DATA_WIDTH-1:0] act_out,
    output reg  signed [ACC_WIDTH-1:0]  sum_out
);

    // Stationary weight storage
    reg signed [DATA_WIDTH-1:0] weight_reg;

    // Multiplier output (INT8 x INT8 = INT16 sign-extended to ACC_WIDTH)
    wire signed [ACC_WIDTH-1:0] mult_result;
    assign mult_result = $signed(act_in) * $signed(weight_reg);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg <= '0;
            act_out    <= '0;
            sum_out    <= '0;
        end else begin
            // 1. Weight Preloading
            if (load_weight) begin
                weight_reg <= weight_in;
            end

            // 2. Systolic Execution & Forwarding
            if (en) begin
                act_out <= act_in;
                sum_out <= sum_in + mult_result;
            end
        end
    end

endmodule
