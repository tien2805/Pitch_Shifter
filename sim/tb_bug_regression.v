`timescale 1ns / 1ps

module tb_bug_regression;
    reg clk;
    reg rst_n;

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    integer errors;

    // ------------------------------------------------------------
    // CORDIC signed-quadrant regression
    // ------------------------------------------------------------
    reg signed [23:0] cordic_x_in;
    reg signed [23:0] cordic_y_in;
    reg signed [23:0] cordic_phase;
    reg               cordic_valid;
    wire signed [23:0] cordic_x_out;
    wire signed [23:0] cordic_y_out;
    wire               cordic_valid_out;

    cordic_core u_cordic (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (cordic_valid),
        .x_in      (cordic_x_in),
        .y_in      (cordic_y_in),
        .phase_in  (cordic_phase),
        .x_out     (cordic_x_out),
        .y_out     (cordic_y_out),
        .valid_out (cordic_valid_out)
    );

    task run_cordic_case;
        input signed [23:0] phase;
        input expect_x_negative;
        input expect_y_negative;
        integer wait_count;
        begin
            @(posedge clk);
            cordic_x_in  <= 24'sd607253;
            cordic_y_in  <= 24'sd0;
            cordic_phase <= phase;
            cordic_valid <= 1'b1;
            @(posedge clk);
            cordic_valid <= 1'b0;

            wait_count = 0;
            while (!cordic_valid_out && wait_count < 40) begin
                @(posedge clk);
                wait_count = wait_count + 1;
            end

            if (!cordic_valid_out) begin
                $display("ERROR: CORDIC valid_out timeout");
                errors = errors + 1;
            end else begin
                if (expect_x_negative && cordic_x_out >= 0) begin
                    $display("ERROR: CORDIC x sign wrong for phase %h, x=%0d", phase, cordic_x_out);
                    errors = errors + 1;
                end
                if (!expect_x_negative && cordic_x_out < 0) begin
                    $display("ERROR: CORDIC x sign wrong for phase %h, x=%0d", phase, cordic_x_out);
                    errors = errors + 1;
                end
                if (expect_y_negative && cordic_y_out >= 0) begin
                    $display("ERROR: CORDIC y sign wrong for phase %h, y=%0d", phase, cordic_y_out);
                    errors = errors + 1;
                end
                if (!expect_y_negative && cordic_y_out < 0) begin
                    $display("ERROR: CORDIC y sign wrong for phase %h, y=%0d", phase, cordic_y_out);
                    errors = errors + 1;
                end
            end
        end
    endtask

    // ------------------------------------------------------------
    // DC remover feedback regression
    // ------------------------------------------------------------
    reg signed [23:0] dc_data_in;
    reg               dc_en;
    wire signed [23:0] dc_data_out;

    dc_remover u_dc (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (dc_en),
        .data_in  (dc_data_in),
        .data_out (dc_data_out)
    );

    initial begin
        errors       = 0;
        rst_n        = 1'b0;
        cordic_x_in  = 24'sd0;
        cordic_y_in  = 24'sd0;
        cordic_phase = 24'sd0;
        cordic_valid = 1'b0;
        dc_data_in   = 24'sd0;
        dc_en        = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // +135 degrees: x negative, y positive.
        run_cordic_case(24'sh600000, 1'b1, 1'b0);

        // -135 degrees: x negative, y negative. This catches unsigned
        // comparisons that misclassify negative phases as large positives.
        run_cordic_case(-24'sh600000, 1'b1, 1'b1);

        // Constant DC input should decay by R=255/256 on the second sample:
        // y1=1000, y2=996. The old feedback bug produced y2=0.
        @(posedge clk);
        dc_data_in <= 24'sd1000;
        dc_en      <= 1'b1;
        @(posedge clk);
        dc_en      <= 1'b0;
        #1;
        if (dc_data_out !== 24'sd1000) begin
            $display("ERROR: DC remover first output expected 1000, got %0d", dc_data_out);
            errors = errors + 1;
        end

        @(posedge clk);
        dc_en <= 1'b1;
        @(posedge clk);
        dc_en <= 1'b0;
        #1;
        if (dc_data_out !== 24'sd997) begin
            $display("ERROR: DC remover second output expected 997, got %0d", dc_data_out);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("BUG_REGRESSION_PASS");
        end else begin
            $display("BUG_REGRESSION_FAIL errors=%0d", errors);
            $stop;
        end
        $finish;
    end
endmodule
