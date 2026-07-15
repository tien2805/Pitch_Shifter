`timescale 1ns / 1ps

module cordic_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire signed [23:0] x_in,     // Pre-scaled Audio input
    input  wire signed [23:0] y_in,     // Usually 0 for basic amplitude modulation
    input  wire signed [23:0] phase_in, // Q1.23 angle
    output reg  signed [23:0] x_out,    // x_in*cos - y_in*sin
    output reg  signed [23:0] y_out,    // x_in*sin + y_in*cos
    output reg         valid_out
);

    localparam signed [23:0] POS_HALF_PI = 24'sh400000;
    localparam signed [23:0] NEG_HALF_PI = -24'sh400000;
    localparam signed [23:0] HALF_TURN   = 24'sh800000;

    wire signed [23:0] atan_table [0:15];
    assign atan_table[0]  = 24'sh200000;
    assign atan_table[1]  = 24'sh12E405;
    assign atan_table[2]  = 24'sh09DED2;
    assign atan_table[3]  = 24'sh051111;
    assign atan_table[4]  = 24'sh028B0D;
    assign atan_table[5]  = 24'sh0145D7;
    assign atan_table[6]  = 24'sh00A2F6;
    assign atan_table[7]  = 24'sh00517C;
    assign atan_table[8]  = 24'sh0028BE;
    assign atan_table[9]  = 24'sh00145F;
    assign atan_table[10] = 24'sh000A2F;
    assign atan_table[11] = 24'sh000517;
    assign atan_table[12] = 24'sh00028B;
    assign atan_table[13] = 24'sh000145;
    assign atan_table[14] = 24'sh0000A2;
    assign atan_table[15] = 24'sh000051;

    reg signed [23:0] x [0:16];
    reg signed [23:0] y [0:16];
    reg signed [23:0] z [0:16];
    reg               v [0:16];

    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<=16; i=i+1) begin
                x[i] <= 24'd0;
                y[i] <= 24'd0;
                z[i] <= 24'd0;
                v[i] <= 1'b0;
            end
            x_out   <= 24'd0;
            y_out   <= 24'd0;
            valid_out <= 1'b0;
        end else begin
            // Stage 0: Input loading & Quadrant Pre-mapping
            // CORDIC only converges for angles between -90 and +90 degrees.
            // If the angle is outside this range (Q2 or Q3), we rotate it by 180 degrees
            // and invert the inputs (X and Y) to compensate.
            if (phase_in > POS_HALF_PI) begin
                // > +90 degrees (Quadrant 2)
                x[0] <= -x_in;
                y[0] <= -y_in;
                z[0] <= phase_in + HALF_TURN;
            end
            else if (phase_in < NEG_HALF_PI) begin
                // < -90 degrees (Quadrant 3)
                x[0] <= -x_in;
                y[0] <= -y_in;
                z[0] <= phase_in + HALF_TURN;
            end
            else begin
                // Normal Range (Quadrant 1 & 4)
                x[0] <= x_in;
                y[0] <= y_in;
                z[0] <= phase_in;
            end
            v[0] <= valid_in;

            // Stages 1 to 16
            for (i=1; i<=16; i=i+1) begin
                v[i] <= v[i-1];
                if (z[i-1][23] == 1'b0) begin // z >= 0
                    x[i] <= x[i-1] - (y[i-1] >>> (i-1));
                    y[i] <= y[i-1] + (x[i-1] >>> (i-1));
                    z[i] <= z[i-1] - atan_table[i-1];
                end else begin                // z < 0
                    x[i] <= x[i-1] + (y[i-1] >>> (i-1));
                    y[i] <= y[i-1] - (x[i-1] >>> (i-1));
                    z[i] <= z[i-1] + atan_table[i-1];
                end
            end

            x_out   <= x[16];
            y_out   <= y[16];
            valid_out <= v[16];
        end
    end

endmodule
