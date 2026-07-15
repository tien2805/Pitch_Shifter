`timescale 1ns / 1ps

// ============================================================
//  tb_demo.v â€” Testbench Demo cho Pitch Shifter DSP Core
//  BÆ¡m trá»±c tiáº¿p dá»¯ liá»‡u 24-bit song song vÃ o pitch_shift_ctrl
//  (bá» qua I2S serial vÃ  Async FIFO Ä‘á»ƒ mÃ´ phá»ng cá»±c nhanh)
// ============================================================

module tb_demo();

    // === DEMO CONFIGURATION ===
    // Thay Ä‘á»•i PHASE_STEP Ä‘á»ƒ thá»­ cÃ¡c má»©c dá»‹ch táº§n khÃ¡c nhau:
    //   24'h011111 = ~200 Hz sideband spacing
    //   24'h02AAAB = ~500 Hz sideband spacing
    //   24'h055555 = ~1000 Hz sideband spacing
    //   24'h0AAAAB = ~2000 Hz sideband spacing
    parameter NUM_SAMPLES = 2048;
    parameter PHASE_STEP  = 24'h055555;  // ~1000 Hz shift

    // === Signals ===
    reg         clk, rst_n;
    reg  signed [23:0] audio_in_l, audio_in_r;
    reg         valid_in;
    reg  signed [23:0] phase_step;

    wire signed [23:0] audio_out_l, audio_out_r;
    wire        valid_out;

    // Input sample memory (loaded from hex file)
    reg [23:0] input_mem [0:NUM_SAMPLES-1];

    // === Instantiate DSP Core (bypass I2S & FIFO) ===
    pitch_shift_ctrl u_dsp (
        .clk        (clk),
        .rst_n      (rst_n),
        .audio_in_l (audio_in_l),
        .audio_in_r (audio_in_r),
        .valid_in   (valid_in),
        .phase_step (phase_step),
        .audio_out_l(audio_out_l),
        .audio_out_r(audio_out_r),
        .valid_out  (valid_out)
    );

    // === Clock Generation: 50 MHz ===
    initial begin clk = 0; forever #10 clk = ~clk; end

    // === Output File Capture ===
    integer fd_out, out_count;
    initial out_count = 0;

    always @(posedge clk) begin
        if (valid_out && fd_out != 0) begin
            $fwrite(fd_out, "%h\n", audio_out_l);
            out_count = out_count + 1;
            // Print a few representative output samples
            if (out_count <= 3) begin
                $display("    [Output #%0d] hex=%h  signed=%0d", 
                         out_count, audio_out_l, audio_out_l);
            end
        end
    end

    // === Main Test Sequence ===
    integer i;
    reg [63:0] start_time;

    initial begin
        // Initialize
        rst_n      = 0;
        valid_in   = 0;
        audio_in_l = 0;
        audio_in_r = 0;
        phase_step = PHASE_STEP;

        // Load input samples from hex file
        $readmemh("demo_input.hex", input_mem);

        // Check if file loaded successfully
        if (^input_mem[1] === 1'bx) begin
            $display("");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $display("  ERROR: demo_input.hex not found!");
            $display("  Please run: python plot_demo.py generate");
            $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
            $stop;
        end

        // Open output file
        fd_out = $fopen("demo_output.txt", "w");
        if (fd_out == 0) begin
            $display("ERROR: Cannot create demo_output.txt!");
            $stop;
        end

        // === Print Banner ===
        $display("");
        $display("======================================================");
        $display("  DEMO: CORDIC Voice/Frequency Transformer DSP Core");
        $display("======================================================");
        $display("  Input Signal  : %0d samples, 500 Hz + 1200 Hz", NUM_SAMPLES);
        $display("  Sample Rate   : 48000 Hz");
        $display("  Phase Step    : 0x%06h (~1000 Hz frequency shift)", PHASE_STEP);
        $display("  Expected Out  : DSB sidebands near 200, 500, 1500, 2200 Hz");
        $display("  CORDIC Pipeline: 16 stages, ~18 clock latency");
        $display("  DSP Blocks Used: 0 (pure shift-and-add)");
        $display("======================================================");

        // Release reset
        #200;
        rst_n = 1;
        repeat (10) @(posedge clk);

        // Record start time
        start_time = $time;

        // Print first few input samples
        $display("");
        $display("  --- First Input Samples ---");
        for (i = 0; i < 3; i = i + 1) begin
            $display("    [Input  #%0d] hex=%h", i, input_mem[i]);
        end
        $display("  ...");
        $display("");
        $display("  --- First Output Samples (after pipeline flush) ---");

        // === Feed samples at 48 kHz (1042 sys_clk cycles per sample) ===
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(posedge clk); #1;
            audio_in_l = input_mem[i];
            audio_in_r = input_mem[i];
            valid_in   = 1;
            @(posedge clk); #1;
            valid_in   = 0;
            repeat (1040) @(posedge clk);
        end

        // Stop feeding, wait for pipeline to flush
        audio_in_l = 0;
        audio_in_r = 0;
        repeat (5000) @(posedge clk);

        // Close output file
        $fclose(fd_out);

        // === Print Summary ===
        $display("");
        $display("======================================================");
        $display("  KET QUA MO PHONG (SIMULATION RESULTS)");
        $display("======================================================");
        $display("  Input Samples  : %0d", NUM_SAMPLES);
        $display("  Output Samples : %0d", out_count);
        $display("  Sim Time       : %0t", $time - start_time);
        $display("  Output File    : demo_output.txt");
        $display("======================================================");
        $display("  >> Buoc tiep: python plot_demo.py plot");
        $display("======================================================");
        $display("");
        $display("  *** DEMO COMPLETE ***");
        $display("");
        $finish;
    end

endmodule
