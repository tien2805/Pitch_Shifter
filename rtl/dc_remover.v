`timescale 1ns / 1ps

module dc_remover (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire signed [23:0] data_in,
    output reg  signed [23:0] data_out
);

    reg signed [23:0] x_prev;
    reg signed [23:0] y_prev;

    function signed [23:0] sat24;
        input signed [25:0] value;
        begin
            if (value > 26'sd8388607) begin
                sat24 = 24'sh7FFFFF;
            end else if (value < -26'sd8388608) begin
                sat24 = 24'sh800000;
            end else begin
                sat24 = value[23:0];
            end
        end
    endfunction

    wire signed [25:0] data_in_ext = {{2{data_in[23]}}, data_in};
    wire signed [25:0] x_prev_ext  = {{2{x_prev[23]}}, x_prev};
    wire signed [25:0] y_prev_ext  = {{2{y_prev[23]}}, y_prev};
    wire signed [25:0] y_next_ext  = data_in_ext - x_prev_ext + y_prev_ext - (y_prev_ext >>> 8);
    wire signed [23:0] y_next      = sat24(y_next_ext);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_prev   <= 24'd0;
            y_prev   <= 24'd0;
            data_out <= 24'd0;
        end else if (en) begin
            // High-pass IIR Filter: y[n] = x[n] - x[n-1] + R * y[n-1]
            // Let R = 1 - 1/256 = 255/256
            // R * y[n-1] = y[n-1] - (y[n-1] >>> 8)
            data_out <= y_next;
            x_prev   <= data_in;
            y_prev   <= y_next;
        end
    end

endmodule
