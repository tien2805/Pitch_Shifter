`timescale 1ns / 1ps

module async_fifo #(
    parameter DATA_WIDTH = 48, // 24-bit Left + 24-bit Right
    parameter ADDR_WIDTH = 5   // Depth = 32
)(
    // Write Domain
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,

    // Read Domain
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty
);

    localparam FIFO_DEPTH = (1 << ADDR_WIDTH);
    
    // Internal Memory (Inferred as Distributed RAM or Block RAM)
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    
    // Pointers
    reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;
    
    // Synchronizers (2-FF Sync)
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;
    
    //-----------------------------------------
    // Write Domain Logic
    //-----------------------------------------
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !wr_full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin  <= wr_ptr_bin + 1;
            // Binary to Gray Code Conversion
            wr_ptr_gray <= (wr_ptr_bin + 1) ^ ((wr_ptr_bin + 1) >> 1);
        end
    end
    
    //-----------------------------------------
    // Read Domain Logic
    //-----------------------------------------
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
        end else if (rd_en && !rd_empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1;
            // Binary to Gray Code Conversion
            rd_ptr_gray <= (rd_ptr_bin + 1) ^ ((rd_ptr_bin + 1) >> 1);
        end
    end
    
    // Read Data Output (Combinational out, falls on memory read behavior)
    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    //-----------------------------------------
    // Synchronizers
    //-----------------------------------------
    // Sync Read Pointer to Write Domain
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end
    
    // Sync Write Pointer to Read Domain
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end
    
    //-----------------------------------------
    // Full & Empty Flag Generation
    //-----------------------------------------
    // Full occurs when MSB 2 bits are inverted, and lower bits match 
    // (Write pointer wrapped around once more than read pointer)
    assign wr_full = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], 
                                       rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});
    
    // Empty occurs when pointers are exactly equal
    assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync2);

endmodule
