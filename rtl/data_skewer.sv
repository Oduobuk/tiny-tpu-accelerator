`timescale 1ns / 1ps
// =============================================================================
// Module: data_skewer
// Description:
//   Staggers N input activation lanes so they enter the systolic array
//   with a diagonal wavefront. Row i is delayed by i clock cycles.
//   Row 0: 0 cycles delay
//   Row 1: 1 cycle delay
//   Row 2: 2 cycles delay
//   Row 3: 3 cycles delay
// =============================================================================

module data_skewer #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_WIDTH = 8
)(
    input  wire                                     clk,
    input  wire                                     rst_n,
    input  wire                                     en,
    input  wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]  data_in,
    output wire signed [ARRAY_SIZE*DATA_WIDTH-1:0]  data_out
);

    genvar i, d;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin : gen_skewer_row
            if (i == 0) begin : gen_row_0
                // Row 0 has zero delay
                assign data_out[DATA_WIDTH-1:0] = data_in[DATA_WIDTH-1:0];
            end else begin : gen_delayed_row
                // Shift register of depth i
                reg signed [DATA_WIDTH-1:0] delay_pipe [0:i-1];

                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (int k = 0; k < i; k = k + 1) begin
                            delay_pipe[k] <= '0;
                        end
                    end else if (en) begin
                        delay_pipe[0] <= data_in[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
                        for (int k = 1; k < i; k = k + 1) begin
                            delay_pipe[k] <= delay_pipe[k-1];
                        end
                    end
                end

                assign data_out[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] = delay_pipe[i-1];
            end
        end
    endgenerate

endmodule
