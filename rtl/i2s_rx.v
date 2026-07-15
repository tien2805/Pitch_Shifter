`timescale 1ns / 1ps

module i2s_rx (
    input  wire        bclk,       // Bit clock (~3.072 MHz for 48kHz stereo, 32 bits/channel)
    input  wire        rst_n,      // Asynchronous active-low reset
    input  wire        lrclk,      // Left/Right Word Clock (48kHz)
    input  wire        sdata,      // Serial Data In
    output reg  [23:0] left_data,  // 24-bit Left Channel Data
    output reg  [23:0] right_data, // 24-bit Right Channel Data
    output reg         valid       // Asserted high for 1 clock cycle when both channels are ready
);

    reg lrclk_d;
    reg [23:0] shift_reg;
    reg [4:0]  bit_cnt;

    // Delay LRCLK by 1 BCLK to detect edges
    always @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            lrclk_d <= 1'b0;
        end else begin
            lrclk_d <= lrclk;
        end
    end

    wire lrclk_edge = (lrclk != lrclk_d);

    // Standard I2S logic: Data shifts in on the rising edge of BCLK
    always @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            left_data  <= 24'd0;
            right_data <= 24'd0;
            shift_reg  <= 24'd0;
            bit_cnt    <= 5'd0;
            valid      <= 1'b0;
        end else begin
            valid <= 1'b0; // Default: pulse low
            
            if (lrclk_edge) begin
                bit_cnt <= 5'd0;
                // LRCLK=0 is Left Channel, LRCLK=1 is Right Channel.
                // The previous channel just finished transmitting.
                if (lrclk_d == 1'b0) begin
                    left_data <= shift_reg;
                end else begin
                    right_data <= shift_reg;
                    valid <= 1'b1; // Valid asserts after a complete Left/Right frame is loaded
                end
            end else begin
                if (bit_cnt < 24) begin
                    shift_reg <= {shift_reg[22:0], sdata};
                    bit_cnt   <= bit_cnt + 1;
                end
            end
        end
    end

endmodule
