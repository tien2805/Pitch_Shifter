`timescale 1ns / 1ps

module tb_audio_loopback();

    // Clock and Reset
    reg bclk;
    reg sys_clk;
    reg rst_n;
    reg lrclk;

    // Simulated audio input
    reg  sdata_in;
    wire sdata_out;

    // internal wires
    wire [23:0] rx_left_data;
    wire [23:0] rx_right_data;
    wire        rx_valid;

    // FIFO interface (SYS domain)
    wire [47:0] fifo_rx_data;
    wire        fifo_rx_empty;
    reg         fifo_rx_rd_en;

    wire        fifo_tx_full;
    reg         fifo_tx_wr_en;
    reg  [47:0] fifo_tx_data;

    // FIFO interface (BCLK domain)
    wire [47:0] tx_i2s_data;
    wire        fifo_tx_empty;
    reg         fifo_tx_rd_en;

    // Clock Generation
    // 50 MHz SYS clock -> 20ns period
    initial begin
        sys_clk = 0;
        forever #10 sys_clk = ~sys_clk;
    end

    // ~3.072 MHz BCLK -> ~325.52 ns period -> ~162.76 ns half-period
    initial begin
        bclk = 0;
        forever #162.76 bclk = ~bclk;
    end

    // LRCLK Generation (BCLK / 64) -> 48kHz
    // 64 BCLKs per LRCLK (32 for Left, 32 for Right)
    reg [5:0] lrclk_div;
    always @(negedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            lrclk_div <= 0;
            lrclk <= 0;
        end else begin
            lrclk_div <= lrclk_div + 1;
            if (lrclk_div == 31) begin
                lrclk <= ~lrclk;
                lrclk_div <= 0;
            end
        end
    end

    // ==============================================
    // Device Under Test
    // ==============================================

    // 1. I2S Receiver
    i2s_rx u_i2s_rx (
        .bclk       (bclk),
        .rst_n      (rst_n),
        .lrclk      (lrclk),
        .sdata      (sdata_in),
        .left_data  (rx_left_data),
        .right_data (rx_right_data),
        .valid      (rx_valid)
    );

    // 2. Async FIFO RX (BCLK -> SYS)
    async_fifo #(
        .DATA_WIDTH (48),
        .ADDR_WIDTH (5)
    ) u_fifo_rx (
        .wr_clk     (bclk),
        .wr_rst_n   (rst_n),
        .wr_en      (rx_valid),
        .wr_data    ({rx_left_data, rx_right_data}),
        .wr_full    (), // ignore for now, assuming not full
        
        .rd_clk     (sys_clk),
        .rd_rst_n   (rst_n),
        .rd_en      (fifo_rx_rd_en),
        .rd_data    (fifo_rx_data),
        .rd_empty   (fifo_rx_empty)
    );

    // 3. SYS Domain Loopback Logic
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rx_rd_en <= 0;
            fifo_tx_wr_en <= 0;
            fifo_tx_data  <= 0;
        end else begin
            fifo_rx_rd_en <= 0;
            fifo_tx_wr_en <= 0;
            // Simple loopback: if RX has data and TX is not full, move data
            if (!fifo_rx_empty && !fifo_tx_full) begin
                fifo_rx_rd_en <= 1'b1;
                fifo_tx_wr_en <= 1'b1;
                fifo_tx_data  <= fifo_rx_data; // This uses combinational rd_data of the FIFO
            end
        end
    end

    // 4. Async FIFO TX (SYS -> BCLK)
    async_fifo #(
        .DATA_WIDTH (48),
        .ADDR_WIDTH (5)
    ) u_fifo_tx (
        .wr_clk     (sys_clk),
        .wr_rst_n   (rst_n),
        .wr_en      (fifo_tx_wr_en),
        .wr_data    (fifo_tx_data),
        .wr_full    (fifo_tx_full),
        
        .rd_clk     (bclk),
        .rd_rst_n   (rst_n),
        .rd_en      (fifo_tx_rd_en),
        .rd_data    (tx_i2s_data),
        .rd_empty   (fifo_tx_empty)
    );

    // 5. TX Logic: Read from FIFO and push to i2s_tx
    // We need to provide left_data and right_data to i2s_tx continuously.
    // We update them when a new frame starts.
    reg [23:0] tx_left_data;
    reg [23:0] tx_right_data;
    reg lrclk_d;
    
    always @(posedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            lrclk_d <= 0;
            fifo_tx_rd_en <= 0;
            tx_left_data <= 0;
            tx_right_data <= 0;
        end else begin
            lrclk_d <= lrclk;
            fifo_tx_rd_en <= 0;
            // On LRCLK rising edge (start of right channel transmission), 
            // we should prepare the next frame from FIFO so it's ready for the next LRCLK falling edge.
            // Alternatively, pull from FIFO when LRCLK falls.
            // Let's pull from FIFO when LRCLK rises, so data is stable before the next frame.
            if (lrclk == 1'b1 && lrclk_d == 1'b0) begin
                if (!fifo_tx_empty) begin
                    fifo_tx_rd_en <= 1'b1;
                    tx_left_data  <= tx_i2s_data[47:24];
                    tx_right_data <= tx_i2s_data[23:0];
                end
            end
        end
    end

    // 6. I2S Transmitter
    i2s_tx u_i2s_tx (
        .bclk       (bclk),
        .rst_n      (rst_n),
        .lrclk      (lrclk),
        .left_data  (tx_left_data),
        .right_data (tx_right_data),
        .sdata      (sdata_out)
    );

    // ==============================================
    // Stimulus Generation
    // ==============================================
    integer i;
    reg [23:0] test_left;
    reg [23:0] test_right;
    
    initial begin
        // VCD Dump
        $dumpfile("tb_audio_loopback.vcd");
        $dumpvars(0, tb_audio_loopback);

        rst_n = 0;
        sdata_in = 0;
        test_left = 24'hAAAAAA;
        test_right = 24'h555555;
        
        #200;
        rst_n = 1;
        
        // Wait for a few frames to sync up
        @(negedge lrclk);
        @(negedge lrclk);
        
        // Send frame 1
        // Left Channel
        for (i=23; i>=0; i=i-1) begin
            @(negedge bclk);
            sdata_in = test_left[i];
        end
        // Wait out the rest of left channel (32-24=8 bits)
        for (i=0; i<8; i=i+1) begin
            @(negedge bclk);
            sdata_in = 0;
        end
        
        // Right Channel
        for (i=23; i>=0; i=i-1) begin
            @(negedge bclk);
            sdata_in = test_right[i];
        end
        // Wait out the rest of right channel
        for (i=0; i<8; i=i+1) begin
            @(negedge bclk);
            sdata_in = 0;
        end
        
        // Send frame 2
        test_left = 24'h123456;
        test_right = 24'hFEDCBA;
        for (i=23; i>=0; i=i-1) begin
            @(negedge bclk);
            sdata_in = test_left[i];
        end
        for (i=0; i<8; i=i+1) begin
            @(negedge bclk);
            sdata_in = 0;
        end
        for (i=23; i>=0; i=i-1) begin
            @(negedge bclk);
            sdata_in = test_right[i];
        end
        for (i=0; i<8; i=i+1) begin
            @(negedge bclk);
            sdata_in = 0;
        end

        // Wait for loopback to propagate through both FIFOs
        #10000;
        
        $display("Simulation Finished.");
        $finish;
    end

endmodule
