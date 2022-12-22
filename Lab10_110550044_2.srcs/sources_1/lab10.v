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
    input  [3:0] usr_sw,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] fish_clock, fish_clock2, fish_clock3;
wire [9:0]  pos, pos2, pos3;
wire        fish_region, fish_region1, fish_region2;

// declare SRAM control signals
wire [16:0] sram_addr;
wire [16:0] sram_addr2;
wire [16:0] sram_addr3;
wire [16:0] sram_addr4;
wire [11:0] data_in;
wire [11:0] data_out;
wire [11:0] data_out2;
wire [11:0] data_out3;
wire [11:0] data_out4;

wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr;
reg  [17:0] pixel_addr2;
reg  [17:0] pixel_addr3;
reg  [17:0] pixel_addr4;
// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
reg [8:0] FISH_VPOS   = 64; // Vertical location of the fish in the sea image.
reg [8:0] FISH_VPOS2   = 64 + 44*2;
reg [8:0] FISH_VPOS3   = 44;
localparam FISH_W      = 64; // Width of the fish.
localparam FISH_H      = 32; // Height of the fish.
localparam FISH_W2     = 64; // Width of the fish.
localparam FISH_H2     = 44; // Height of the fish.
reg [17:0] fish_addr[0:7];   // Address array for up to 8 fish images.
reg [17:0] fish_addr1[0:7];   // Address array for up to 8 fish images.
reg [17:0] fish_addr2[0:7];

wire usr_btn_debounced[0:3];
reg [1:0]choose;

// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
  fish_addr[0] = 18'd0;         /* Addr for fish image #1 */
  fish_addr[1] = FISH_W*FISH_H; /* Addr for fish image #2 */
  fish_addr[2] = FISH_W*FISH_H*2;
  fish_addr[3] = FISH_W*FISH_H*3;
  fish_addr[4] = FISH_W*FISH_H*4;
  fish_addr[5] = FISH_W*FISH_H*5;
  fish_addr[6] = FISH_W*FISH_H*6;
  fish_addr[7] = FISH_W*FISH_H*7;
  fish_addr1[0] = 18'd0;         /* Addr for fish image #1 */
  fish_addr1[1] = FISH_W2*FISH_H2; /* Addr for fish image #2 */
  fish_addr1[2] = FISH_W2*FISH_H2*2;
  fish_addr1[3] = FISH_W2*FISH_H2*3;
  fish_addr1[4] = FISH_W2*FISH_H2*4;
  fish_addr1[5] = FISH_W2*FISH_H2*5;
  fish_addr1[6] = FISH_W2*FISH_H2*6;
  fish_addr1[7] = FISH_W2*FISH_H2*7;
  fish_addr2[0] = 18'd0;         /* Addr for fish image #1 */
  fish_addr2[1] = FISH_W2*FISH_H2; /* Addr for fish image #2 */
  fish_addr2[2] = FISH_W2*FISH_H2*2;
  fish_addr2[3] = FISH_W2*FISH_H2*3;
  fish_addr2[4] = FISH_W2*FISH_H2*4;
  fish_addr2[5] = FISH_W2*FISH_H2*5;
  fish_addr2[6] = FISH_W2*FISH_H2*6;
  fish_addr2[7] = FISH_W2*FISH_H2*7;
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));
sram1 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W*FISH_H*8))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr2), .data_i(data_in), .data_o(data_out2));
sram2 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W2*FISH_H2*8))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr3), .data_i(data_in), .data_o(data_out3));
sram3 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W2*FISH_H2*8))
  ram3 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr4), .data_i(data_in), .data_o(data_out4));
