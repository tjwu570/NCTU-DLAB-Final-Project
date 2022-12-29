`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National YangMing ChiaoTung Chiao Tung University
// Engineer: Chinlin-Wu
// 
// Create Date: 2022/12/23
// Design Name: Snake
// Module Name: Snake
// Project Name: Final Project 
// Target Devices: Arty
// Tool Versions: 
// Description: A circuit for user to experience the old game, snake.
// 
// Dependencies: vga_sync, clk_divider, sram
// 
// 
//////////////////////////////////////////////////////////////////////////////////

module final(
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
//reg  [31:0] fish_clock;
//wire [9:0]  pos;
//wire        fish_region;

// declare SRAM control signals
wire  background_is_black;
wire [11:0] data_in;
wire [11:0] data_out;
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
reg  background_is_black_reg = 0;
reg this_pos_is_food;
reg this_pos_is_block;
reg this_pos_is_snake;
reg this_pos_is_snake_head;
wire food, snake, block, snake_head;
reg [5:0] current_pos_x = 0;
reg [5:0] current_pos_y = 0;
reg [3:0] b_x;
reg [3:0] b_y;

reg [5:0] food_pos_x [0:9];
reg [5:0] food_pos_y [0:9];
reg [3:0] snake_length = 5;
reg [5:0] snake_pos_x[0:9];
reg [5:0] snake_pos_y[0:9];
reg [7:0]block_amount = 6;
reg [5:0] block_pos_x [0:100];
reg [5:0] block_pos_y [0:100];

wire snake_speed;
reg food_appear[0:9];
reg snake_appear[0:9];

reg [31:0] snake_clock;
reg [31:0] food_clock;
reg [31:0] hit_wall_timer;
wire up_block, down_block, right_block, left_block, front_block;
reg food_size;
wire [1:0] btn_level [3:0];
reg [1:0] btn_pressed [3:0];
reg  [1:0] prev_btn_level[3:0];
wire bump;
wire hit_up_wall,hit_down_wall,hit_left_wall,hit_right_wall,hit_wall;
wire eat;
reg red;
wire zero;
integer i;
// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

localparam Block_size = 5;
localparam Block_width = 48;
localparam Block_amount = Block_width * Block_width;
//end

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

debounce btn_db0(.clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_level[0]));
debounce btn_db1(.clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_level[1]));
debounce btn_db2(.clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_level[2]));
debounce btn_db3(.clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_level[3]));

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
/*sram_background 
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .is_black(background_is_black), .color_change(usr_sw[0]), .data_i(data_in), .data_o(data_out),
           .is_food(this_pos_is_food), .is_snake(this_pos_is_snake), .is_snake_head(this_pos_is_snake_head),
           .is_bumped(red), 
            .is_block(this_pos_is_block), .block_transparent(usr_sw[1]));*/
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(461700))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .x(pixel_x), .y(pixel_y), .data_i(data_in), .data_o(data_out), .b_x(b_x), .b_y(b_y),
          .is_black(background_is_black), .color_change(usr_sw[0]),
          .is_food(this_pos_is_food), .food_small(food_size),
          .is_snake(this_pos_is_snake), .is_snake_head(this_pos_is_snake_head), .is_bumped(red), 
          .is_block(this_pos_is_block), .block_transparent(usr_sw[1]));
assign sram_we = zero; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign background_is_black = background_is_black_reg;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

//
// Enable one cycle of btn_pressed per each button hit
always @(posedge clk or negedge reset_n) begin
  if (~reset_n) for (i=0;i<4;i=i+1) prev_btn_level[i] <= 2'b00;
  else for (i=0;i<4;i=i+1) prev_btn_level[i] <= btn_level[i];
end

always @(*) begin
    for (i=0;i<4;i=i+1) btn_pressed[i] = (btn_level[i] & ~prev_btn_level[i]);
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////initialize
always@(posedge clk) begin
    b_x <= pixel_x - (current_pos_x * 10);
    b_y <= pixel_y - (current_pos_y * 10);
end
always@(posedge clk) begin
    if(~reset_n) begin
        food_pos_x[0] <= 6'd17; food_pos_y[0] <= 6'd11;
        food_pos_x[1] <= 6'd22; food_pos_y[1] <= 6'd2;
        food_pos_x[2] <= 6'd32; food_pos_y[2] <= 6'd23;
        food_pos_x[3] <= 6'd40; food_pos_y[3] <= 6'd14;
        food_pos_x[4] <= 6'd15; food_pos_y[4] <= 6'd5;
        food_pos_x[5] <= 6'd36; food_pos_y[5] <= 6'd36;
        food_pos_x[6] <= 6'd47; food_pos_y[6] <= 6'd7;
        food_pos_x[7] <= 6'd28; food_pos_y[7] <= 6'd18;
        food_pos_x[8] <= 6'd29; food_pos_y[8] <= 6'd9;
        food_pos_x[9] <= 6'd10; food_pos_y[9] <= 6'd10;
    end
end

always@(posedge clk) begin
    block_pos_x[0] <= 6'd3; block_pos_y[0] <= 6'd1;
    block_pos_x[1] <= 6'd3; block_pos_y[1] <= 6'd2;
    block_pos_x[2] <= 6'd3; block_pos_y[2] <= 6'd3;
    block_pos_x[3] <= 6'd3; block_pos_y[3] <= 6'd4;
    block_pos_x[4] <= 6'd3; block_pos_y[4] <= 6'd5;
    block_pos_x[5] <= 6'd3; block_pos_y[5] <= 6'd6;
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////snake bump
assign up_block = ((snake_pos_x[0] == block_pos_x[0]) && (snake_pos_y[0]-1 == block_pos_y[0])) |
                  ((snake_pos_x[0] == block_pos_x[1]) && (snake_pos_y[0]-1 == block_pos_y[1])) |
                  ((snake_pos_x[0] == block_pos_x[2]) && (snake_pos_y[0]-1 == block_pos_y[2])) |
                  ((snake_pos_x[0] == block_pos_x[3]) && (snake_pos_y[0]-1 == block_pos_y[3])) |
                  ((snake_pos_x[0] == block_pos_x[4]) && (snake_pos_y[0]-1 == block_pos_y[4])) |
                  ((snake_pos_x[0] == block_pos_x[5]) && (snake_pos_y[0]-1 == block_pos_y[5]));

assign down_block = ((snake_pos_x[0] == block_pos_x[0]) && (snake_pos_y[0]+1 == block_pos_y[0])) |
                    ((snake_pos_x[0] == block_pos_x[1]) && (snake_pos_y[0]+1 == block_pos_y[1])) |
                    ((snake_pos_x[0] == block_pos_x[2]) && (snake_pos_y[0]+1 == block_pos_y[2])) |
                    ((snake_pos_x[0] == block_pos_x[3]) && (snake_pos_y[0]+1 == block_pos_y[3])) |
                    ((snake_pos_x[0] == block_pos_x[4]) && (snake_pos_y[0]+1 == block_pos_y[4])) |
                    ((snake_pos_x[0] == block_pos_x[5]) && (snake_pos_y[0]+1 == block_pos_y[5]));

assign left_block = ((snake_pos_x[0]-1 == block_pos_x[0]) && (snake_pos_y[0] == block_pos_y[0])) |
                    ((snake_pos_x[0]-1 == block_pos_x[1]) && (snake_pos_y[0] == block_pos_y[1])) |
                    ((snake_pos_x[0]-1 == block_pos_x[2]) && (snake_pos_y[0] == block_pos_y[2])) |
                    ((snake_pos_x[0]-1 == block_pos_x[3]) && (snake_pos_y[0] == block_pos_y[3])) |
                    ((snake_pos_x[0]-1 == block_pos_x[4]) && (snake_pos_y[0] == block_pos_y[4])) |
                    ((snake_pos_x[0]-1 == block_pos_x[5]) && (snake_pos_y[0] == block_pos_y[5]));

assign right_block = ((snake_pos_x[0]+1 == block_pos_x[0]) && (snake_pos_y[0] == block_pos_y[0])) |
                     ((snake_pos_x[0]+1 == block_pos_x[1]) && (snake_pos_y[0] == block_pos_y[1])) |
                     ((snake_pos_x[0]+1 == block_pos_x[2]) && (snake_pos_y[0] == block_pos_y[2])) |
                     ((snake_pos_x[0]+1 == block_pos_x[3]) && (snake_pos_y[0] == block_pos_y[3])) |
                     ((snake_pos_x[0]+1 == block_pos_x[4]) && (snake_pos_y[0] == block_pos_y[4])) |
                     ((snake_pos_x[0]+1 == block_pos_x[5]) && (snake_pos_y[0] == block_pos_y[5]));

assign front_block = ((snake_pos_x[0]+(snake_pos_x[0]-snake_pos_x[1]) == block_pos_x[0]) && (snake_pos_y[0]+(snake_pos_y[0]-snake_pos_y[1]) == block_pos_y[0])) |
                     ((snake_pos_x[0]+(snake_pos_x[0]-snake_pos_x[1]) == block_pos_x[1]) && (snake_pos_y[0]+(snake_pos_y[0]-snake_pos_y[1]) == block_pos_y[1])) |
                     ((snake_pos_x[0]+(snake_pos_x[0]-snake_pos_x[1]) == block_pos_x[2]) && (snake_pos_y[0]+(snake_pos_y[0]-snake_pos_y[1]) == block_pos_y[2])) |
                     ((snake_pos_x[0]+(snake_pos_x[0]-snake_pos_x[1]) == block_pos_x[3]) && (snake_pos_y[0]+(snake_pos_y[0]-snake_pos_y[1]) == block_pos_y[3])) |
                     ((snake_pos_x[0]+(snake_pos_x[0]-snake_pos_x[1]) == block_pos_x[4]) && (snake_pos_y[0]+(snake_pos_y[0]-snake_pos_y[1]) == block_pos_y[4])) |
                     ((snake_pos_x[0]+(snake_pos_x[0]-snake_pos_x[1]) == block_pos_x[5]) && (snake_pos_y[0]+(snake_pos_y[0]-snake_pos_y[1]) == block_pos_y[5]));
                     
assign hit_left_wall = (snake_pos_x[0]==0); 
assign hit_right_wall = (snake_pos_x[0]==47); 
assign hit_up_wall = (snake_pos_y[0]==0); 
assign hit_down_wall = (snake_pos_y[0]==47);
assign hit_wall = (snake_pos_x[0]==0 && snake_pos_x[1]==1) | (snake_pos_x[0]==47 && snake_pos_x[1]==46) | (snake_pos_y[0]==0 && snake_pos_y[1]==1) | (snake_pos_y[0]==47 && snake_pos_y[1]==46);
                     
always @(posedge clk) begin
  if (~reset_n || bump) snake_clock <= 0;
  else if (snake_speed && snake_clock >= 30000000) snake_clock <= 0;
  else if (!snake_speed && snake_clock >= 100000000) snake_clock <= 0;
  else snake_clock <= snake_clock + 1;
end

assign snake_speed = usr_sw[2];

assign bump = (btn_pressed[0] && (right_block | hit_right_wall)) | 
              (btn_pressed[1] && (left_block | hit_left_wall)) | 
              (btn_pressed[2] && (up_block | hit_up_wall)) | 
              (btn_pressed[3] && (down_block | hit_down_wall)); // if we want to count score, we need to add the snake clock count like (bump  && snake_count == 100000000) 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////snake move
always @(posedge clk or negedge reset_n) begin
    if (~reset_n) red <= 0;
    else begin
        if (bump) red <= 1;
        else if(hit_wall | front_block) begin
            if(hit_wall_timer == 100000000) begin
                hit_wall_timer <= 0;
                red <= 1;
            end
            else hit_wall_timer <= hit_wall_timer + 1;
        end
        else if (snake_clock == 100000000) red<= 0;
        else red <= red;
    end
end

always@(posedge clk) begin
    if(~reset_n) begin
        snake_appear[0] <= 1;
        snake_appear[1] <= 1;
        snake_appear[2] <= 1;
        snake_appear[3] <= 1;
        snake_appear[4] <= 1;
        snake_appear[5] <= 0;
        snake_appear[6] <= 0;
        snake_appear[7] <= 0;
        snake_appear[8] <= 0;
        snake_appear[9] <= 0;
    end
    else begin
        if(eat)begin
            snake_appear[snake_length] = 1;
            if (snake_length<=8) 
                snake_length = snake_length + 1;
        end
    end
end
always @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
        snake_pos_x[0] <= 6'd20; snake_pos_y[0] <= 6'd40;
        snake_pos_x[1] <= 6'd21; snake_pos_y[1] <= 6'd40;
        snake_pos_x[2] <= 6'd22; snake_pos_y[2] <= 6'd40;
        snake_pos_x[3] <= 6'd23; snake_pos_y[3] <= 6'd40;
        snake_pos_x[4] <= 6'd24; snake_pos_y[4] <= 6'd40;
        snake_pos_x[5] <= 6'd25; snake_pos_y[5] <= 6'd40;
        snake_pos_x[6] <= 6'd26; snake_pos_y[6] <= 6'd40;
        snake_pos_x[7] <= 6'd27; snake_pos_y[7] <= 6'd40;
        snake_pos_x[8] <= 6'd28; snake_pos_y[8] <= 6'd40;
        snake_pos_x[9] <= 6'd29; snake_pos_y[9] <= 6'd40; // 開始會有左上角那一格
    end
    else begin
        // going right 
        if (btn_pressed[0] && snake_pos_x[0] >= snake_pos_x[1] && !right_block && !hit_right_wall) begin // if we want to change color while bumping into wall, add a if else statement below (if (right_block...))
            
            snake_pos_y[0] <= snake_pos_y[0];
            snake_pos_x[0] <= snake_pos_x[0]+1;
            for (i=1;i<10;i=i+1) begin
                snake_pos_x[i] <= snake_pos_x[i-1];
                snake_pos_y[i] <= snake_pos_y[i-1];
            end
        end
        // going left
        else if (btn_pressed[1] && snake_pos_x[0] <= snake_pos_x[1] && !left_block && !hit_left_wall) begin
            snake_pos_y[0] <= snake_pos_y[0];
            snake_pos_x[0] <= snake_pos_x[0]-1;
            for (i=1;i<10;i=i+1) begin
                snake_pos_x[i] <= snake_pos_x[i-1];
                snake_pos_y[i] <= snake_pos_y[i-1];
            end
        end
        // going up
        else if (btn_pressed[2] && snake_pos_y[0] <= snake_pos_y[1] && !up_block && !hit_up_wall) begin
            snake_pos_y[0] <= snake_pos_y[0]-1;
            snake_pos_x[0] <= snake_pos_x[0];
            for (i=1;i<10;i=i+1) begin
                snake_pos_x[i] <= snake_pos_x[i-1];
                snake_pos_y[i] <= snake_pos_y[i-1];
            end
        end
        // going down
        else if (btn_pressed[3] && snake_pos_y[0] >= snake_pos_y[1] && !down_block && !hit_down_wall) begin
            snake_pos_y[0] <= snake_pos_y[0]+1;
            snake_pos_x[0] <= snake_pos_x[0];
            for (i=1;i<10;i=i+1) begin
                snake_pos_x[i] <= snake_pos_x[i-1];
                snake_pos_y[i] <= snake_pos_y[i-1];
            end
        end
        // going in the original direction, if no button pressed
        else if (snake_clock == 0 && !front_block && !hit_wall)  begin
            snake_pos_x[0] <= snake_pos_x[0] + (snake_pos_x[0]-snake_pos_x[1]);
            snake_pos_y[0] <= snake_pos_y[0] + (snake_pos_y[0]-snake_pos_y[1]);
            for (i=1;i<10;i=i+1) begin
                snake_pos_x[i] <= snake_pos_x[i-1];
                snake_pos_y[i] <= snake_pos_y[i-1];
            end
        end
    end
end
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////food eat
assign eat = (snake_head && food);

always@(posedge clk) begin
    if(~reset_n) begin
        for(i=0;i<10;i=i+1) food_appear[i] <= 1;
    end
    else if(eat) begin
        for(i=0;i<10;i=i+1) begin
            if((snake_pos_x[0] == food_pos_x[i]) && (snake_pos_y[0] == food_pos_y[i])) begin
                food_appear[i] <= 0;
            end
        end
    end
end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////draw
always@(posedge clk) begin
    if(~reset_n) begin
        current_pos_x <= 0;
        current_pos_y <= 0;
    end
    else begin
        current_pos_x <= pixel_x / 10;
        current_pos_y <= pixel_y / 10;
    end
end

assign food = ((current_pos_x == food_pos_x[0]) && (current_pos_y == food_pos_y[0]) && food_appear[0]) |
              ((current_pos_x == food_pos_x[1]) && (current_pos_y == food_pos_y[1]) && food_appear[1]) | 
              ((current_pos_x == food_pos_x[2]) && (current_pos_y == food_pos_y[2]) && food_appear[2]) |
              ((current_pos_x == food_pos_x[3]) && (current_pos_y == food_pos_y[3]) && food_appear[3]) | 
              ((current_pos_x == food_pos_x[4]) && (current_pos_y == food_pos_y[4]) && food_appear[4]) |
              ((current_pos_x == food_pos_x[5]) && (current_pos_y == food_pos_y[5]) && food_appear[5]) |
              ((current_pos_x == food_pos_x[6]) && (current_pos_y == food_pos_y[6]) && food_appear[6]) |
              ((current_pos_x == food_pos_x[7]) && (current_pos_y == food_pos_y[7]) && food_appear[7]) |
              ((current_pos_x == food_pos_x[8]) && (current_pos_y == food_pos_y[8]) && food_appear[8]) |
              ((current_pos_x == food_pos_x[9]) && (current_pos_y == food_pos_y[9]) && food_appear[9]);

assign snake_head = ((current_pos_x == snake_pos_x[0]) && (current_pos_y == snake_pos_y[0]) && snake_appear[0]);
assign snake = ((current_pos_x == snake_pos_x[1]) && (current_pos_y == snake_pos_y[1]) && snake_appear[1]) | 
               ((current_pos_x == snake_pos_x[2]) && (current_pos_y == snake_pos_y[2]) && snake_appear[2]) |
               ((current_pos_x == snake_pos_x[3]) && (current_pos_y == snake_pos_y[3]) && snake_appear[3]) | 
               ((current_pos_x == snake_pos_x[4]) && (current_pos_y == snake_pos_y[4]) && snake_appear[4]) |
               ((current_pos_x == snake_pos_x[5]) && (current_pos_y == snake_pos_y[5]) && snake_appear[5]) | 
               ((current_pos_x == snake_pos_x[6]) && (current_pos_y == snake_pos_y[6]) && snake_appear[6]) |
               ((current_pos_x == snake_pos_x[7]) && (current_pos_y == snake_pos_y[7]) && snake_appear[7]) |
               ((current_pos_x == snake_pos_x[8]) && (current_pos_y == snake_pos_y[8]) && snake_appear[8]) | 
               ((current_pos_x == snake_pos_x[9]) && (current_pos_y == snake_pos_y[9]) && snake_appear[9]);

assign block = ((current_pos_x == block_pos_x[0]) && (current_pos_y == block_pos_y[0])) |
               ((current_pos_x == block_pos_x[1]) && (current_pos_y == block_pos_y[1])) |
               ((current_pos_x == block_pos_x[2]) && (current_pos_y == block_pos_y[2])) |
               ((current_pos_x == block_pos_x[3]) && (current_pos_y == block_pos_y[3])) |
               ((current_pos_x == block_pos_x[4]) && (current_pos_y == block_pos_y[4])) |
               ((current_pos_x == block_pos_x[5]) && (current_pos_y == block_pos_y[5]));
       

/////////////////////////////////////////////////////////////snake
always @(posedge clk or negedge reset_n) begin
    if (~reset_n) this_pos_is_snake <= 0;
    else begin
        if (snake) this_pos_is_snake <= 1;
        else this_pos_is_snake <= 0;
    end
end
always @(posedge clk or negedge reset_n) begin
    if (~reset_n) this_pos_is_snake_head <= 0;
    else begin
        if (snake_head) this_pos_is_snake_head <= 1;
        else this_pos_is_snake_head <= 0;
    end
end
/////////////////////////////////////////////////////////////food
always@(posedge clk) begin
    if(~reset_n) begin
        food_clock <= 0;
        food_size <= 0;
    end
    else begin
        if(food_clock == 5*10000000) begin
            food_clock <= 0;
            food_size <= ~food_size;
        end
        else food_clock <= food_clock + 1;
    end
end
always@(posedge clk) begin
    if(~reset_n) this_pos_is_food <= 0;
    else begin
        if(food) this_pos_is_food <= 1;
        else this_pos_is_food <= 0;
    end
end
/////////////////////////////////////////////////////////////block
always@(posedge clk) begin
    if(~reset_n) this_pos_is_block <= 0;
    else begin
        if(block) this_pos_is_block <= 1;
        else this_pos_is_block <= 0;
    end
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
  end
  else if (pixel_x >= 480) begin
    background_is_black_reg <= 1;
  end
  else begin
    background_is_black_reg <= 0;
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
  else
    rgb_next = data_out; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
