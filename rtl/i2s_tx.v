`timescale 1ns / 1ps

module i2s_tx (
    input  wire        bclk,       // Bit clock (~3.072 MHz for 48kHz stereo, 32 bits/channel)
    input  wire        rst_n,      // Asynchronous active-low reset
    input  wire        lrclk,      // Left/Right Word Clock
    input  wire [23:0] left_data,  // 24-bit Left Channel Data to send
    input  wire [23:0] right_data, // 24-bit Right Channel Data to send
    output reg         sdata       // Serial Data Out
);

    reg lrclk_d;
    reg [23:0] shift_reg;
    reg [4:0]  bit_cnt;
    
    // I2S spec: Data is driven on the falling edge of BCLK
    always @(negedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            lrclk_d   <= 1'b0;
            shift_reg <= 24'd0;
            bit_cnt   <= 5'd0;
            sdata     <= 1'b0;
        end else begin
            lrclk_d <= lrclk;
            
            // Detect LRCLK transition
            if (lrclk != lrclk_d) begin
                bit_cnt <= 5'd0;
                if (lrclk == 1'b0) begin 
                    shift_reg <= left_data;
                end else begin 
                    shift_reg <= right_data;
                end
                // Per I2S Standard: MSB is delayed 1 cycle after LRCLK toggles.
                // We don't drive MSB on this current falling edge, 
                // but we will do it on the NEXT falling edge (in the else branch below).
            end else begin
                if (bit_cnt < 24) begin
                    sdata     <= shift_reg[23];
                    shift_reg <= {shift_reg[22:0], 1'b0};
                    bit_cnt   <= bit_cnt + 1;
                end else begin
                    sdata <= 1'b0; // Pad zeros after 24 bits
                end
            end
        end
    end

endmodule