debounce db0(.clock(clk), .btn_p(usr_btn[0]), .debounced_dn(usr_btn_debounced[0]));
debounce db1(.clock(clk), .btn_p(usr_btn[1]), .debounced_dn(usr_btn_debounced[1]));
debounce db2(.clock(clk), .btn_p(usr_btn[2]), .debounced_dn(usr_btn_debounced[2]));
debounce db3(.clock(clk), .btn_p(usr_btn[3]), .debounced_dn(usr_btn_debounced[3]));
assign sram_we = usr_sw[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign sram_addr2 = pixel_addr2;
assign sram_addr3 = pixel_addr3;
assign sram_addr4 = pixel_addr4;

assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
reg [20:0] cnt[0:3];
reg run = 0, stop = 0;
reg rev[0:3];

always @(posedge clk) begin
  if (~reset_n) begin
    choose <= 0;
  end
  else if(usr_btn_debounced[3]) begin
    choose <= choose + 1;
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    stop <= 0;
  end
  else if(usr_btn_debounced[2]) begin
    stop <= ~stop;
  end
end

always @(posedge clk) begin
  if (~reset_n || cnt[0] >= 12'heff) begin
    cnt[0] <= 0;
  end
  else if(usr_btn_debounced[0]) begin
    cnt[0] <= cnt[0] + 50;
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    cnt[1] <= 0;
    cnt[2] <= 0;
    cnt[3] <= 0; 
    run <= 0;
    rev[0] <= 0;
    rev[1] <= 0;
    rev[2] <= 0;
  end  else if(usr_btn_debounced[1]) begin
    run <= ~run;
  end 
  
  if(run) begin
      if((choose == 0 || choose == 3)&& cnt[1] == 500000) begin
          if(FISH_VPOS > VBUF_H - FISH_H || FISH_VPOS == 0) rev[0] = ~rev[0];
          if(rev[0]) FISH_VPOS <= FISH_VPOS - 1;
          else FISH_VPOS <= FISH_VPOS + 1;
          cnt[1] <= 0;
      end else if((choose == 1 || choose == 3)&& cnt[2] == 750000) begin
          if(FISH_VPOS2 > VBUF_H - FISH_H2 || FISH_VPOS2 == 0) rev[1] = ~rev[1];
          if(rev[1]) FISH_VPOS2 <= FISH_VPOS2 - 1;
          else FISH_VPOS2 <= FISH_VPOS2 + 1;
          cnt[2] <= 0;
      end  else if((choose ==2 || choose == 3)&& cnt[3] == 850000) begin
          if(FISH_VPOS3 > VBUF_H - FISH_H2 || FISH_VPOS3 == 0) rev[2] = ~rev[2];
          if(rev[2]) FISH_VPOS3 <= FISH_VPOS3 - 1;
          else FISH_VPOS3 <= FISH_VPOS3 + 1;
          cnt[3] <= 0;
      end else begin
          cnt[1] <= cnt[1] + 1;
          cnt[2] <= cnt[2] + 1;
          cnt[3] <= cnt[3] + 1;   
    end
  end
end
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
assign pos = fish_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
assign pos2 = fish_clock2[31:19];            

assign pos3 = fish_clock3[31:19] - FISH_W; 
                    
always @(posedge clk) begin
      if(~reset_n || fish_clock[31:21] > VBUF_W + FISH_W) begin
        fish_clock <= 0;
      end  else if(stop && (choose == 0 || choose == 3)) begin
        fish_clock <= fish_clock;
      end else begin
        fish_clock <= fish_clock + 1;
      end
end

always @(posedge clk) begin
      if (~reset_n || fish_clock2[31:20] > VBUF_W + FISH_W) begin
        fish_clock2 <= 0;
      end  else if(stop && (choose == 1 || choose == 3)) begin
        fish_clock2 <= fish_clock2;
      end else begin
        fish_clock2 <= fish_clock2 + 1;
      end
end

always @(posedge clk) begin
  if (~reset_n || fish_clock3[31:20] == 0) begin
    fish_clock3[31:20] <= VBUF_W + FISH_W;
  end  else if(stop && (choose == 2 || choose == 3)) begin
        fish_clock3 <= fish_clock3;
      end else begin
    fish_clock3 <= fish_clock3 - 1;
  end
end

// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign fish_region =
           pixel_y >= ((FISH_VPOS)<<1) && pixel_y < (FISH_VPOS+FISH_H)<<1 &&
           (pixel_x + 127) >= pos && pixel_x < pos + 1;
assign fish_region1 =
           pixel_y >= ((FISH_VPOS2)<<1) && pixel_y < (FISH_VPOS2 + FISH_H2)<<1 &&
           (pixel_x + 127) >= pos2  && pixel_x < pos2 + 1;
assign fish_region2 =
           pixel_y >= ((FISH_VPOS3)<<1) && pixel_y < (FISH_VPOS3 + FISH_H2)<<1 &&
           (pixel_x + 127) >= pos3  && pixel_x < pos3 + 1;

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
    pixel_addr2 <= 0;
    pixel_addr3 <= 0;
    pixel_addr4 <= 0;
  end
  else begin
    pixel_addr4 <= fish_addr2[fish_clock[25:23]] +
                  ((pixel_y>>1)-(FISH_VPOS3))*FISH_W2 +
                  ((pixel_x +(FISH_W2*2-1)-pos3)>>1);
    pixel_addr3 <= fish_addr1[fish_clock[25:23]] +
                  ((pixel_y>>1)-(FISH_VPOS2))*FISH_W2 +
                  ((pixel_x +(FISH_W2*2-1)-pos2)>>1);
    pixel_addr2 <= fish_addr[fish_clock[25:23]] +
                  ((pixel_y>>1)-FISH_VPOS)*FISH_W +
                  ((pixel_x +(FISH_W*2-1)-pos)>>1);
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
  end
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else if(fish_region && data_out2 != 12'h0f0) 
    rgb_next = data_out2;
  else if(fish_region1 && data_out3 != 12'h0f0) 
    rgb_next = data_out3;
  else if(fish_region2 && data_out4 != 12'h0f0) 
    rgb_next = data_out4;
  else
    rgb_next = data_out ^ cnt[0]; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
module debounce(
    input clock,
    input btn_p,
    output debounced_dn
    );

    // sync with clock and combat metastability
    reg state;
    reg [3:0] shifter;
    always @(posedge clock) 
    begin
        shifter = {shifter[2:0], btn_p};
    end

    // 2.6 ms counter at 100 MHz
    reg [18:0] counter;

    always @(posedge clock)
    begin
        if (state == shifter[3])
            counter <= 0;
        else
        begin
            counter <= counter + 1;
            if (&counter)
                state <= ~state;
        end
    end

    assign debounced_dn = ~(state == shifter[3]) & (&counter) & ~state;
    
endmodule