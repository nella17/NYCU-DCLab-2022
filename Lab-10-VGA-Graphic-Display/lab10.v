`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai 
// 
// Create Date: 2018/12/11 16:04:41
// Design Name: 
// Module Name: lab9
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
// 
// Dependencies: vga_sync, clk_divider, sram 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
);
    genvar gi;

    // Declare system variables
    reg  [31:0] fish_clock;
    wire [8:0]  pos;
    wire        fish_region;

    // declare SRAM control signals
    reg  [17:0] sram_addr;
    wire [11:0] data_in;
    wire [11:0] data_out;
    wire        sram_we, sram_en;

    // General VGA control signals
    wire vga_clk;         // 50MHz clock for VGA control
    wire video_on;        // when video_on is 0, the VGA controller is sending
                          // synchronization signals to the display device.
      
    wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                          // based for the new coordinate (pixel_x, pixel_y)
      
    wire [9:0] pixel_x2;   // x coordinate of the next pixel (between 0 ~ 639) 
    wire [9:0] pixel_y2;   // y coordinate of the next pixel (between 0 ~ 479)
    wire [8:0] pixel_x, pixel_y; // 0 ~ 319 / 0 ~ 239
    wire [8:0] pixel_nx, pixel_ny; // 0 ~ 319 / 0 ~ 239

    reg  [11:0] rgb_reg;  // RGB value for the current pixel
    wire  [11:0] rgb_next; // RGB value for the next pixel
      
    // Application-specific VGA signals
    wire  [17:0] pixel_pos, fish_pos;

    localparam BG_PIXEL = 12'h0F0;

    // Declare the video buffer size
    localparam VBUF_W = 320; // video buffer width
    localparam VBUF_H = 240; // video buffer height
    localparam VBUF_SZ = VBUF_W * VBUF_H;

    // Set parameters for the fish images
    localparam FISH_VPOS = 64; // Vertical location of the fish in the sea image.
    localparam FISH_W    = 64; // Width of the fish.
    localparam FISH_H    = 32; // Height of the fish.
    localparam FISH_SZ = FISH_W * FISH_H;
    localparam FISH_CNT = 8;
    reg [17:0] fish_addr[0:FISH_CNT-1];   // Address array for up to 8 fish images.

    reg [11:0] pixel_bg, pixel_fish;

    reg P;

    localparam RAM_SIZE = VBUF_SZ + FISH_SZ * FISH_CNT;

    // Initializes the fish images starting addresses.
    // Note: System Verilog has an easier way to initialize an array,
    //       but we are using Verilog 2001 :(
    generate for(gi = 0; gi < FISH_CNT; gi = gi+1) begin
        initial begin
            fish_addr[gi] = VBUF_SZ + FISH_SZ * gi;
        end
    end endgenerate

    // Instiantiate the VGA sync signal generator
    vga_sync vs0(
        .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
        .visible(video_on), .p_tick(pixel_tick),
        .pixel_x(pixel_x2), .pixel_y(pixel_y2)
    );
    assign pixel_x = pixel_x2[9:1];
    assign pixel_y = pixel_y2[9:1];
    assign pixel_nx = pixel_x != VBUF_W-1 ? pixel_x + 1 : 0;
    assign pixel_ny = pixel_x != VBUF_W-1 ? pixel_y : pixel_y != VBUF_H-1 ? pixel_y + 1 : 0;

    clk_divider#(2) clk_divider0(
        .clk(clk),
        .reset(~reset_n),
        .clk_out(vga_clk)
    );

    // ------------------------------------------------------------------------
    // The following code describes an initialized SRAM memory block that
    // stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
    sram #(
        .DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(RAM_SIZE),
        .INIT_MEM("images.mem")
    ) ram0 (
        .clk(clk), .we(sram_we), .en(sram_en),
        .addr(sram_addr), .data_i(data_in), .data_o(data_out)
    );

    assign sram_we = 0;          // In this demo, we do not write the SRAM. However, if
                                 // you set 'sram_we' to 0, Vivado fails to synthesize
                                 // ram0 as a BRAM -- this is a bug in Vivado.
    assign sram_en = 1;          // Here, we always enable the SRAM block.
    // assign sram_addr = pixel_addr;
    assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
    // End of the SRAM memory block.
    // ------------------------------------------------------------------------

    // VGA color pixel generator
    assign { VGA_RED, VGA_GREEN, VGA_BLUE } = rgb_reg;

    // ------------------------------------------------------------------------
    // An animation clock for the motion of the fish, upper bits of the
    // fish clock is the x position of the fish on the VGA screen.
    // Note that the fish will move one screen pixel every 2^20 clock cycles,
    // or 10.49 msec
    assign pos = fish_clock[28:20]; // the x position of the right edge of the fish image
                                    // in the 640x480 VGA screen
    always @(posedge clk) begin
        if (~reset_n || pos > VBUF_W + FISH_W)
            fish_clock <= 0;
        else
            fish_clock <= fish_clock + 1;
    end
    // End of the animation clock code.
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Video frame buffer address generation unit (AGU) with scaling control
    // Note that the width x height of the fish image is 64x32, when scaled-up
    // on the screen, it becomes 128x64. 'pos' specifies the right edge of the
    // fish image.

    assign pixel_pos = pixel_ny * VBUF_W + pixel_nx;

    assign fish_region =
            FISH_VPOS <= pixel_ny && pixel_ny < (FISH_VPOS + FISH_H) &&
            pixel_nx <= pos && pos < pixel_nx + FISH_W;
    assign fish_pos = fish_addr[fish_clock[25+:$clog2(FISH_CNT)]]
                        + (pixel_ny - FISH_VPOS) * FISH_W
                        + (pixel_nx + FISH_W - pos);

    always @ (posedge clk) begin
        if (~reset_n) begin
            P <= 0;
            sram_addr <= 0;
        end else begin
            case (P)
                0: begin
                    P <= 1;
                    sram_addr <= pixel_pos;
                    pixel_bg <= data_out;
                end
                1: begin
                    P <= 0;
                    sram_addr <= fish_pos;
                    pixel_fish <= fish_region ? data_out : BG_PIXEL;
                end
            endcase
        end
    end
    // End of the AGU code.
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Send the video data in the sram to the VGA controller
    always @(posedge pixel_tick) begin
        rgb_reg <= ~video_on ? 12'h0 : rgb_next;
    end

    assign rgb_next = pixel_fish != BG_PIXEL ? pixel_fish : pixel_bg;
    // End of the video data display code.
    // ------------------------------------------------------------------------

endmodule
