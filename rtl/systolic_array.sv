`timescale 1ns / 1ps
// =============================================================================
// Module: systolic_array
// Architecture: N x N 2D Weight-Stationary Systolic Array
// Description:
//   - Instantiates an ARRAY_SIZE x ARRAY_SIZE mesh of PEs.
//   - Horizontal lanes forward activations from West to East.
//   - Vertical lanes accumulate partial sums from North to South.
// =============================================================================

module systolic_array #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                                                 clk,
    input  wire                                                 rst_n,
    input  wire                                                 load_weight,
    input  wire                                                 en,

    // Activations entering West boundary
    input  wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]              act_in,

    // Flattened weights matrix (Row-major: weight[row][col])
    input  wire signed [ARRAY_SIZE*ARRAY_SIZE*DATA_WIDTH-1:0]   weight_in,

    // Partial sums entering North boundary (usually 0)
    input  wire signed [ARRAY_SIZE*ACC_WIDTH-1:0]               sum_in,

    // Activations leaving East boundary
    output wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]              act_out,

    // Accumulated results leaving South boundary
    output wire signed [ARRAY_SIZE*ACC_WIDTH-1:0]               sum_out
);

    // Internal interconnect buses
    // act_bus[r][c] is the horizontal wire leaving PE(r, c) to the East
    wire signed [DATA_WIDTH-1:0] act_bus [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    
    // sum_bus[r][c] is the vertical wire leaving PE(r, c) to the South
    wire signed [ACC_WIDTH-1:0]  sum_bus [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    genvar r, c;
    generate
        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin : gen_rows
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : gen_cols

                // West activation input selection
                wire signed [DATA_WIDTH-1:0] pe_act_in;
                if (c == 0) begin : gen_act_boundary
                    assign pe_act_in = act_in[(r+1)*DATA_WIDTH-1 : r*DATA_WIDTH];
                end else begin : gen_act_internal
                    assign pe_act_in = act_bus[r][c-1];
                end

                // North partial sum input selection
                wire signed [ACC_WIDTH-1:0] pe_sum_in;
                if (r == 0) begin : gen_sum_boundary
                    assign pe_sum_in = sum_in[(c+1)*ACC_WIDTH-1 : c*ACC_WIDTH];
                end else begin : gen_sum_internal
                    assign pe_sum_in = sum_bus[r-1][c];
                end

                // Stationary weight for this specific PE(r, c)
                wire signed [DATA_WIDTH-1:0] pe_weight;
                assign pe_weight = weight_in[((r*ARRAY_SIZE + c)+1)*DATA_WIDTH-1 : (r*ARRAY_SIZE + c)*DATA_WIDTH];

                // PE Instance
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .load_weight(load_weight),
                    .en         (en),
                    .act_in     (pe_act_in),
                    .weight_in  (pe_weight),
                    .sum_in     (pe_sum_in),
                    .act_out    (act_bus[r][c]),
                    .sum_out    (sum_bus[r][c])
                );

            end
        end
    endgenerate

    // Connect East boundary outputs
    generate
        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin : gen_east_out
            assign act_out[(r+1)*DATA_WIDTH-1 : r*DATA_WIDTH] = act_bus[r][ARRAY_SIZE-1];
        end
    endgenerate

    // Connect South boundary outputs
    generate
        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : gen_south_out
            assign sum_out[(c+1)*ACC_WIDTH-1 : c*ACC_WIDTH] = sum_bus[ARRAY_SIZE-1][c];
        end
    endgenerate

endmodule
