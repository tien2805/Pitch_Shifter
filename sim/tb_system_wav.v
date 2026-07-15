`timescale 1ns / 1ps

module tb_system_wav();

    reg sys_clk, bclk, rst_n, lrclk;
    reg sdata_in;
    wire sdata_out;

    // Pitch control phase step. 
    // switch_in defines the frequency shift. 
    // 24'h051111 is approx a small phase rotation per sample, shifting frequency nicely.
    reg [23:0] switch_in = 24'h051111; 

    // Instantiate Top Module
    pitch_shifter_top u_top (
        .sys_clk   (sys_clk),
        .bclk      (bclk),
        .rst_n     (rst_n),
        .lrclk     (lrclk),
        .sdata_in  (sdata_in),
        .switch_in (switch_in),
        .sdata_out (sdata_out)
    );

    // Clock Generation
    initial begin sys_clk = 0; forever #10 sys_clk = ~sys_clk; end // 50 MHz
    initial begin bclk = 0; forever #162.76 bclk = ~bclk; end      // 3.072 MHz (64 * 48kHz)

    // LRCLK Generation (48kHz)
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

    // File I/O
    integer fd_in, fd_out;
    reg [47:0] sample_data;
    integer scan_res;
    integer out_sample_count;

    // Write Logic (Capturing Output I2S Data)
    reg [23:0] out_left;
    reg [23:0] out_right;
    reg lrclk_del;
    reg [4:0] bit_cnt;

    initial begin
        out_left = 0;
        out_right = 0;
        lrclk_del = 0;
        bit_cnt = 0;
        out_sample_count = 0;
    end

    always @(posedge bclk) begin
        lrclk_del <= lrclk;
        // On LRCLK rising edge, the previous frame (left and right) just finished
        if (lrclk == 1'b1 && lrclk_del == 1'b0) begin
            // Don't record the first few empty frames
            if (out_sample_count > 5 && fd_out != 0) begin
                $fwrite(fd_out, "%06X%06X\n", out_left, out_right);
            end
            out_sample_count = out_sample_count + 1;
        end

        // Sniff I2S TX bitstream
        if (lrclk != lrclk_del) begin
            bit_cnt <= 0;
        end else begin
            if (bit_cnt < 24) begin
                if (lrclk_del == 1'b0) begin
                    out_left <= {out_left[22:0], sdata_out};
                end else begin
                    out_right <= {out_right[22:0], sdata_out};
                end
                bit_cnt <= bit_cnt + 1;
            end
        end
    end

    // Read Logic (Injecting Input I2S Data)
    integer i;
    initial begin
        sdata_in = 0;
        rst_n = 0;
        fd_in = $fopen("input.txt", "r");
        
        if (fd_in == 0) begin
            $display("==================================================");
            $display("WARNING: input.txt not found. Simulation will stop.");
            $display("Please run: python wav_processor.py encode input.wav input.txt");
            $display("==================================================");
            $stop;
        end else begin
            fd_out = $fopen("output.txt", "w");

            #200;
            rst_n = 1;
            
            // Wait for first LRCLK sync
            @(negedge lrclk);
            @(negedge lrclk);

            // Feed data to i2s_rx
            begin : read_loop
                while (!$feof(fd_in)) begin
                    scan_res = $fscanf(fd_in, "%h\n", sample_data);
                    if (scan_res == 1) begin
                        // Left Channel (Upper 24 bits)
                        for (i=23; i>=0; i=i-1) begin
                            @(negedge bclk);
                            sdata_in = sample_data[24 + i];
                        end
                        for (i=0; i<8; i=i+1) begin
                            @(negedge bclk);
                            sdata_in = 0;
                        end
                        
                        // Right Channel (Lower 24 bits)
                        for (i=23; i>=0; i=i-1) begin
                            @(negedge bclk);
                            sdata_in = sample_data[i];
                        end
                        for (i=0; i<8; i=i+1) begin
                            @(negedge bclk);
                            sdata_in = 0;
                        end
                    end else begin
                        // Avoid infinite loop if file format is weird
                        disable read_loop; 
                    end
                end
            end

            // Wait for data to flush through the 16-stage CORDIC and FIFOs
            #100000;
            $fclose(fd_in);
            $fclose(fd_out);
            $display("==================================================");
            $display("Simulation Complete.");
            $display("Captured %d frames.", out_sample_count);
            $display("Run: python wav_processor.py decode output.txt output.wav");
            $display("==================================================");
            $stop;
        end
    end

endmodule
