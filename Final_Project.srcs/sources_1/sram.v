//
// This module show you how to infer an initialized SRAM block
// in your circuit using the standard Verilog code.  The initial
// values of the SRAM cells is defined in the text file "image.dat"
// Each line defines a cell value. The number of data in image.dat
// must match the size of the sram block exactly.

module sram
#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 19, RAM_SIZE = 65536)
 (input clk, input we, input en,
  input  [9:0] x, input [9:0] y,input  [DATA_WIDTH-1 : 0] data_i,output reg [DATA_WIDTH-1 : 0] data_o, input [3:0] b_x,input [3:0] b_y,
  input is_black,input color_change,
  input is_food, input food_small,
  input is_snake, input is_snake_head, input is_bumped,
  input is_block, input block_transparent,
  input [5:0] current_pos_x, input [5:0] current_pos_y,
  input [3:0]score_2, [3:0]score_1, [3:0]score_0);

// Declaration of the memory cells
 (* ram_style = "block" *) reg [DATA_WIDTH-1 : 0] RAM [RAM_SIZE - 1:0];

integer idx;

initial begin
    $readmemh("images.mem", RAM);
end

// localparam back_addr = 0;
// localparam back_rev_addr = 230400;
// localparam food_big_addr = 460800;
// localparam food_small_addr = 460900;
// localparam food_rev_big_addr = 461000;
// localparam food_rev_small_addr = 461100;
// localparam block_addr = 461200;
// localparam snakehead_addr = 461300;
// localparam snake_addr = 461400;
// localparam snakehead_rev_addr = 461500;
// localparam snake_rev_addr = 461600;
// localparam zero_addr = 461700;
// localparam one_addr = 466700;
// localparam two_addr = 471700;
// localparam three_addr = 476700;
// localparam four_addr = 481700;
// localparam five_addr = 486700;
// localparam six_addr = 491700;
// localparam seven_addr = 496700;
// localparam eight_addr = 501700;
// localparam nine_addr = 506700;

localparam food_big_addr = 0;
localparam food_small_addr = 100;
localparam block_addr = 200;
localparam snakehead_addr = 300;
localparam snake_addr = 400;
localparam snakehead_rev_addr = 500;
localparam snake_rev_addr = 600;
localparam zero_addr = 700;
localparam one_addr = 5700;
localparam two_addr = 10700;
localparam three_addr = 15700;
localparam four_addr = 20700;
localparam five_addr = 25700;
localparam six_addr = 30700;
localparam seven_addr = 35700;
localparam eight_addr = 40700;
localparam nine_addr = 45700;
localparam score_addr = 50700;
localparam press_addr = 59163;

reg [32:0] addr;


// ------------------------------------
// SRAM read operation
// ------------------------------------

always@(posedge clk) begin
  if (en & we) data_o <= data_i;
  else if ((current_pos_x >= 48 && current_pos_x < 53) && (current_pos_y >= 10 && current_pos_y < 20)) data_o <= RAM[zero_addr + (y-100)*50 + x - 480];
  else if ((current_pos_x >= 53 && current_pos_x < 58) && (current_pos_y >= 10 && current_pos_y < 20)) data_o <= RAM[zero_addr + (y-100)*50 + x - 530];
  else if ((current_pos_x >= 58 && current_pos_x < 63) && (current_pos_y >= 10 && current_pos_y < 20)) data_o <= RAM[zero_addr + (y-100)*50 + x - 580];
  else if(is_black) data_o <= 12'h000;
  else begin
    
    if(is_snake_head) begin
        if(is_bumped) data_o <= RAM[snakehead_rev_addr + (b_y*10) + b_x];
        else data_o <= RAM[snakehead_addr + (b_y*10) + b_x];
    end
    else if(is_snake) begin
        if(is_bumped) data_o <= RAM[snake_rev_addr + (b_y*10) + b_x];
        else data_o <= RAM[snake_addr + (b_y*10) + b_x];
    end
    else if(is_food & food_small & !(RAM[food_small_addr + (b_y*10) + b_x] == 12'h003)) begin
        data_o <= RAM[food_small_addr + (b_y*10) + b_x];
    end
    else if(is_food & !food_small & !(RAM[food_big_addr + (b_y*10) + b_x] == 12'h003)) begin
        data_o <= RAM[food_big_addr + (b_y*10) + b_x];
    end
    else if(is_block && ~block_transparent) begin
        data_o <= RAM[block_addr + (b_y*10) + b_x];
    end
    else begin
        if (color_change) begin
            if ( (current_pos_x%2) ^ (current_pos_y%2)) 
                data_o <= 12'hEEF;
            else 
                data_o <= 12'hEFF;
        end
        else begin 
            if ( (current_pos_x%2) ^ (current_pos_y%2)) 
                data_o <= 12'hFFE;
            else 
                data_o <= 12'hFEE;
        end
    end
  end
end

// ------------------------------------
// SRAM write operation
// ------------------------------------
 always@(posedge clk)
 begin
   if (en & we)
     RAM[addr] <= data_i;
 end

endmodule

/* // original module, not supposed to use 
module sram_background
 (input clk, input we, input en,
  input  is_black,
  input color_change,
  input  [12-1 : 0] data_i,
  output reg [12-1 : 0] data_o,
  input is_food,
  input is_snake,
  input is_snake_head, 
  input is_bumped,
  input is_block, input block_transparent);

integer idx;

always@(posedge clk)
begin
  if (en & we) begin
      data_o <= data_i;
  end
  else if(is_black) begin
      data_o <= 12'h0;
  end
  else if(color_change) begin
      if (is_snake_head) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if (is_snake) begin
        if (is_bumped) data_o <= 12'hF0F;
        else data_o <= 12'h080;
      end
      else if(is_food) begin 
          data_o <= 12'h123;
      end
      else if(is_block && ~block_transparent) begin
          data_o <= 12'h666;
      end
      else begin
          data_o <= 12'hBEF;
      end
  end
  else  begin
      if (is_snake_head) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if (is_snake) begin
        if (is_bumped) data_o <= 12'hF00;
        else data_o <= 12'h0E0;
      end
      else if(is_food) begin
          data_o <= 12'h123;
      end
      else if(is_block && ~block_transparent) begin
          data_o <= 12'h666;
      end
      else begin
          data_o <= 12'hFEB;
      end
  end
end

endmodule
*/