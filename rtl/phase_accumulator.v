`timescale 1ns / 1ps

module phase_accumulator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,          // Pulse when a new sample arrives
    input  wire signed [23:0] phase_step,  // Phase increment per sample
    output reg  signed [23:0] phase_out    // Accumulated phase
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_out <= 24'd0;
        end else if (en) begin
            phase_out <= phase_out + phase_step;
        end
    end

endmodule
