`timescale 1ns / 1ps

module pitch_shift_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    
    // Interface from RX FIFO (SYS domain)
    input  wire signed [23:0] audio_in_l,
    input  wire signed [23:0] audio_in_r,
    input  wire        valid_in,     // Pulse when new sample is ready
    
    // Control inputs
    input  wire signed [23:0] phase_step, // Frequency shift amount

    // Interface to TX FIFO
    output wire signed [23:0] audio_out_l,
    output wire signed [23:0] audio_out_r,
    output wire        valid_out
);

    // DC Remover
    wire signed [23:0] dc_clean_l;
    dc_remover u_dc_rem_l (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (valid_in),
        .data_in  (audio_in_l),
        .data_out (dc_clean_l)
    );

    wire signed [23:0] dc_clean_r;
    dc_remover u_dc_rem_r (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (valid_in),
        .data_in  (audio_in_r),
        .data_out (dc_clean_r)
    );

    // Phase Accumulator
    wire signed [23:0] current_phase;
    phase_accumulator u_phase_acc (
        .clk        (clk),
        .rst_n      (rst_n),
        .en         (valid_in),
        .phase_step (phase_step),
        .phase_out  (current_phase)
    );

    // DC remover and phase accumulator both register their outputs. Delay the
    // sample-valid pulse by one cycle so CORDIC samples the matching data/phase.
    reg valid_to_cordic;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_to_cordic <= 1'b0;
        end else begin
            valid_to_cordic <= valid_in;
        end
    end

    // Pre-scale the input audio by K factor before entering CORDIC.
    // K approx 0.60725; this shift-add version is 0.607421875.
    wire signed [23:0] scaled_audio_l = (dc_clean_l >>> 1) + (dc_clean_l >>> 3) - (dc_clean_l >>> 6) - (dc_clean_l >>> 9);
    wire signed [23:0] scaled_audio_r = (dc_clean_r >>> 1) + (dc_clean_r >>> 3) - (dc_clean_r >>> 6) - (dc_clean_r >>> 9);

    // CORDIC Core for SSB Modulation (Left Channel)
    wire signed [23:0] cordic_x_out_l;
    wire signed [23:0] cordic_y_out_l;
    wire valid_out_l;
    
    cordic_core u_cordic_l (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_to_cordic),
        .x_in      (scaled_audio_l),
        .y_in      (24'd0),
        .phase_in  (current_phase),
        .x_out     (cordic_x_out_l),
        .y_out     (cordic_y_out_l),
        .valid_out (valid_out_l)
    );

    // CORDIC Core for SSB Modulation (Right Channel)
    wire signed [23:0] cordic_x_out_r;
    wire signed [23:0] cordic_y_out_r;
    wire valid_out_r;

    cordic_core u_cordic_r (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_to_cordic),
        .x_in      (scaled_audio_r),
        .y_in      (24'd0),
        .phase_in  (current_phase),
        .x_out     (cordic_x_out_r),
        .y_out     (cordic_y_out_r),
        .valid_out (valid_out_r)
    );

    // The output audio is the rotated X component. With y_in=0 this is a
    // multiplier-less frequency/robot effect (audio * cos(theta)).
    assign audio_out_l = cordic_x_out_l;
    assign audio_out_r = cordic_x_out_r;
    assign valid_out   = valid_out_l; // Both valid outputs are identical in timing

endmodule
