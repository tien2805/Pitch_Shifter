`timescale 1ns / 1ps

module pitch_shifter_top (
    input  wire        sys_clk,    // 50 MHz System Clock
    input  wire        bclk,       // 3.072 MHz Audio Bit Clock (48 kHz * 2 * 32)
    input  wire        rst_n,      // Asynchronous active-low reset
    input  wire        lrclk,      // 48 kHz Word Clock
    input  wire        sdata_in,   // I2S serial data from Mic
    input  wire [23:0] switch_in,  // Pitch control phase step
    output wire        sdata_out   // I2S serial data to DAC
);

    // ==============================================
    // 1. I2S Receiver (BCLK Domain)
    // ==============================================
    wire [23:0] rx_left;
    wire [23:0] rx_right;
    wire        rx_valid;

    i2s_rx u_i2s_rx (
        .bclk       (bclk),
        .rst_n      (rst_n),
        .lrclk      (lrclk),
        .sdata      (sdata_in),
        .left_data  (rx_left),
        .right_data (rx_right),
        .valid      (rx_valid)
    );

    // ==============================================
    // 2. Async FIFO RX (BCLK -> SYS)
    // ==============================================
    wire [47:0] fifo_rx_data_out;
    wire        fifo_rx_empty;
    wire        fifo_rx_full;
    wire        fifo_rx_rd_en;
    
    async_fifo #(
        .DATA_WIDTH (48),
        .ADDR_WIDTH (5)
    ) u_fifo_rx (
        .wr_clk     (bclk),
        .wr_rst_n   (rst_n),
        .wr_en      (rx_valid && !fifo_rx_full),
        .wr_data    ({rx_left, rx_right}),
        .wr_full    (fifo_rx_full), 
        
        .rd_clk     (sys_clk),
        .rd_rst_n   (rst_n),
        .rd_en      (fifo_rx_rd_en),
        .rd_data    (fifo_rx_data_out),
        .rd_empty   (fifo_rx_empty)
    );

    // ==============================================
    // 3. DSP Processing Core (SYS Domain)
    // ==============================================
    wire [23:0] sys_audio_in_l = fifo_rx_data_out[47:24];
    wire [23:0] sys_audio_in_r = fifo_rx_data_out[23:0];
    
    wire [23:0] sys_audio_out_l;
    wire [23:0] sys_audio_out_r;
    wire        sys_valid_out;

    // Read from FIFO when not empty. 
    // This valid pulse drives the processing pipeline.
    assign fifo_rx_rd_en = ~fifo_rx_empty;

    // Synchronize external switches into the SYS clock domain.
    reg [23:0] switch_sync1;
    reg [23:0] switch_sync2;
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            switch_sync1 <= 24'd0;
            switch_sync2 <= 24'd0;
        end else begin
            switch_sync1 <= switch_in;
            switch_sync2 <= switch_sync1;
        end
    end

    wire signed [23:0] phase_step = switch_sync2;

    pitch_shift_ctrl u_pitch_ctrl (
        .clk        (sys_clk),
        .rst_n      (rst_n),
        .audio_in_l (sys_audio_in_l),
        .audio_in_r (sys_audio_in_r),
        .valid_in   (fifo_rx_rd_en),
        .phase_step (phase_step),
        .audio_out_l(sys_audio_out_l),
        .audio_out_r(sys_audio_out_r),
        .valid_out  (sys_valid_out)
    );

    // ==============================================
    // 4. Async FIFO TX (SYS -> BCLK)
    // ==============================================
    wire [47:0] fifo_tx_data_out;
    wire        fifo_tx_empty;
    wire        fifo_tx_full;
    wire        fifo_tx_rd_en;
    
    async_fifo #(
        .DATA_WIDTH (48),
        .ADDR_WIDTH (5)
    ) u_fifo_tx (
        .wr_clk     (sys_clk),
        .wr_rst_n   (rst_n),
        .wr_en      (sys_valid_out && !fifo_tx_full),
        .wr_data    ({sys_audio_out_l, sys_audio_out_r}),
        .wr_full    (fifo_tx_full),
        
        .rd_clk     (bclk),
        .rd_rst_n   (rst_n),
        .rd_en      (fifo_tx_rd_en),
        .rd_data    (fifo_tx_data_out),
        .rd_empty   (fifo_tx_empty)
    );

    // ==============================================
    // 5. I2S Transmitter (BCLK Domain)
    // ==============================================
    reg [23:0] tx_left_data;
    reg [23:0] tx_right_data;
    reg lrclk_d;
    
    always @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            lrclk_d       <= 1'b0;
            tx_left_data  <= 24'd0;
            tx_right_data <= 24'd0;
        end else begin
            lrclk_d <= lrclk;
            // Fetch frame when LRCLK rises.
            if (lrclk == 1'b1 && lrclk_d == 1'b0) begin
                if (!fifo_tx_empty) begin
                    tx_left_data  <= fifo_tx_data_out[47:24];
                    tx_right_data <= fifo_tx_data_out[23:0];
                end
            end
        end
    end

    // Read enable to FIFO exactly 1 cycle
    assign fifo_tx_rd_en = (lrclk == 1'b1 && lrclk_d == 1'b0) && !fifo_tx_empty;

    i2s_tx u_i2s_tx (
        .bclk       (bclk),
        .rst_n      (rst_n),
        .lrclk      (lrclk),
        .left_data  (tx_left_data),
        .right_data (tx_right_data),
        .sdata      (sdata_out)
    );

endmodule
