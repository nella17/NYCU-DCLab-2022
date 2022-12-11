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

    wire [3:0] btn, btn_pressed;
    reg  [3:0] prev_btn;
    generate for(gi = 0; gi < 4; gi = gi+1) begin
        debounce db_btn(.clk(clk), .reset_n(reset_n), .in(usr_btn[gi]), .out(btn[gi]));
    end endgenerate
    always @(posedge clk) begin
        prev_btn <= ~reset_n ? 0 : btn;
    end
    assign btn_pressed = ~prev_btn & btn;

    reg [2:0] mask_cnt = 0;
    wire [11:0] bg_mask = {
        { 4{ mask_cnt[0] } },
        { 4{ mask_cnt[1] } },
        { 4{ mask_cnt[2] } }
    };
    always @ (posedge clk) begin
        if (~reset_n)
            mask_cnt <= 0;
        else
            mask_cnt <= mask_cnt + btn_pressed[0];
    end

    // declare SRAM control signals
    reg  [16:0] sram_addr;
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
    wire [16:0] pixel_pos;

    reg  [11:0] rgb_reg;  // RGB value for the current pixel
    wire [11:0] rgb_next; // RGB value for the next pixel

    // Application-specific VGA signals

    localparam BG_PIXEL = 12'h0F0;
    localparam ZO_PIXEL = 12'h000;

    // Declare the video buffer size
    localparam VBUF_W = 320; // video buffer width
    localparam VBUF_H = 240; // video buffer height
    localparam VBUF_SZ = VBUF_W * VBUF_H;
    localparam VBUF_OF = 0;
    localparam VBUF_ED = VBUF_OF + VBUF_SZ;

    // Set parameters for the fish images
    localparam FRAME_CNT = 8;

    localparam FISHA_W    = 64;
    localparam FISHA_H    = 32;
    localparam FISHA_SZ = FISHA_W * FISHA_H;
    localparam FISHA_OF = VBUF_ED;
    localparam FISHA_ED = FISHA_OF + FISHA_SZ * FRAME_CNT;

    localparam FISHB_W    = 64;
    localparam FISHB_H    = 44;
    localparam FISHB_SZ = FISHB_W * FISHB_H;
    localparam FISHB_OF = FISHA_ED;
    localparam FISHB_ED = FISHB_OF + FISHB_SZ * FRAME_CNT;

    /*
    localparam FISHC_W    = 64;
    localparam FISHC_H    = 72;
    localparam FISHC_SZ = FISHC_W * FISHC_H;
    localparam FISHC_OF = FISHB_ED;
    localparam FISHC_ED = FISHC_OF + FISHC_SZ * FRAME_CNT;
    */

    localparam RAM_SIZE = FISHB_ED;

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

    clk_divider #(2) clk_divider0(
        .clk(clk),
        .reset(~reset_n),
        .clk_out(vga_clk)
    );

    // ------------------------------------------------------------------------
    // The following code describes an initialized SRAM memory block that
    // stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
    sram #(
        .DATA_WIDTH(12), .ADDR_WIDTH(17), .RAM_SIZE(RAM_SIZE),
        .INIT_MEM("images.mem")
    ) ram0 (
        .clk(clk), .we(sram_we), .en(sram_en),
        .addr(sram_addr), .data_i(data_in), .data_o(data_out)
    );

    assign sram_we = 0;          // In this demo, we do not write the SRAM. However, if
                                 // you set 'sram_we' to 0, Vivado fails to synthesize
                                 // ram0 as a BRAM -- this is a bug in Vivado.
    assign sram_en = 1;          // Here, we always enable the SRAM block.
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
    localparam FISH_CNT = 2;

    localparam integer FISH_OF [1:FISH_CNT] = { FISHA_OF, FISHB_OF };
    localparam integer FISH_W  [1:FISH_CNT] = { FISHA_W , FISHB_W  };
    localparam integer FISH_H  [1:FISH_CNT] = { FISHA_H , FISHB_H  };
    reg  [31:0] fish_clock  [1:FISH_CNT];
    wire [8:0]  fish_x      [1:FISH_CNT];
    wire [8:0]  fish_y      [1:FISH_CNT];
    wire        fish_region [1:FISH_CNT];
    wire [16:0] fish_pos    [1:FISH_CNT];

    generate for(gi = 1; gi <= FISH_CNT; gi = gi+1) begin
        fish #(
            .OFFSET(FISH_OF[gi]),
            .W(FISH_W[gi]), .H(FISH_H[gi])
        ) fish (
            .px(pixel_nx), .py(pixel_ny),
            .x(fish_x[gi]), .y(fish_y[gi]),
            .frame(fish_clock[gi][25+:$clog2(FRAME_CNT)]),
            .region(fish_region[gi]), .pos(fish_pos[gi])
        );
    end endgenerate

    assign fish_x[1] = fish_clock[1][28:20];
    assign fish_y[1] = 64;
    always @(posedge clk) begin
        if (~reset_n || fish_x[1] > VBUF_W + FISHA_W)
            fish_clock[1] <= 0;
        else
            fish_clock[1] <= fish_clock[1] + 1;
    end

    assign fish_x[2] = fish_clock[2][28:20];
    assign fish_y[2] = 128;
    always @(posedge clk) begin
        if (~reset_n || fish_x[2] > VBUF_W + FISHA_W)
            fish_clock[2] <= 0;
        else
            fish_clock[2] <= fish_clock[2] + 1;
    end

    // generate for(gi = 3; gi <= FISH_CNT; gi = gi+1) begin
    //     assign fish_x[gi] = fish_clock[gi][28:20];
    //     assign fish_y[gi] = 64;
    //     always @(posedge clk) begin
    //         if (~reset_n || fish_x[gi] > VBUF_W + FISHA_W)
    //             fish_clock[gi] <= 0;
    //         else
    //             fish_clock[gi] <= fish_clock[gi] + 1;
    //     end
    // end endgenerate

    // End of the animation clock code.
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Video frame buffer address generation unit (AGU) with scaling control
    // Note that the width x height of the fish image is 64x32, when scaled-up
    // on the screen, it becomes 128x64. 'pos' specifies the right edge of the
    // fish image.

    reg [11:0] pixel_bg, pixel_fish[1:FISH_CNT];
    assign pixel_pos = pixel_ny * VBUF_W + pixel_nx;

    reg [$clog2(FISH_CNT):0] P = 0;

    wire [1:2] match;
    generate for(gi = 1; gi <= FISH_CNT; gi = gi+1) begin
        assign match[gi] = P <= gi && fish_region[gi];
    end endgenerate

    reg [1:2] match_prev;
    always_ff @(negedge clk)
        match_prev <= match;

    always_ff @(posedge clk) begin
        if (0)
            ;
        else if (match[1])
            P <= 2;
        else if (match[2])
            P <= 3;
        else
            P <= 1;
    end

    always_ff @(posedge clk) begin
        if (0)
            ;
        else if (match[1])
            sram_addr <= fish_pos[1];
        else if (match[2])
            sram_addr <= fish_pos[2];
        else
            sram_addr <= pixel_pos;
    end

    always_ff @(negedge clk) begin
        if (~|(match))
            pixel_bg <= data_out;
    end

    generate for(gi = 1; gi <= FISH_CNT; gi = gi+1) begin
        always_ff @(negedge clk) begin
            if (match[gi])
                pixel_fish[gi] <= data_out;
            else if (~fish_region[gi])
                pixel_fish[gi] <= BG_PIXEL;
        end
    end endgenerate

    // End of the AGU code.
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Send the video data in the sram to the VGA controller
    always_ff @(posedge pixel_tick)
        rgb_reg <= ~video_on ? 12'h0 : rgb_next;

    assign rgb_next =
        // pixel_fish[4] == ZO_PIXEL ? pixel_fish[4] :
        // pixel_fish[3] == ZO_PIXEL ? pixel_fish[3] :
        pixel_fish[2] != BG_PIXEL ? pixel_fish[2] :
        pixel_fish[1] != BG_PIXEL ? pixel_fish[1] :
                (pixel_bg ^ bg_mask);
    // End of the video data display code.
    // ------------------------------------------------------------------------

endmodule

module fish #(
    parameter OFFSET = 0,
    parameter integer W = 0, H = 0, CNT = 8
)(
    input [8:0] px, py,
    input [8:0] x, y,
    input [$clog2(CNT)-1:0] frame,
    output region,
    output [16:0] pos
);
    assign region = y <= py + H && py < y && x <= px + W && px < x;
    assign pos = OFFSET + W * H * frame + (py + H - y) * W + (px + W - x);
endmodule
